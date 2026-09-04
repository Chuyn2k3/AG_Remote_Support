import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/wakelock_service.dart';
import '../../models/remote_session.dart';
import 'widgets/floating_capsule.dart';

class RemoteScreen extends StatefulWidget {
  final RemoteSession session;

  const RemoteScreen({super.key, required this.session});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isWakelock = false;
  String? _errorMessage;
  bool _isLoading = true;

  // Custom User-Agent giả lập Chrome Mobile chuẩn để vượt qua Google OAuth 403 disallowed_useragent
  static const String customUserAgent =
      'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    _initWakelock();
  }

  Future<void> _initWakelock() async {
    await WakelockService.enable();
    setState(() {
      _isWakelock = true;
    });
  }

  @override
  void dispose() {
    WakelockService.disable();
    super.dispose();
  }

  void _toggleWakelock() async {
    final status = await WakelockService.toggle();
    setState(() {
      _isWakelock = status;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.surfaceDark,
          content: Text(
            status ? '💡 Giữ sáng màn hình: ĐÃ BẬT' : '💡 Giữ sáng màn hình: ĐÃ TẮT',
            style: TextStyle(
              color: status ? AppColors.stateWarning : AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: widget.session.rawUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        backgroundColor: AppColors.surfaceDark,
        content: Text('📋 Đã sao chép link session', style: TextStyle(color: AppColors.textPrimary)),
      ),
    );
  }

  void _retry() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _progress = 0;
    });
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(widget.session.rawUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canGoBack = await _webViewController?.canGoBack() ?? false;
        if (canGoBack) {
          _webViewController?.goBack();
        } else {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // InAppWebView full screen
              Positioned.fill(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.session.rawUrl)),
                  initialSettings: InAppWebViewSettings(
                    userAgent: customUserAgent,
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    cacheEnabled: true,
                    supportMultipleWindows: false,
                    javaScriptCanOpenWindowsAutomatically: true,
                    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    useHybridComposition: true,
                    // Xóa header X-Requested-With để Google OAuth không chặn trên Android
                    requestedWithHeaderOriginAllowList: <String>{},
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    debugPrint('WebView Load Start: $url');
                  },
                  onLoadStop: (controller, url) {
                    setState(() {
                      _isLoading = false;
                      _progress = 1.0;
                    });
                    debugPrint('WebView Load Stop: $url');
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    // Cho phép tất cả các redirect (Google SSO 302 redirects)
                    debugPrint('WebView Redirecting: ${navigationAction.request.url}');
                    return NavigationActionPolicy.ALLOW;
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _progress = progress / 100.0;
                      if (progress >= 95) {
                        _isLoading = false;
                      }
                    });
                  },
                  onReceivedError: (controller, request, error) {
                    debugPrint('WebView Error: ${error.description} (URL: ${request.url})');
                    // Bỏ qua lỗi cancel do redirect nội bộ
                    if (error.description.contains('net::ERR_ABORTED')) return;
                    setState(() {
                      _errorMessage = 'Không thể tải trang: ${error.description}';
                    });
                  },
                  onReceivedHttpError: (controller, request, errorResponse) {
                    debugPrint('WebView HTTP Error: ${errorResponse.statusCode} for ${request.url}');
                  },
                ),
              ),

              // Thin Linear Progress Indicator at top (Tech Cyan)
              if (_progress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                    minHeight: 2.5,
                  ),
                ),

              // Loading Spinner nếu trang đang khởi động lần đầu
              if (_isLoading && _progress < 0.2)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Đang kết nối tới Google & Antigravity...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Error banner if loading completely failed
              if (_errorMessage != null)
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.stateWarning.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, size: 36, color: AppColors.stateWarning),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Thử lại'),
                          onPressed: _retry,
                        ),
                      ],
                    ),
                  ),
                ),

              // Floating Capsule Assistant Menu
              FloatingCapsule(
                isWakelockEnabled: _isWakelock,
                onToggleWakelock: _toggleWakelock,
                onReload: () => _webViewController?.reload(),
                onCopyUrl: _copyUrl,
                onExit: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
