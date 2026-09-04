import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/services/biometric_service.dart';
import '../../core/theme/app_colors.dart';

class BiometricLockScreen extends StatefulWidget {
  final BiometricService biometricService;
  final VoidCallback onAuthenticated;

  const BiometricLockScreen({
    super.key,
    required this.biometricService,
    required this.onAuthenticated,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _isAuthenticating = false;
  String _biometricName = 'Face ID / Vân tay';
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadBiometricName();
    // Tự động kích hoạt xác thực sau khi màn hình hiển thị
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAuth();
    });
  }

  Future<void> _loadBiometricName() async {
    final name = await widget.biometricService.getBiometricDisplayName();
    if (mounted) {
      setState(() {
        _biometricName = name;
      });
    }
  }

  Future<void> _triggerAuth() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Đang xác thực $_biometricName...';
    });

    final success = await widget.biometricService.authenticate(
      reason: 'Xác thực để truy cập AG Remote Support',
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _statusMessage = 'Mở khóa thành công!';
      });
      widget.onAuthenticated();
    } else {
      setState(() {
        _isAuthenticating = false;
        _statusMessage = 'Chưa thể xác thực. Chạm vào biểu tượng để thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Lớp kính mờ phủ toàn màn hình
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                color: (isDark ? AppColors.darkBackground : AppColors.lightBackground).withOpacity(0.85),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Biểu tượng khiên bảo mật sinh trắc học
                    InkWell(
                      onTap: _triggerAuth,
                      borderRadius: BorderRadius.circular(44),
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isDark ? AppColors.darkPrimaryLight : AppColors.lightPrimaryLight),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(isDark ? 0.25 : 0.15),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _biometricName.contains('Face')
                              ? Icons.face_rounded
                              : Icons.fingerprint_rounded,
                          size: 44,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Tiêu đề ứng dụng
                    Text(
                      'AG Remote Support',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Dòng trạng thái
                    Text(
                      _statusMessage ?? 'Ứng dụng được khóa bằng $_biometricName',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Nút bấm thử lại thủ công
                    SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _triggerAuth,
                        icon: const Icon(Icons.lock_open_rounded, size: 18),
                        label: Text(
                          'Mở khóa $_biometricName',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
