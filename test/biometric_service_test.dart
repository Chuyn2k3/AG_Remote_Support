import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/core/services/biometric_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BiometricService initializes and handles fallback when no hardware mock', () async {
    final service = BiometricService();
    // Default platform in flutter_test has no biometric hardware, should handle gracefully
    final supported = await service.isSupported();
    expect(supported, isA<bool>());

    final types = await service.getAvailableBiometrics();
    expect(types, isA<List>());

    final name = await service.getBiometricDisplayName();
    expect(name, isNotEmpty);
  });
}
