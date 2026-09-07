import 'dart:async';
import 'dart:convert';

import 'dart:collection';
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

/// Script quan sát AI chạy trên mọi frame (bao gồm cả iframe chat của Antigravity)
const String _aiObserverScript = r'''
(function() {
  if (window.__agObserverInitialized) return;
  window.__agObserverInitialized = true;

  // 1. Mock window.nativeNotifications (Antigravity's internal Electron bridge)
  try {
    window.nativeNotifications = {
      onClicked: function(cb) { window._agNotiClicked = cb; },
      send: function(noti) {
        try {
          console.log('[AG NativeNotification] ' + JSON.stringify(noti || {}));
        } catch(e) {
          console.log('[AG NativeNotification] {"title":"Antigravity Notification"}');
        }
      },
      openSystemPreferences: function() {},
      clearNotifications: function() {}
    };
  } catch(e) {}

  // 2. Mock HTML5 Notification API with granted permission
  try {
    if (typeof window.Notification === 'undefined' || window.Notification.permission !== 'granted') {
      function MockNotification(title, options) {
        try {
          console.log('[AG WebNotification] ' + JSON.stringify({
            title: title,
            body: (options && options.body) || ''
          }));
        } catch(e) {}
      }
      MockNotification.permission = 'granted';
      MockNotification.requestPermission = function() { return Promise.resolve('granted'); };
      window.Notification = MockNotification;
    }
  } catch(e) {}

  let isWaitingForResponse = false;
  let hasStartedGenerating = false;
  let promptSentTime = 0;
  let promptSentTextLength = 0;
  let lastTextLength = 0;
  let lastActivityTime = Date.now();
  let notified = true;
  let lastInputValLength = 0;

  function getAllText() {
    try {
      return document.body ? (document.body.innerText || '') : '';
    } catch(e) { return ''; }
  }

  function extractPreview() {
    try {
      const candidates = document.querySelectorAll(
        '.model-response, [data-role="model"], ' +
        '.response-text, .message-content, ' +
        '[class*="response"], [class*="message"], ' +
        '[class*="agent"], [class*="assistant"], ' +
        'pre, code, p'
      );
      if (candidates.length > 0) {
        for (let i = candidates.length - 1; i >= 0; i--) {
          const t = (candidates[i].innerText || '').trim();
          if (t.length > 10) {
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

  function checkIsGenerating() {
    try {
      const stopKeywords = ['stop', 'cancel', 'dừng', 'hủy', 'abort', 'pause', 'interrupt', 'terminate', 'halt'];
      const buttons = document.querySelectorAll('button, [role="button"], a, div[tabindex]');
      for (let i = 0; i < buttons.length; i++) {
        const b = buttons[i];
        const aria = (b.getAttribute('aria-label') || '').toLowerCase();
        const title = (b.getAttribute('title') || '').toLowerCase();
        const text = (b.innerText || '').toLowerCase().trim();
        const cls = (b.className || '').toString().toLowerCase();
        for (let k = 0; k < stopKeywords.length; k++) {
          const kw = stopKeywords[k];
          if (aria.includes(kw) || title.includes(kw) || text === kw || cls.includes(kw)) {
            return true;
          }
        }
      }
      const icons = document.querySelectorAll('mat-icon, .google-symbols, i, svg, [class*="codicon"]');
      for (let j = 0; j < icons.length; j++) {
        const el = icons[j];
        const t = (el.innerText || '').toLowerCase().trim();
        const cls = (el.className || '').toString().toLowerCase();
        if (t === 'stop' || t === 'pause' || t === 'stop_circle' || t === 'cancel' ||
            cls.includes('stop') || cls.includes('pause') || cls.includes('codicon-debug-stop') || cls.includes('codicon-stop')) {
          return true;
        }
      }
      if (document.querySelector(
        '[aria-busy="true"], mat-progress-bar, mat-spinner, .mat-mdc-progress-bar, ' +
        'mwc-circular-progress, [data-is-generating="true"], [data-status="generating"], ' +
        '.loading, .spinner, .typing, .streaming, .cursor, .blinking-cursor, ' +
        '[class*="generating"], [class*="streaming"], [class*="thinking"], [class*="in-progress"]'
      )) {
        return true;
      }
    } catch(e) {}
    return false;
  }

  function notifyPromptSent() {
    isWaitingForResponse = true;
    hasStartedGenerating = false;
    notified = false;
    promptSentTime = Date.now();
    lastActivityTime = Date.now();
    promptSentTextLength = getAllText().length;
    lastTextLength = promptSentTextLength;
    console.log('[AG Remote] User sent prompt');
    try {
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('onUserPromptSent');
      }
    } catch(e) {}
  }

  window.addEventListener('keydown', function(e) {
    if ((e.key === 'Enter' || e.keyCode === 13 || e.which === 13) && !e.shiftKey) {
      notifyPromptSent();
    }
  }, true);

  window.addEventListener('beforeinput', function(e) {
    if (e.inputType === 'insertLineBreak' || e.inputType === 'insertParagraph') {
      notifyPromptSent();
    }
  }, true);

  window.addEventListener('input', function(e) {
    const target = e.target;
    if (target && (target.tagName === 'TEXTAREA' || target.isContentEditable || target.tagName === 'INPUT')) {
      const val = (target.value || target.innerText || '').trim();
      const curLen = val.length;
      if (lastInputValLength >= 2 && curLen === 0) {
        notifyPromptSent();
      }
      lastInputValLength = curLen;
    }
  }, true);

  window.addEventListener('click', function(e) {
    const btn = e.target.closest('button, [role="button"], a, mat-icon, svg, [class*="send"], [class*="submit"], [class*="action"]');
    if (btn) {
      const label = (btn.getAttribute('aria-label') || '').toLowerCase();
      const title = (btn.getAttribute('title') || '').toLowerCase();
      const text = (btn.innerText || '').toLowerCase();
      const cls = (btn.className || '').toString().toLowerCase();
      if (label.includes('send') || label.includes('gửi') || label.includes('submit') || label.includes('run') ||
          label.includes('generate') || label.includes('execute') || label.includes('prompt') ||
          title.includes('send') || title.includes('gửi') || title.includes('run') || title.includes('execute') ||
          text.includes('send') || text.includes('gửi') || text.includes('chạy') ||
          cls.includes('send') || cls.includes('submit') || cls.includes('run') || cls.includes('codicon-send') ||
          btn.type === 'submit') {
        notifyPromptSent();
      }
    }
  }, true);

  function checkStatus() {
    try {
      const generating = checkIsGenerating();
      const currentLen = getAllText().length;

      if (lastTextLength === 0 && currentLen > 0) {
        lastTextLength = currentLen;
      }

      // Xác định khi AI bắt đầu sinh (có Stop button hoặc text bắt đầu dài thêm do câu trả lời)
      if (isWaitingForResponse || hasStartedGenerating) {
        if (generating) {
          if (!hasStartedGenerating) {
            hasStartedGenerating = true;
            console.log('[AG Remote] AI is generating');
          }
          lastActivityTime = Date.now();
        } else if (currentLen > promptSentTextLength + 6) {
          if (!hasStartedGenerating) {
            hasStartedGenerating = true;
            console.log('[AG Remote] AI is generating');
          }
          if (currentLen > lastTextLength + 2) {
            lastActivityTime = Date.now();
            lastTextLength = currentLen;
          }
        }
      }

      // CHỈ kích hoạt hoàn thành khi AI ĐÃ THỰC SỰ BẮT ĐẦU SINH và giờ đã dừng lại
      if (hasStartedGenerating && !generating && !notified) {
        const idleTime = Date.now() - lastActivityTime;
        // Chờ ít nhất 2.2 giây sau khi text dừng thay đổi
        if (idleTime >= 2200) {
          isWaitingForResponse = false;
          hasStartedGenerating = false;
          notified = true;
          lastTextLength = currentLen;
          const preview = extractPreview();
          console.log('[AG Remote] AI completed: ' + preview);
          try {
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('onAIResponseDone', preview);
            }
          } catch(e) {}
        }
      }
    } catch(e) {}
  }

  window.addEventListener('message', function(ev) {
    if (ev.data && (ev.data.type === 'AG_CHECK_STATUS' || ev.data.type === 'AG_PING')) {
      checkStatus();
    }
  });

  try {
    if (document.body) {
      const observer = new MutationObserver(checkStatus);
      observer.observe(document.body, {
        childList: true,
        subtree: true,
        characterData: true,
        attributes: true
      });
    } else {
      document.addEventListener('DOMContentLoaded', function() {
        if (document.body) {
          const observer = new MutationObserver(checkStatus);
          observer.observe(document.body, {
            childList: true,
            subtree: true,
            characterData: true,
            attributes: true
          });
        }
      });
    }
  } catch(e) {}

  setInterval(checkStatus, 800);
  console.log('[AG Remote] Enhanced AI Response Observer active in frame: ' + window.location.href);
})();
''';

