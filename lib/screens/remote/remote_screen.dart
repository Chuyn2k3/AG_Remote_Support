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

  // Custom User-Agent giả lập Chrome Mobile chuẩn để vượt 403 disallowed_useragent của Google OAuth
  static const String customUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

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
              // InAppWebView
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.session.rawUrl)),
                initialSettings: InAppWebViewSettings(
                  userAgent: customUserAgent,
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  cacheEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  useOnLoadResource: true,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100.0;
                  });
                },
              ),

              // Thin Linear Progress Indicator (Tech Cyan)
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

              // Floating Capsule Assistant
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
