import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/services/biometric_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/security/biometric_lock_screen.dart';

final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final storageService = await StorageService.init();
  final biometricService = BiometricService();
  await NotificationService().init();
  AppLifecycleService.initOverlayCommunication();
  appThemeNotifier.value = storageService.getThemeMode();

  runApp(AntigravityApp(
    storageService: storageService,
    biometricService: biometricService,
  ));
}

class AntigravityApp extends StatefulWidget {
  final StorageService storageService;
  final BiometricService biometricService;

  const AntigravityApp({
    super.key,
    required this.storageService,
    required this.biometricService,
  });

  @override
  State<AntigravityApp> createState() => _AntigravityAppState();
}

class _AntigravityAppState extends State<AntigravityApp> with WidgetsBindingObserver {
  late bool _isLocked;
  DateTime? _pausedAt;
  DateTime? _lastUnlockedAt;

  // Thời gian app ở background trước khi bắt buộc xác thực lại (30 giây)
  static const Duration _lockGracePeriod = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLocked = widget.storageService.isBiometricEnabled();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Không xử lý nếu hộp thoại sinh trắc học của hệ thống đang mở
    if (BiometricService.isAuthenticating) return;

    // QUAN TRỌNG: Tuyệt đối KHÔNG bắt AppLifecycleState.inactive
    // vì inactive xảy ra khi: mở camera quét QR, hiện dialog quyền, kéo status bar,
    // hoặc vừa đóng hộp thoại vân tay xong.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (widget.storageService.isBiometricEnabled() && !_isLocked) {
        // Tránh khóa lại nếu vừa mới unlock trong vòng 5 giây
        final bool isRecentUnlock = _lastUnlockedAt != null &&
            DateTime.now().difference(_lastUnlockedAt!) < const Duration(seconds: 5);

        if (!isRecentUnlock && _pausedAt != null) {
          final elapsed = DateTime.now().difference(_pausedAt!);
          if (elapsed >= _lockGracePeriod) {
            setState(() {
              _isLocked = true;
            });
          }
        }
      }
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'AG Remote Support',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: HomeScreen(
            storageService: widget.storageService,
            themeNotifier: appThemeNotifier,
            biometricService: widget.biometricService,
          ),
          builder: (context, child) {
            return Stack(
              children: [
                if (child != null) child,
                if (_isLocked && widget.storageService.isBiometricEnabled())
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      child: BiometricLockScreen(
                        biometricService: widget.biometricService,
                        onAuthenticated: () {
                          setState(() {
                            _isLocked = false;
                            _lastUnlockedAt = DateTime.now();
                          });
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