/// State riêng cho từng tab WebView
class _TabState {
  final RemoteSession session;
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? controller;
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> loadingNotifier = ValueNotifier<bool>(true);
  String? errorMessage;
  bool isDisconnected;

  _TabState({
    required this.session,
    this.isDisconnected = false,
  });

  double get progress => progressNotifier.value;
  set progress(double v) => progressNotifier.value = v;

  bool get isLoading => loadingNotifier.value;
  set isLoading(bool v) => loadingNotifier.value = v;

  void dispose() {
    progressNotifier.dispose();
    loadingNotifier.dispose();
  }
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
  String? get _errorMessage => _activeTab.errorMessage;
  set _errorMessage(String? v) => _activeTab.errorMessage = v;
  bool get _isInstanceDisconnected => _activeTab.isDisconnected;
  set _isInstanceDisconnected(bool v) => _activeTab.isDisconnected = v;

  // ── Other state ──────────────────────────────────────────────────────────
  bool _isWakelock = false;
  StorageService? _storageService;
  final SpeechService _speechService = SpeechService();
  final NotificationService _notificationService = NotificationService();
  final NativeBubbleService _nativeBubbleService = NativeBubbleService();
  bool _bubbleActive = false;

  // ── AI Response Watcher state (Event-Driven via Console & UserScript) ────
  Timer? _aiStreamDebounceTimer;
  bool _aiIsWorking = false;
  bool _hasStartedStreaming = false;
  bool _aiNotified = true;
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

