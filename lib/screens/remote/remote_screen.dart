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
import '../../core/services/notification_service.dart';
import '../../core/services/native_bubble_service.dart';
import '../../core/services/app_lifecycle_service.dart';
import 'session_tab_bar.dart';
import 'widgets/floating_capsule.dart';
import 'widgets/voice_prompt_modal.dart';
import 'widgets/git_actions_modal.dart';

/// State riêng cho từng tab WebView
class _TabState {
  final RemoteSession session;
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? controller;
  double progress = 0.0;
  bool isLoading = true;
  String? errorMessage;
  bool isDisconnected;

  _TabState({
    required this.session,
    this.isDisconnected = false,
  });
}

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

class _RemoteScreenState extends State<RemoteScreen> with WidgetsBindingObserver {
  // ── Multi-tab state ──────────────────────────────────────────────────────
  late final List<_TabState> _tabs;
  int _activeTabIndex = 0;
  bool _isSplitScreen = false;
  bool _isLandscape = false;

  // Convenience getters trỏ vào tab đang active
  _TabState get _activeTab => _tabs[_activeTabIndex];
  InAppWebViewController? get _webViewController => _activeTab.controller;
  double get _progress => _activeTab.progress;
  set _progress(double v) => _activeTab.progress = v;
  bool get _isLoading => _activeTab.isLoading;
  set _isLoading(bool v) => _activeTab.isLoading = v;
  String? get _errorMessage => _activeTab.errorMessage;
  set _errorMessage(String? v) => _activeTab.errorMessage = v;
  bool get _isInstanceDisconnected => _activeTab.isDisconnected;
  set _isInstanceDisconnected(bool v) => _activeTab.isDisconnected = v;

  // ── Other state ──────────────────────────────────────────────────────────
  bool _isWakelock = false;
  Timer? _disconnectCheckTimer;
  StorageService? _storageService;
  final SpeechService _speechService = SpeechService();
  final NotificationService _notificationService = NotificationService();
  final NativeBubbleService _nativeBubbleService = NativeBubbleService();
  bool _bubbleActive = false;

  // ── AI Response Watcher state (Dart Poller) ──────────────────────────────
  Timer? _aiResponsePollingTimer;
  bool _aiIsWorking = false;
  bool _aiNotified = true;
  int _aiLastTextLength = 0;
  DateTime? _aiLastActivityTime;
  String _aiLastPreview = '';

