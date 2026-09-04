import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cấu hình System UI Bar trong suốt và tối màu theo chuẩn VHT Minimalism
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = await StorageService.init();

  runApp(AntigravityApp(storageService: storageService));
}

class AntigravityApp extends StatelessWidget {
  final StorageService storageService;

  const AntigravityApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity Remote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeScreen(storageService: storageService),
    );
  }
}