  void _onUserPromptSubmitted(String sessionTitle, [String? reason]) {
    debugPrint('[AI Monitor] User Prompt Submitted: $reason');
    _aiIsWorking = true;
    _hasStartedStreaming = false; // CHƯA nhận được token, tuyệt đối KHÔNG được báo hoàn thành!
    _aiNotified = false;
    _aiStreamDebounceTimer?.cancel(); // Hủy mọi debounce timer trước đó
    _aiStreamDebounceTimer = null;

    _nativeBubbleService.startForegroundWatcher(title: sessionTitle);
    _nativeBubbleService.updateBubbleStatus('thinking');
    if (mounted) setState(() {});
  }

  void _onAITokenStreaming(String sessionTitle, [String? reason]) {
    debugPrint('[AI Monitor] AI Streaming: $reason');
    _aiIsWorking = true;
    _hasStartedStreaming = true; // ĐÃ bắt đầu nhận token / sinh câu trả lời!
    _aiNotified = false;
    _resetStreamDebounceTimer(sessionTitle);
    if (mounted) setState(() {});
  }

  void _resetStreamDebounceTimer(String sessionTitle) {
    _aiStreamDebounceTimer?.cancel();
    // Chờ 3.8 giây nếu không còn token/sự kiện nào phát sinh SAU KHI ĐÃ BẮT ĐẦU STREAM -> Hoàn thành
    _aiStreamDebounceTimer = Timer(const Duration(milliseconds: 3800), () {
      if (_aiIsWorking && _hasStartedStreaming && !_aiNotified) {
        debugPrint('[AI Monitor] Inactivity stream debounce reached. AI completed turn.');
        _onAICompleted(sessionTitle, _aiLastPreview.isNotEmpty ? _aiLastPreview : null);
      }
    });
  }

