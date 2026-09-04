import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/biometric_service.dart';
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

  final storageService = await StorageService.init();
  final biometricService = BiometricService();
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
  bool _needsUnlock = false;

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
    // Không thực hiện lock nếu hộp thoại sinh trắc học của hệ thống đang hiển thị
    if (BiometricService.isAuthenticating) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      if (widget.storageService.isBiometricEnabled()) {
        _needsUnlock = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_needsUnlock && widget.storageService.isBiometricEnabled()) {
        _needsUnlock = false;
        if (!_isLocked) {
          setState(() {
            _isLocked = true;
          });
        }
      }
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
