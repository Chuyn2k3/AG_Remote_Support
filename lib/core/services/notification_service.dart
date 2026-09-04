import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    // Tạo notification channel cho Android với High/Max importance để hiện pop-up banner
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'ai_response_channel',
            'AI Response',
            description: 'Thông báo khi Antigravity AI trả lời xong',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

    // Request permission trên Android 13+
    await requestPermission();

    _initialized = true;
    debugPrint('[NotificationService] Initialized');
  }

  /// Kiểm tra xem thông báo đã được cấp quyền chưa
  Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? true;
  }

  /// Yêu cầu cấp quyền thông báo
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Hiển thị notification khi AI hoàn thành response
  Future<void> showAICompletedNotification({
    required String sessionName,
    String? preview,
  }) async {
    if (!_initialized) await init();

    final String bodyText = preview?.isNotEmpty == true
        ? preview!
        : 'Nhấn để xem kết quả trong Antigravity';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'ai_response_channel',
      'AI Response',
      channelDescription: 'Thông báo khi Antigravity AI trả lời xong',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      ticker: 'AI đã trả lời',
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        bodyText,
        contentTitle: '✅ $sessionName — AI đã trả lời',
        summaryText: 'Antigravity AI',
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _plugin.show(
      notificationId,
      '✅ $sessionName — AI đã trả lời',
      bodyText,
      details,
    );
    debugPrint('[NotificationService] Notification shown with id $notificationId');
  }

  /// Gửi thông báo thử nghiệm
  Future<void> sendTestNotification({int delaySeconds = 0}) async {
    if (!_initialized) await init();
    if (delaySeconds > 0) {
      await Future.delayed(Duration(seconds: delaySeconds));
    }
    await showAICompletedNotification(
      sessionName: 'AG Remote Support',
      preview: 'Kiểm tra thành công! Thông báo hoạt động bình thường trên thiết bị của bạn.',
    );
  }
}