  Future<void> _onAICompleted(String sessionTitle, [String? preview, bool force = false]) async {
    // Ngăn chặn nổ thông báo non khi AI chưa từng bắt đầu stream câu trả lời
    if (!force && !_hasStartedStreaming) {
      debugPrint('[AI Monitor] Bỏ qua hoàn thành sớm: AI chưa từng stream token nào!');
      return;
    }
    if (_aiNotified) return;

    debugPrint('[AI Monitor] AI Completed! Showing notification. Preview: $preview');
    _aiStreamDebounceTimer?.cancel();
    _aiStreamDebounceTimer = null;

    _aiIsWorking = false;
    _hasStartedStreaming = false;
    _aiNotified = true;
    if (mounted) setState(() {});

    final sendPreview = (preview != null && preview.trim().isNotEmpty)
        ? preview.trim()
        : (_aiLastPreview.isNotEmpty ? _aiLastPreview : 'Antigravity đã hoàn thành phản hồi.');

    await _notificationService.showAICompletedNotification(
      sessionName: sessionTitle,
      preview: sendPreview,
    );
    await _nativeBubbleService.updateBubbleStatus('online');
    await _nativeBubbleService.stopForegroundWatcher();
  }

  void _handleConsoleMessage(int tabIndex, _TabState tab, String msg) {
    final sessionTitle = tab.session.title;

    // 1. Antigravity native log từ main.js: [TTFT] Time to first token: 5846ms (turn 5)
    if (msg.contains('[TTFT]') || msg.contains('Time to first token')) {
      final turnMatch = RegExp(r'\(turn\s*(\d+)\)').firstMatch(msg);
      final turnStr = turnMatch != null ? ' (Lượt ${turnMatch.group(1)})' : '';
      _onAITokenStreaming(sessionTitle, 'Antigravity TTFT token stream started$turnStr');
      return;
    }

    // 2. Observer: Người dùng vừa gửi prompt trong iframe chat
    if (msg.contains('[AG Remote] User sent prompt')) {
      _onUserPromptSubmitted(sessionTitle, 'User submitted prompt inside chat iframe');
      return;
    }

    // 3. Observer: AI đang hiển thị chỉ thị sinh (Stop button, stream text)
    if (msg.contains('[AG Remote] AI is generating')) {
      _onAITokenStreaming(sessionTitle, 'AI generation indicator active in chat iframe');
      return;
    }

    // 4. Observer: AI đã hoàn thành phản hồi trong iframe chat
    if (msg.contains('[AG Remote] AI completed:')) {
      final preview = msg.replaceFirst('[AG Remote] AI completed:', '').trim();
      if (preview.isNotEmpty) _aiLastPreview = preview;
      _onAICompleted(sessionTitle, preview.isNotEmpty ? preview : null);
      return;
    }

    // 5. Thông báo gốc từ Antigravity (qua mock window.nativeNotifications.send)
    if (msg.contains('[AG NativeNotification]')) {
      final jsonStr = msg.replaceFirst('[AG NativeNotification]', '').trim();
      String? notiPreview;
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        notiPreview = map['body']?.toString() ?? map['title']?.toString();
      } catch (_) {}
      _onAICompleted(sessionTitle, notiPreview ?? 'Antigravity đã hoàn thành tác vụ!', true);
      return;
    }

