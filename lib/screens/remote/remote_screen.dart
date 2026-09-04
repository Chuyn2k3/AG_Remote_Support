import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/heartbeat_service.dart';
import '../../core/utils/url_parser.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/wakelock_service.dart';
import '../../models/remote_session.dart';
import '../../core/services/speech_service.dart';
import 'widgets/floating_capsule.dart';
import 'widgets/voice_prompt_modal.dart';

class RemoteScreen extends StatefulWidget {
  final RemoteSession session;
  final StorageService? storageService;

  const RemoteScreen({
    super.key,
    required this.session,
    this.storageService,
  });

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  InAppWebViewController? _webViewController;
  double _progress = 0;
  bool _isWakelock = false;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isInstanceDisconnected = false;
  Timer? _disconnectCheckTimer;
  StorageService? _storageService;
  final SpeechService _speechService = SpeechService();

  // Custom User-Agent giả lập Chrome Mobile chuẩn để vượt qua Google OAuth 403 disallowed_useragent
  static const String customUserAgent =
      'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    _isInstanceDisconnected = widget.session.isDisconnected;
    _storageService = widget.storageService;
    _initStorageIfNeeded();
    _initWakelock();
    _startDisconnectPolling();
  }

  Future<void> _initStorageIfNeeded() async {
    _storageService ??= await StorageService.init();
  }

  void _startDisconnectPolling() {
    _disconnectCheckTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _checkInstanceDisconnection();
    });
  }

  Future<void> _checkInstanceDisconnection() async {
    if (_webViewController == null || !mounted) return;

    try {
      final dynamic result = await _webViewController?.evaluateJavascript(source: '''
        (function() {
          try {
            const body = document.body;
            if (!body) return false;
            const text = (body.innerText || '').toLowerCase();
            const hasDisconnectedText = text.includes('instance disconnected') ||
                                        text.includes('instance offline') ||
                                        text.includes('no instance') ||
                                        text.includes('disconnected from instance') ||
                                        text.includes('session ended') ||
                                        text.includes('connection lost');
            const hasDisconnectCard = document.querySelector('.disconnect-card, .no-instance-card, [data-status="disconnected"]') !== null;
            return hasDisconnectedText || hasDisconnectCard;
          } catch(e) {
            return false;
          }
        })()
      ''');

      final bool isDisconnected = (result == true || result == 'true' || result == 1);

      if (isDisconnected != _isInstanceDisconnected) {
        if (mounted) {
          setState(() {
            _isInstanceDisconnected = isDisconnected;
          });
        }
        widget.session.isDisconnected = isDisconnected;
        if (!isDisconnected) {
          widget.session.lastAccessedAt = DateTime.now();
        }
        await _saveSessionState();
      } else if (!isDisconnected && widget.session.isDisconnected) {
        widget.session.isDisconnected = false;
        widget.session.lastAccessedAt = DateTime.now();
        await _saveSessionState();
      }
    } catch (e) {
      debugPrint('Error checking disconnection: $e');
    }
  }

  Future<void> _saveSessionState() async {
    try {
      if (_storageService != null) {
        await _storageService!.upsertSession(widget.session);
      } else {
        final storage = await StorageService.init();
        _storageService = storage;
        await storage.upsertSession(widget.session);
      }
    } catch (e) {
      debugPrint('Error saving session state: $e');
    }
  }

  Future<void> _initWakelock() async {
    await WakelockService.enable();
    setState(() {
      _isWakelock = true;
    });
  }

  @override
  void dispose() {
    _disconnectCheckTimer?.cancel();
    _speechService.cancelListening();
    WakelockService.disable();
    super.dispose();
  }

  void _toggleWakelock() async {
    final status = await WakelockService.toggle();
    setState(() {
      _isWakelock = status;
    });
    if (mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          content: Text(
            status ? '💡 Giữ sáng màn hình: BẬT' : '💡 Giữ sáng màn hình: TẮT',
            style: TextStyle(
              color: status ? AppColors.statusWarning : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
        ),
      );
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: widget.session.rawUrl));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        content: Text(
          '📋 Đã sao chép link session',
          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        ),
      ),
    );
  }

  void _retry() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _progress = 0;
      _isInstanceDisconnected = false;
    });
    widget.session.isDisconnected = false;
    _saveSessionState();
    final targetUrl = HeartbeatService.getTargetUrl(widget.session);
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(targetUrl)),
    );
  }


  void _showAccountModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final badgeBg = isDark ? AppColors.darkPrimaryLight : AppColors.lightPrimaryLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textSecondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Quản lý Tài khoản & Đăng nhập',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (widget.session.email != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Tài khoản: ${widget.session.email}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: primaryColor),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Option 1: Switch / Add Google Account
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.switch_account_rounded, color: primaryColor),
                  ),
                  title: Text('Đổi / Thêm tài khoản Google', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Mở Google Account Chooser để chọn hoặc đăng nhập mail khác',
                      style: TextStyle(fontSize: 12, color: textSecondary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    final email = widget.session.email ?? UrlParser.extractEmail(widget.session.rawUrl);
                    final emailParam = (email != null && email.isNotEmpty) ? '&Email=${Uri.encodeComponent(email)}' : '';
                    final targetUrl = HeartbeatService.getTargetUrl(widget.session);
                    final chooserUrl =
                        'https://accounts.google.com/AccountChooser?continue=${Uri.encodeComponent(targetUrl)}$emailParam';
                    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(chooserUrl)));
                  },
                ),

                // Option 2: Open with external system browser (Chrome/Safari)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.open_in_browser_rounded, color: primaryColor),
                  ),
                  title: Text('Mở bằng Trình duyệt máy (Safari/Chrome)',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Dùng phiên đăng nhập Google đã lưu sẵn trên trình duyệt',
                      style: TextStyle(fontSize: 12, color: textSecondary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await InAppBrowser.openWithSystemBrowser(url: WebUri(widget.session.rawUrl));
                  },
                ),

                // Option 3: Clear Cookies
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.statusWarning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cleaning_services_rounded, color: AppColors.statusWarning),
                  ),
                  title: Text('Xóa toàn bộ Cookie', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Reset sạch phiên nếu gặp sự cố đăng nhập',
                      style: TextStyle(fontSize: 12, color: textSecondary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await CookieManager.instance().deleteAllCookies();
                    _retry();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Đã xóa toàn bộ cookie đăng nhập'),
                          backgroundColor: surfaceColor,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // InAppWebView full screen
              Positioned.fill(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(HeartbeatService.getTargetUrl(widget.session)),
                  ),
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
                    Future.delayed(const Duration(milliseconds: 600), () {
                      if (mounted) _checkInstanceDisconnection();
                    });
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

              // Thin 2px Linear Progress Indicator at top (Apple Blue)
              if (_progress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    minHeight: 2.0,
                  ),
                ),

              // Loading Spinner nếu trang đang khởi động lần đầu
              if (_isLoading && _progress < 0.2)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkSurface : AppColors.lightSurface).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Đang kết nối tới Antigravity Desktop...',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Error banner if loading completely failed (Frosted style, no harsh red)
              if (_errorMessage != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkSurface : AppColors.lightSurface).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_off_rounded, size: 36, color: textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              'Không thể kết nối với Desktop',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Hãy đảm bảo Antigravity 2.0 đang chạy trên máy tính của bạn.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.w600)),
                              onPressed: _retry,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Disconnected Banner/Overlay (Apple Frosted Glass HIG)
              if (_isInstanceDisconnected)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkSurface : AppColors.lightSurface).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.darkPrimaryLight : AppColors.lightPrimaryLight),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.power_off_rounded,
                                size: 28,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Máy tính đã ngắt kết nối',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Antigravity 2.0 trên máy tính đã tắt hoặc mất kết nối mạng. Hãy mở lại Antigravity trên máy tính để tiếp tục làm việc.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text(
                                  'Thử kết nối lại',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                onPressed: _retry,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Quay lại Hub thiết bị',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Floating Dynamic Island Capsule Assistant
              FloatingCapsule(
                isWakelockEnabled: _isWakelock,
                onToggleWakelock: _toggleWakelock,
                onAccount: _showAccountModal,
                onReload: () => _webViewController?.reload(),
                onCopyUrl: _copyUrl,
                onExit: () => Navigator.pop(context),
                onVoicePrompt: _openVoicePromptModal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openVoicePromptModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoicePromptModal(
        speechService: _speechService,
        onSendPrompt: (text, autoSubmit) {
          _injectPromptIntoWebView(text, autoSubmit: autoSubmit);
        },
      ),
    );
  }

  Future<void> _injectPromptIntoWebView(String text, {required bool autoSubmit}) async {
    if (_webViewController == null) return;

    final jsText = jsonEncode(text);

    try {
      final dynamic result = await _webViewController?.evaluateJavascript(source: '''
        (function() {
          try {
            const candidates = [
              document.querySelector('textarea:not([disabled])'),
              document.querySelector('[contenteditable="true"]'),
              document.querySelector('input[type="text"]:not([disabled])'),
              document.querySelector('mwc-textarea textarea'),
              document.querySelector('.chat-input textarea')
            ];
            const target = candidates.find(el => el !== null && el.offsetParent !== null) || candidates.find(el => el !== null);
            if (!target) return false;

            target.focus();
            if (target.isContentEditable) {
              target.innerText = (target.innerText ? target.innerText + ' ' : '') + $jsText;
            } else {
              const prev = target.value || '';
              target.value = (prev ? prev + ' ' : '') + $jsText;
            }

            target.dispatchEvent(new Event('input', { bubbles: true }));
            target.dispatchEvent(new Event('change', { bubbles: true }));

            if ($autoSubmit) {
              setTimeout(() => {
                const sendBtn = document.querySelector('button[aria-label*="Send"], button[aria-label*="Gửi"], [data-test-id="send-button"], button[type="submit"]');
                if (sendBtn) {
                  sendBtn.click();
                } else {
                  target.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
                  target.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
                }
              }, 200);
            }
            return true;
          } catch(e) {
            return false;
          }
        })()
      ''');

      final bool success = (result == true || result == 'true' || result == 1);
      if (!success) {
        await Clipboard.setData(ClipboardData(text: text));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 3),
            content: Text('📋 Đã sao chép prompt vào Clipboard. Chạm vào ô chat để dán!'),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(autoSubmit ? '🚀 Đã gửi câu lệnh tới Antigravity!' : '✏️ Đã điền câu lệnh vào ô chat.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error injecting prompt: $e');
      await Clipboard.setData(ClipboardData(text: text));
    }
  }
}
