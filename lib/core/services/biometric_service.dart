import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth;

  /// Cờ tĩnh đánh dấu khi hộp thoại xác thực hệ thống đang hiển thị
  /// để tránh vòng lặp re-lock khi Android kích hoạt pause/resume
  static bool isAuthenticating = false;

  BiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  /// Kiểm tra xem thiết bị có hỗ trợ phần cứng sinh trắc học hoặc mật mã bảo vệ không
  Future<bool> isSupported() async {
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      return isDeviceSupported || canCheckBiometrics;
    } catch (e) {
      debugPrint('Biometric check error: $e');
      return false;
    }
  }

  /// Lấy danh sách các loại sinh trắc học thiết bị hỗ trợ (Face ID, Fingerprint, Iris)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Available biometrics error: $e');
      return [];
    }
  }

  /// Tên gọi thân thiện với người dùng dựa trên loại cảm biến
  Future<String> getBiometricDisplayName() async {
    try {
      final types = await getAvailableBiometrics();
      if (types.contains(BiometricType.face)) {
        return 'Face ID';
      } else if (types.contains(BiometricType.fingerprint) || types.contains(BiometricType.strong)) {
        return 'Vân tay / Touch ID';
      } else if (types.contains(BiometricType.iris)) {
        return 'Mống mắt (Iris)';
      }
    } catch (_) {}
    return 'Sinh trắc học / Mã PIN';
  }

  /// Thực hiện yêu cầu người dùng xác thực khuôn mặt, vân tay hoặc mã PIN của máy
  Future<bool> authenticate({
    String reason = 'Xác thực để mở khóa AG Remote Support',
  }) async {
    try {
      final supported = await isSupported();
      if (!supported) return true; // Cho phép vào nếu thiết bị không hỗ trợ

      isAuthenticating = true;
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Cho phép fallback mã PIN / Passcode của máy
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    } finally {
      // Chờ một khoảng nhỏ để Android hoàn tất chuyển đổi Activity focus
      await Future.delayed(const Duration(milliseconds: 300));
      isAuthenticating = false;
    }
  }
}