    // 6. Web notification từ Antigravity (qua mock HTML5 Notification)
    if (msg.contains('[AG WebNotification]')) {
      final jsonStr = msg.replaceFirst('[AG WebNotification]', '').trim();
      String? notiPreview;
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        notiPreview = map['body']?.toString() ?? map['title']?.toString();
      } catch (_) {}
      _onAICompleted(sessionTitle, notiPreview ?? 'Antigravity đã hoàn thành tác vụ!', true);
      return;
    }

    // 7. Khi AI đang sinh, các log hoạt động sẽ reset debounce timer để không kết thúc sớm
    if (_hasStartedStreaming && !_aiNotified) {
      if (!msg.contains('ResizeObserver') && !msg.contains('TouchIcon') && !msg.contains('ConfigService') && !msg.contains('GPUAUX')) {
        _resetStreamDebounceTimer(sessionTitle);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final tab in _tabs) {
      tab.dispose();
    }
    _aiStreamDebounceTimer?.cancel();
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
    _activeTab.loadingNotifier.value = true;
    _activeTab.progressNotifier.value = 0.0;
    setState(() {
      _errorMessage = null;
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
              // Tab bar (chỉ hiện khi có nhiều hơn 1 tab) - Render layer isolation
              if (_tabs.length > 1)
                RepaintBoundary(
                  child: SessionTabBar(
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
                ),
              Expanded(
                child: Stack(
                  children: [
              // IndexedStack hoặc SplitView chia đôi màn hình
              Positioned.fill(
                child: _isSplitScreen && _tabs.length >= 2
                    ? _buildSplitView(isDark, primaryColor)
                    : (_tabs.length == 1
                        ? _buildTabWebView(0)
                        : IndexedStack(
                            index: _activeTabIndex,
                            children: List.generate(_tabs.length, (i) => _buildTabWebView(i)),
                          )),
              ),

              // Thin 2px Linear Progress Indicator at top (Apple Blue) - Scoped with ValueListenableBuilder
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<double>(
                  valueListenable: _activeTab.progressNotifier,
                  builder: (context, progress, _) {
                    if (progress >= 1.0) return const SizedBox.shrink();
                    return LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      minHeight: 2.0,
                    );
                  },
                ),
              ),

              // Loading Spinner nếu trang đang khởi động lần đầu - Scoped with ValueListenableBuilder
              ValueListenableBuilder<bool>(
                valueListenable: _activeTab.loadingNotifier,
                builder: (context, isLoading, _) {
                  if (!isLoading) return const SizedBox.shrink();
                  return ValueListenableBuilder<double>(
                    valueListenable: _activeTab.progressNotifier,
                    builder: (context, progress, _) {
                      if (progress >= 0.2) return const SizedBox.shrink();
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                          decoration: BoxDecoration(
                            // Dùng màu đặc thay BackdropFilter — BackdropFilter không đọc được pixel SurfaceView trên Android
                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
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
                      );
                    },
                  );
                },
              ),

              // Error banner if loading completely failed (Solid — BackdropFilter breaks Android PlatformView)
              if (_errorMessage != null)
                Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
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

              // Disconnected Banner/Overlay (Solid — BackdropFilter breaks Android PlatformView)
              if (_isInstanceDisconnected)
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
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
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          groupName: 'ag_observer',
          source: _aiObserverScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
          allowedOriginRules: {'*'},
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        userAgent: customUserAgent,
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        thirdPartyCookiesEnabled: true,
        cacheEnabled: true,
        cacheMode: CacheMode.LOAD_DEFAULT,
        clearCache: false,
        supportMultipleWindows: false,
        javaScriptCanOpenWindowsAutomatically: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        useHybridComposition: true, // SurfaceView chuẩn — MIUI GuiExtAux xử lý đúng, không gây Null ANativeBuffer
        transparentBackground: false, // Nền đặc tránh lộ buffer đen của SurfaceView native
        requestedWithHeaderOriginAllowList: <String>{},
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        allowContentAccess: true,
        allowBackgroundAudioPlaying: true,
      ),
      onWebViewCreated: (controller) {
        tab.controller = controller;
        // Đăng ký JS handler nhận callback khi AI hoàn thành với kiểm tra Origin an toàn
        controller.addJavaScriptHandler(
          handlerName: 'onAIResponseDone',
          callback: (args) async {
            final currentUrl = await controller.getUrl();
            final host = currentUrl?.host.toLowerCase() ?? '';
            if (!host.endsWith('.google.com') && !host.endsWith('.usercontent.goog')) {
              debugPrint('[Security] Untrusted origin attempted JS onAIResponseDone: $host');
              return;
            }
            final String preview = args.isNotEmpty ? args[0].toString() : '';
            debugPrint('[AI Tab $tabIndex] JS onAIResponseDone. Preview: $preview');
            _onAICompleted(tab.session.title, preview.isNotEmpty ? preview : null);
          },
        );
        // Đăng ký JS handler nhận callback khi người dùng gửi prompt với kiểm tra Origin an toàn
        controller.addJavaScriptHandler(
          handlerName: 'onUserPromptSent',
          callback: (args) async {
            final currentUrl = await controller.getUrl();
            final host = currentUrl?.host.toLowerCase() ?? '';
            if (!host.endsWith('.google.com') && !host.endsWith('.usercontent.goog')) {
              debugPrint('[Security] Untrusted origin attempted JS onUserPromptSent: $host');
              return;
            }
            debugPrint('[AI Tab $tabIndex] JS onUserPromptSent received!');
            _onUserPromptSubmitted(tab.session.title, 'onUserPromptSent handler');
          },
        );
      },
      onConsoleMessage: (controller, consoleMessage) {
        _handleConsoleMessage(tabIndex, tab, consoleMessage.message);
      },
      onLoadStart: (controller, url) {
        tab.loadingNotifier.value = true;
        if (tab.errorMessage != null && mounted) {
          setState(() {
            tab.errorMessage = null;
          });
        }
      },
      onLoadStop: (controller, url) {
        tab.loadingNotifier.value = false;
        tab.progressNotifier.value = 1.0;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && tabIndex == _activeTabIndex) {
            _checkInstanceDisconnection();
          }
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _injectAIResponseObserver(controller);
          }
        });
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url;
        if (uri == null) return NavigationActionPolicy.CANCEL;

        // 1. Chỉ chấp nhận giao thức HTTPS an toàn
        if (uri.scheme != 'https') {
          return NavigationActionPolicy.CANCEL;
        }

        // 2. Kiểm tra danh sách miền được phép (Domain Whitelist)
        final host = uri.host.toLowerCase();
        final bool isAllowed = host == 'antigravity.google.com' ||
            host == 'accounts.google.com' ||
            host.endsWith('.google.com') ||
            host.endsWith('.usercontent.goog');

        if (!isAllowed) {
          debugPrint('[Security] Blocked unauthorized navigation attempt to: $host');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFFE53935),
                content: Text('⚠️ Chặn điều hướng không an toàn tới: $host'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return NavigationActionPolicy.CANCEL;
        }

        return NavigationActionPolicy.ALLOW;
      },
      onProgressChanged: (controller, progress) {
        final double val = progress / 100.0;
        tab.progressNotifier.value = val;
        if (progress >= 95) {
          tab.loadingNotifier.value = false;
        }
      },
      onReceivedError: (controller, request, error) {
        if (error.description.contains('net::ERR_ABORTED')) return;
        if (!mounted) return;
        setState(() {
          tab.errorMessage = 'Không thể tải trang: ${error.description}';
        });
        _checkInstanceDisconnection();
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
    final closedTab = _tabs.removeAt(index);
    closedTab.dispose();
    setState(() {
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
          _onUserPromptSubmitted(_activeTab.session.title, 'Prompt autoSubmit from modal');
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

  /// Inject JavaScript để detect khi AI hoàn thành response
  Future<void> _injectAIResponseObserver([InAppWebViewController? targetController]) async {
    final controller = targetController ?? _webViewController;
    if (controller == null) return;

    try {
      await controller.evaluateJavascript(source: _aiObserverScript);
      await controller.evaluateJavascript(source: '''
        (function() {
          try {
            for (let i = 0; i < window.frames.length; i++) {
              try {
                window.frames[i].postMessage({type: 'AG_CHECK_STATUS'}, '*');
              } catch(e) {}
            }
          } catch(e) {}
        })();
      ''');
      debugPrint('[RemoteScreen] Enhanced AI Observer injected and broadcasted');
    } catch (e) {
      debugPrint('[RemoteScreen] Error injecting AI Observer: $e');
    }
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
}
