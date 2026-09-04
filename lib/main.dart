import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_screen.dart';

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
  appThemeNotifier.value = storageService.getThemeMode();

  runApp(AntigravityApp(storageService: storageService));
}

class AntigravityApp extends StatelessWidget {
  final StorageService storageService;

  const AntigravityApp({super.key, required this.storageService});

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
            storageService: storageService,
            themeNotifier: appThemeNotifier,
          ),
        );
      },
    );
  }
}