  // Custom User-Agent giả lập Chrome Mobile chuẩn để vượt qua Google OAuth 403 disallowed_useragent
  static const String customUserAgent =
      'Mozilla/5.0 (Linux; Android 14; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Khởi tạo tab đầu tiên từ session truyền vào
    _tabs = [
      _TabState(
        session: widget.session,
        isDisconnected: widget.session.isDisconnected,
      ),
    ];
    _storageService = widget.storageService;
    _initStorageIfNeeded();
    _initWakelock();
    _startDisconnectPolling();
    _startAIResponsePolling();
    // MẶC ĐỊNH LÀ MÀN HÌNH DỌC (Không tự động/mặc định xoay ngang)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    // Khởi tạo notification service
    _notificationService.init();
    _checkBubbleStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBubbleStatus();
    }
  }

  Future<void> _checkBubbleStatus() async {
    final showing = await _nativeBubbleService.isBubbleShowing();
    if (mounted && showing != _bubbleActive) {
      setState(() => _bubbleActive = showing);
    }
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
        _activeTab.session.isDisconnected = isDisconnected; _activeTab.isDisconnected = isDisconnected;
        if (!isDisconnected) {
          _activeTab.session.lastAccessedAt = DateTime.now();
        }
        await _saveSessionState();
      } else if (!isDisconnected && _activeTab.session.isDisconnected) {
        _activeTab.session.isDisconnected = false; _activeTab.isDisconnected = false;
        _activeTab.session.lastAccessedAt = DateTime.now();
        await _saveSessionState();
      }
    } catch (e) {
      debugPrint('Error checking disconnection: $e');
    }
  }

  Future<void> _saveSessionState() async {
    try {
      if (_storageService != null) {
        await _storageService!.upsertSession(_activeTab.session);
      } else {
        final storage = await StorageService.init();
        _storageService = storage;
        await storage.upsertSession(_activeTab.session);
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

  void _startAIResponsePolling() {
    _aiResponsePollingTimer?.cancel();
    _aiResponsePollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _pollAIResponseStatus();
    });
  }

  Future<void> _pollAIResponseStatus() async {
    if (_webViewController == null || !mounted) return;

    try {
      final dynamic result = await _webViewController?.evaluateJavascript(source: '''
        (function() {
          try {
            // 1. Kiểm tra các nút Stop / Cancel / Dừng
            const stopKeywords = ['stop', 'cancel', 'dừng', 'hủy', 'abort', 'pause'];
            let hasStopButton = false;
            const buttons = document.querySelectorAll('button, [role="button"], a');
            for (let i = 0; i < buttons.length; i++) {
              const b = buttons[i];
              const aria = (b.getAttribute('aria-label') || '').toLowerCase();
              const title = (b.getAttribute('title') || '').toLowerCase();
              const text = (b.innerText || '').toLowerCase().trim();
              for (let k = 0; k < stopKeywords.length; k++) {
                const kw = stopKeywords[k];
                if (aria.includes(kw) || title.includes(kw) || text === kw) {
                  hasStopButton = true;
                  break;
                }
              }
              if (hasStopButton) break;
            }

            // 2. Icon dạng Stop / Loading / Streaming / Thinking
            const hasIndicator = document.querySelector(
              '[aria-busy="true"], mat-progress-bar, mat-spinner, .mat-mdc-progress-bar, ' +
              '.loading, .spinner, .typing, .streaming, [data-is-generating="true"], ' +
              '.cursor, .blinking-cursor, [class*="generating"], [class*="streaming"], [class*="thinking"]'
            ) !== null;

            const isGenerating = hasStopButton || hasIndicator;

            // 3. Độ dài text toàn trang
            const bodyText = document.body ? (document.body.innerText || '') : '';
            const textLen = bodyText.length;

            // 4. Trích xuất preview phản hồi
            let preview = '';
            const candidates = document.querySelectorAll(
              '.model-response, [data-role="model"], .response-text, .message-content, ' +
              '[class*="response"]:last-child, [class*="message"]:last-child, pre, code, p'
            );
            if (candidates.length > 0) {
              for (let i = candidates.length - 1; i >= 0; i--) {
                const t = (candidates[i].innerText || '').trim();
                if (t.length > 10) {
                  preview = t.substring(0, 150);
                  break;
                }
              }
            }
            if (!preview && bodyText.length > 0) {
              const trimmed = bodyText.trim();
              preview = trimmed.length > 150 ? trimmed.substring(trimmed.length - 150) : trimmed;
            }

            // 5. Cờ đánh dấu người dùng vừa gửi câu lệnh
            const userRecentlySent = window.__agUserRecentlySent === true;
            if (userRecentlySent) {
              window.__agUserRecentlySent = false;
            }

            return JSON.stringify({
              isGenerating: isGenerating,
              textLen: textLen,
              preview: preview,
              userRecentlySent: userRecentlySent
            });
          } catch(e) {
            return null;
          }
        })()
      ''');

      if (result == null || !mounted) return;
      final Map<String, dynamic> data = jsonDecode(result.toString());
      final bool isGenerating = data['isGenerating'] == true;
      final int textLen = (data['textLen'] as num?)?.toInt() ?? 0;
      final String preview = data['preview']?.toString() ?? '';
      final bool userRecentlySent = data['userRecentlySent'] == true;

      _handleAIDetectionTick(
        isGenerating: isGenerating,
        textLen: textLen,
        preview: preview,
        userRecentlySent: userRecentlySent,
      );
    } catch (e) {
      // Ignored
    }
  }

  void _handleAIDetectionTick({
    required bool isGenerating,
    required int textLen,
    required String preview,
    required bool userRecentlySent,
  }) {
    if (userRecentlySent) {
      _aiIsWorking = true;
      _aiNotified = false;
      _aiLastActivityTime = DateTime.now();
      _aiLastTextLength = textLen;
      debugPrint('[AI Monitor] User sent prompt! Foreground watcher activated.');
      _nativeBubbleService.startForegroundWatcher(title: _activeTab.session.title);
      _nativeBubbleService.updateBubbleStatus('thinking');
      return;
    }

    if (isGenerating) {
      _aiIsWorking = true;
      _aiNotified = false;
      _aiLastActivityTime = DateTime.now();
      _aiLastTextLength = textLen;
      if (preview.isNotEmpty) _aiLastPreview = preview;
      debugPrint('[AI Monitor] AI is actively generating response (text len: $textLen)...');
      _nativeBubbleService.startForegroundWatcher(title: _activeTab.session.title);
      _nativeBubbleService.updateBubbleStatus('thinking');
      return;
    }

    // Nếu text dài ra > 10 ký tự -> AI đang stream nội dung
    if (_aiLastTextLength > 0 && textLen > _aiLastTextLength + 10) {
      _aiIsWorking = true;
      _aiNotified = false;
      _aiLastActivityTime = DateTime.now();
      _aiLastTextLength = textLen;
      if (preview.isNotEmpty) _aiLastPreview = preview;
      debugPrint('[AI Monitor] AI streaming detected by text growth (len: $textLen)...');
      _nativeBubbleService.startForegroundWatcher(title: _activeTab.session.title);
      _nativeBubbleService.updateBubbleStatus('thinking');
      return;
    }

    // Khi AI đã từng xử lý câu lệnh VÀ không còn sinh nữa VÀ text dừng thay đổi trong 2.0s
    if (_aiIsWorking && !isGenerating && !_aiNotified) {
      final lastTime = _aiLastActivityTime ?? DateTime.now();
      final elapsed = DateTime.now().difference(lastTime).inMilliseconds;
      if (elapsed >= 2000) {
        _aiIsWorking = false;
        _aiNotified = true;
        debugPrint('[AI Monitor] AI completed response! Triggering notification and releasing watcher...');
        final sendPreview = _aiLastPreview.isNotEmpty ? _aiLastPreview : (preview.isNotEmpty ? preview : null);
        _notificationService.showAICompletedNotification(
          sessionName: _activeTab.session.title,
          preview: sendPreview,
        );
        _nativeBubbleService.updateBubbleStatus('online');
        _nativeBubbleService.stopForegroundWatcher();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disconnectCheckTimer?.cancel();
    _aiResponsePollingTimer?.cancel();
    _speechService.cancelListening();
    _nativeBubbleService.stopForegroundWatcher();
    WakelockService.disable();
    // Khóa lại portrait khi rời màn hình WebView
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
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

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            content: Text(
              '🔄 Đã xoay ngang màn hình (Landscape)',
              style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
        );
      }
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            content: Text(
              '📱 Đã quay lại màn hình dọc (Portrait)',
              style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
          ),
        );
      }
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: _activeTab.session.rawUrl));
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
    _activeTab.session.isDisconnected = false;
    _saveSessionState();
    final targetUrl = HeartbeatService.getTargetUrl(_activeTab.session);
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
                if (_activeTab.session.email != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Tài khoản: ${_activeTab.session.email}',
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
                    final email = _activeTab.session.email ?? UrlParser.extractEmail(_activeTab.session.rawUrl);
                    final emailParam = (email != null && email.isNotEmpty) ? '&Email=${Uri.encodeComponent(email)}' : '';
                    final targetUrl = HeartbeatService.getTargetUrl(_activeTab.session);
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
                    await InAppBrowser.openWithSystemBrowser(url: WebUri(_activeTab.session.rawUrl));
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

  Future<void> _handlePopScope() async {
    final canGoBack = await _webViewController?.canGoBack() ?? false;
    if (canGoBack) {
      _webViewController?.goBack();
      return;
    }

    // Nếu AI đang xử lý, cảnh báo người dùng để họ chọn thu nhỏ app chạy ngầm thay vì đóng hẳn
    if (_aiIsWorking && mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final shouldExit = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: Color(0xFFFFD60A), size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI đang xử lý câu lệnh...',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Antigravity đang tiếp tục sinh phản hồi. Nếu bạn thoát hẳn ra ngoài Hub, phiên kết nối sẽ bị đóng. Bạn có muốn thu nhỏ app chạy ngầm để nhận thông báo khi xong không?',
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A84FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.arrow_downward_rounded),
                    label: const Text(
                      'Thu nhỏ chạy ngầm & Nhận thông báo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx, false);
                      AppLifecycleService.moveTaskToBack();
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Đóng hẳn phiên làm việc', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (shouldExit == true && mounted) {
        Navigator.pop(context);
      }
    } else {
      if (mounted) Navigator.pop(context);
    }
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
        await _handlePopScope();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Tab bar (chỉ hiện khi có nhiều hơn 1 tab)
              if (_tabs.length > 1)
                SessionTabBar(
                  sessions: _tabs.map((t) => t.session).toList(),
                  activeIndex: _activeTabIndex,
                  onTabSelected: _switchTab,
                  onTabClosed: _closeTab,
                  onAddTab: _showAddTabSheet,
                  isSplitScreen: _isSplitScreen,
                  onToggleSplitScreen: _toggleSplitScreen,
                  isLandscape: _isLandscape,
                  onToggleOrientation: _toggleOrientation,
                ),
              Expanded(
                child: Stack(
                  children: [
              // IndexedStack hoặc SplitView chia đôi màn hình
              Positioned.fill(
                child: _isSplitScreen && _tabs.length >= 2
                    ? _buildSplitView(isDark, primaryColor)
                    : IndexedStack(
                        index: _activeTabIndex,
                        children: List.generate(_tabs.length, (i) => _buildTabWebView(i)),
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
                onGitActions: _openGitActionsModal,
                onBubble: _toggleBubble,
                bubbleActive: _bubbleActive,
                onTestNotification: _testNotification,
                onToggleSplit: _toggleSplitScreen,
                isSplitActive: _isSplitScreen,
                onToggleOrientation: _toggleOrientation,
                isLandscape: _isLandscape,
              ),
            ],
          ),    // end Stack
        ),      // end Expanded
      ],
      ),        // end Column
    ),          // end SafeArea
  ),            // end Scaffold
);              // end PopScope
}               // end build

  // ─────────────────────────────────────────────────────────────────────────
  // Multi-tab Methods
  // ─────────────────────────────────────────────────────────────────────────

  /// Tạo InAppWebView cho một tab cụ thể với state callbacks riêng.
  Widget _buildTabWebView(int tabIndex) {
    final tab = _tabs[tabIndex];
    return InAppWebView(
      key: tab.webViewKey,
      initialUrlRequest: URLRequest(
        url: WebUri(HeartbeatService.getTargetUrl(tab.session)),
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
        requestedWithHeaderOriginAllowList: <String>{},
      ),
      onWebViewCreated: (controller) {
        tab.controller = controller;
        // Đăng ký JS handler nhận callback khi AI hoàn thành
        controller.addJavaScriptHandler(
          handlerName: 'onAIResponseDone',
          callback: (args) async {
            final String preview = args.isNotEmpty ? args[0].toString() : '';
            debugPrint('[AI Tab $tabIndex] JS Response done. Preview: $preview');
            if (!_aiNotified) {
              _aiIsWorking = false;
              _aiNotified = true;
              await _notificationService.showAICompletedNotification(
                sessionName: tab.session.title,
                preview: preview.isNotEmpty ? preview : null,
              );
              await _nativeBubbleService.updateBubbleStatus('online');
              await _nativeBubbleService.stopForegroundWatcher();
            }
          },
        );
      },
      onLoadStart: (controller, url) {
        if (!mounted) return;
        setState(() {
          tab.isLoading = true;
          tab.errorMessage = null;
        });
      },
      onLoadStop: (controller, url) {
        if (!mounted) return;
        setState(() {
          tab.isLoading = false;
          tab.progress = 1.0;
        });
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && tabIndex == _activeTabIndex) {
            _checkInstanceDisconnection();
          }
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _injectAIResponseObserver(controller);
          }
        });
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        return NavigationActionPolicy.ALLOW;
      },
      onProgressChanged: (controller, progress) {
        if (!mounted) return;
        setState(() {
          tab.progress = progress / 100.0;
          if (progress >= 95) tab.isLoading = false;
        });
      },
      onReceivedError: (controller, request, error) {
        if (error.description.contains('net::ERR_ABORTED')) return;
        if (!mounted) return;
        setState(() {
          tab.errorMessage = 'Không thể tải trang: ${error.description}';
        });
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        debugPrint('WebView HTTP Error: ${errorResponse.statusCode}');
      },
    );
  }

  /// Switch sang tab khác (IndexedStack — WebView giữ state, không reload)
  void _switchTab(int index) {
    if (index == _activeTabIndex) return;
    setState(() => _activeTabIndex = index);
    // Re-inject AI observer cho tab vừa active
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _injectAIResponseObserver();
    });
  }

  /// Đóng tab tại index cho trước
  void _closeTab(int index) {
    if (_tabs.length <= 1) return;
    setState(() {
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
      if (_tabs.length < 2) {
        _isSplitScreen = false;
      }
    });
  }

  /// Bật / tắt chế độ chia đôi màn hình (Split View)
  void _toggleSplitScreen() {
    if (_tabs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần ít nhất 2 phiên kết nối để chia đôi. Vui lòng chọn thêm session...'),
          duration: Duration(seconds: 2),
        ),
      );
      _showAddTabSheet(autoSplit: true);
      return;
    }
    setState(() {
      _isSplitScreen = !_isSplitScreen;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSplitScreen
            ? '⚡️ Đã bật Chia đôi màn hình (Split View)'
            : 'Đã chuyển về chế độ xem từng Tab'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Giao diện chia đôi màn hình 50/50 theo chiều ngang (Landscape) hoặc dọc (Portrait)
  Widget _buildSplitView(bool isDark, Color primaryColor) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        final borderColor = isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

        final pane0 = Stack(
          children: [
            Positioned.fill(child: _buildTabWebView(0)),
            Positioned(
              top: 8,
              left: 10,
              child: _buildSplitPaneBadge(_tabs[0].session, isDark, primaryColor),
            ),
          ],
        );

        final secondIndex = _activeTabIndex > 0 ? _activeTabIndex : 1;
        final pane1 = Stack(
          children: [
            Positioned.fill(child: _buildTabWebView(secondIndex)),
            Positioned(
              top: 8,
              left: 10,
              child: _buildSplitPaneBadge(_tabs[secondIndex].session, isDark, primaryColor),
            ),
          ],
        );

        if (isLandscape) {
          return Row(
            children: [
              Expanded(child: pane0),
              Container(width: 2, color: borderColor),
              Expanded(child: pane1),
            ],
          );
        } else {
          return Column(
            children: [
              Expanded(child: pane0),
              Container(height: 2, color: borderColor),
              Expanded(child: pane1),
            ],
          );
        }
      },
    );
  }

  Widget _buildSplitPaneBadge(RemoteSession session, bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: primaryColor.withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: session.isDisconnected ? const Color(0xFFFF3B30) : const Color(0xFF30D158),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            session.title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// Hiển thị bottom sheet để chọn session thêm vào tab mới
  void _showAddTabSheet({bool autoSplit = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<StorageService>(
          future: StorageService.init(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final sessions = snap.data!.getSessions();
            // Lọc ra sessions chưa mở tab
            final openIds = _tabs.map((t) => t.session.id).toSet();
            final available = sessions.where((s) => !openIds.contains(s.id)).toList();

            return Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    autoSplit ? 'Chọn session để chia đôi màn hình' : 'Mở tab mới',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (available.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Không còn session nào để mở.\nThêm session mới ở màn hình Hub.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    )
                  else
                    ...available.map((session) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.computer_rounded, color: Colors.white54),
                          title: Text(
                            session.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            session.rawUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _tabs.add(_TabState(
                                session: session,
                                isDisconnected: session.isDisconnected,
                              ));
                              if (autoSplit) {
                                _isSplitScreen = true;
                              } else {
                                _activeTabIndex = _tabs.length - 1;
                              }
                            });
                          },
                        )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openGitActionsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GitActionsModal(
        onSendPrompt: (text, autoSubmit) {
          _injectPromptIntoWebView(text, autoSubmit: autoSubmit);
        },
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
                if (window.__agTriggerUserSent) window.__agTriggerUserSent();
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
        if (autoSubmit) {
          _aiIsWorking = true;
          _aiNotified = false;
          _aiLastActivityTime = DateTime.now();
          _nativeBubbleService.startForegroundWatcher(title: _activeTab.session.title);
          _nativeBubbleService.updateBubbleStatus('thinking');
        }
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

  /// Inject JavaScript để detect khi AI hoàn thành response:
  /// 1. Bắt sự kiện người dùng gửi câu lệnh (Enter / Click Send)
  /// 2. Bắt các trạng thái đang sinh (nút Dừng, Stop icon, loading indicator, stream text)
  /// 3. Khi trạng thái đang sinh kết thúc VÀ văn bản ngừng thay đổi trong 1.5s → Bắn thông báo
  Future<void> _injectAIResponseObserver([InAppWebViewController? targetController]) async {
    final controller = targetController ?? _webViewController;
    if (controller == null) return;

    await controller.evaluateJavascript(source: '''
      (function() {
        if (window.__agAIObserverActive) return;
        window.__agAIObserverActive = true;

        let isWorking = false;
        let lastTextLength = 0;
        let lastActivityTime = Date.now();
        let notified = true;

        function getAllText() {
          return document.body ? (document.body.innerText || '') : '';
        }

        function isAIGenerating() {
          // 1. Kiểm tra các nút Stop / Cancel / Dừng / Abort
          const stopKeywords = ['stop', 'cancel', 'dừng', 'hủy', 'abort', 'pause'];
          const buttons = document.querySelectorAll('button, [role="button"], a');
          for (let i = 0; i < buttons.length; i++) {
            const b = buttons[i];
            const aria = (b.getAttribute('aria-label') || '').toLowerCase();
            const title = (b.getAttribute('title') || '').toLowerCase();
            const text = (b.innerText || '').toLowerCase().trim();
            for (let k = 0; k < stopKeywords.length; k++) {
              const kw = stopKeywords[k];
              if (aria.includes(kw) || title.includes(kw) || text === kw) {
                return true;
              }
            }
          }

          // 2. Icon dạng Stop / Pause (Material Icons, Google Symbols, SVG)
          const icons = document.querySelectorAll('mat-icon, .google-symbols, i, svg');
          for (let j = 0; j < icons.length; j++) {
            const t = (icons[j].innerText || '').toLowerCase().trim();
            if (t === 'stop' || t === 'pause' || t === 'stop_circle' || t === 'cancel') {
              return true;
            }
          }

          // 3. Loading spinner, progress bar, typing dots, streaming cursor
          if (document.querySelector('[aria-busy="true"], mat-progress-bar, mat-spinner, .mat-mdc-progress-bar, .loading, .spinner, .typing, .streaming, [data-is-generating="true"], .cursor, .blinking-cursor, [class*="generating"], [class*="streaming"]')) {
            return true;
          }

          return false;
        }

        function extractPreview() {
          try {
            const candidates = document.querySelectorAll(
              '.model-response, [data-role="model"], ' +
              '.response-text, .message-content, ' +
              '[class*="response"]:last-child, [class*="message"]:last-child, ' +
              'pre, code, p'
            );
            if (candidates.length > 0) {
              for (let i = candidates.length - 1; i >= 0; i--) {
                const t = (candidates[i].innerText || '').trim();
                if (t.length > 5) {
                  return t.substring(0, 150);
                }
              }
            }
            const full = getAllText().trim();
            return full.length > 150 ? full.substring(full.length - 150) : full;
          } catch(e) {
            return 'Đã hoàn thành phản hồi!';
          }
        }

        function triggerUserSent() {
          isWorking = true;
          notified = false;
          window.__agUserRecentlySent = true;
          lastTextLength = getAllText().length;
          lastActivityTime = Date.now();
          console.log('[AG Remote] User sent prompt. Tracking AI output...');
        }

        window.__agTriggerUserSent = triggerUserSent;

        // Bắt sự kiện khi user gõ Enter (cả physical lẫn virtual keyboard)
        document.addEventListener('keydown', function(e) {
          if ((e.key === 'Enter' || e.keyCode === 13 || e.which === 13) && !e.shiftKey) {
            triggerUserSent();
          }
        }, true);

        // Bắt sự kiện form submit
        document.addEventListener('submit', function() {
          triggerUserSent();
        }, true);

        // Bắt sự kiện click bất kỳ nút nào liên quan tới gửi tin nhắn
        document.addEventListener('click', function(e) {
          const btn = e.target.closest('button, [role="button"], a, mat-icon, svg');
          if (btn) {
            const label = (btn.getAttribute('aria-label') || '').toLowerCase();
            const title = (btn.getAttribute('title') || '').toLowerCase();
            const text = (btn.innerText || '').toLowerCase();
            const cls = (btn.className || '').toString().toLowerCase();
            if (label.includes('send') || label.includes('gửi') || label.includes('submit') || label.includes('run') ||
                title.includes('send') || title.includes('gửi') ||
                text.includes('send') || text.includes('gửi') ||
                cls.includes('send') || cls.includes('submit') ||
                btn.type === 'submit') {
              triggerUserSent();
            }
          }
        }, true);

        function checkStatus() {
          const generating = isAIGenerating();
          const currentLen = getAllText().length;

          if (generating) {
            isWorking = true;
            notified = false;
            lastActivityTime = Date.now();
          } else if (currentLen !== lastTextLength) {
            // Text đang stream / tăng độ dài
            if (isWorking) {
              lastActivityTime = Date.now();
            }
            lastTextLength = currentLen;
          }

          // Khi AI đã dừng sinh VÀ text không đổi trong 1.5s
          if (isWorking && !generating && !notified) {
            const idleTime = Date.now() - lastActivityTime;
            if (idleTime >= 1500) {
              isWorking = false;
              notified = true;
              const preview = extractPreview();
              console.log('[AG Remote] AI completed! Firing onAIResponseDone');
              if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('onAIResponseDone', preview);
              }
            }
          }
        }

        // MutationObserver theo dõi toàn bộ DOM thay đổi
        const observer = new MutationObserver(function() {
          checkStatus();
        });

        observer.observe(document.body, {
          childList: true,
          subtree: true,
          characterData: true,
          attributes: true,
        });

        // Polling fallback dự phòng khi ở nền
        setInterval(checkStatus, 800);

        console.log('[AG Remote] Enhanced AI Response Observer active');
      })();
    ''');
    debugPrint('[RemoteScreen] Enhanced AI Observer injected');
  }

  /// Toggle floating bubble overlay (Android only).
  Future<void> _toggleBubble() async {
    if (!_nativeBubbleService.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🍎 iOS không hỗ trợ overlay window do giới hạn sandbox.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_bubbleActive) {
      await _nativeBubbleService.hideBubble();
      setState(() => _bubbleActive = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bong bóng nổi đã được ẩn'), duration: Duration(seconds: 1)),
      );
    } else {
      final bool granted = await _nativeBubbleService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Cần cấp quyền "Hiển thị trên ứng dụng khác" trong Cài đặt'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final currentStatus = _aiIsWorking ? 'thinking' : (!_isInstanceDisconnected ? 'online' : 'offline');
      await _nativeBubbleService.showBubble(
        sessionTitle: widget.session.title,
        status: currentStatus,
      );
      setState(() => _bubbleActive = true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1E1E24),
          content: Text(
            '🟢 Đã bật Bong bóng tròn Chat Head! Bạn có thể kéo thả tự do, chạm để mở app, kéo xuống đáy để tắt.',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // Chờ 1.2s để người dùng kịp đọc thông báo, sau đó chuyển app xuống chạy ngầm
      // Giữ nguyên phiên làm việc và WebView hoạt động (KHÔNG làm chết app)
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted && _bubbleActive) {
        await AppLifecycleService.moveTaskToBack();
      }
    }
  }

  /// Gửi thông báo thử nghiệm (cả tức thì lẫn sau 3 giây)
  Future<void> _testNotification() async {
    final bool hasPermission = await _notificationService.areNotificationsEnabled();
    if (!hasPermission) {
      final granted = await _notificationService.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFE53935),
            content: Text(
              '⚠️ Quyền thông báo đang bị tắt! Hãy vào Cài đặt thiết bị > Ứng dụng > AG Remote Support > Bật thông báo.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF1E1E24),
        content: Text('🔔 Đã bắn 1 thông báo tức thì và 1 thông báo sau 3 giây!'),
        duration: Duration(seconds: 3),
      ),
    );

    // 1. Gửi thông báo tức thì (xuất hiện banner thả xuống ngay trên màn hình)
    await _notificationService.showAICompletedNotification(
      sessionName: _activeTab.session.title,
      preview: 'Thông báo tức thì: Antigravity AI đã kết nối thành công!',
    );

    // 2. Gửi thông báo sau 3 giây để người dùng kịp nhấn Home kiểm tra khi app chạy ngầm
    _notificationService.sendTestNotification(delaySeconds: 3);
  }
}
