import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/core/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SpeechService initializes with default states and handles error safely', () async {
    final service = SpeechService();
    expect(service.isListening, isFalse);
    expect(service.lastWords, isEmpty);
    expect(service.isAvailable, isFalse);
    expect(service.soundLevel, equals(0.0));

    // Initializing in test environment without native speech engine should return false gracefully
    final isAvailable = await service.initialize();
    expect(isAvailable, isA<bool>());
    expect(isAvailable, isFalse);
  });
}
