import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speechToText;
  bool _isInitialized = false;
  String _lastWords = '';
  double _soundLevel = 0.0;

  SpeechService([SpeechToText? speechToText])
      : _speechToText = speechToText ?? SpeechToText();

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isInitialized;
  String get lastWords => _lastWords;
  double get soundLevel => _soundLevel;

  Future<bool> initialize({
    Function(SpeechRecognitionError)? onError,
    Function(String)? onStatus,
  }) async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (val) {
          debugPrint('Speech error: ${val.errorMsg}');
          onError?.call(val);
        },
        onStatus: (val) {
          debugPrint('Speech status: $val');
          onStatus?.call(val);
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<List<LocaleName>> getLocales() async {
    if (!_isInitialized) await initialize();
    try {
      return await _speechToText.locales();
    } catch (e) {
      debugPrint('Error getting speech locales: $e');
      return [];
    }
  }

  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(double level)? onSoundLevel,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      final available = await initialize();
      if (!available) return;
    }

    _lastWords = '';
    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastWords = result.recognizedWords;
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (level) {
          _soundLevel = level;
          onSoundLevel?.call(level);
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );
    } catch (e) {
      debugPrint('Error starting speech listen: $e');
    }
  }

  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (e) {
      debugPrint('Error stopping speech listen: $e');
    }
  }

  Future<void> cancelListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
    } catch (e) {
      debugPrint('Error canceling speech listen: $e');
    }
  }
}
