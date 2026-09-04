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
  Future<bool> get hasPermission => _speechToText.hasPermission;
  String get lastWords => _lastWords;
  double get soundLevel => _soundLevel;

  Function(SpeechRecognitionError)? onError;
  Function(String)? onStatus;

  Future<bool> initialize({
    Function(SpeechRecognitionError)? onError,
    Function(String)? onStatus,
  }) async {
    this.onError = onError;
    this.onStatus = onStatus;

    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        debugLogging: true,
        onError: (val) {
          debugPrint('Speech error: ${val.errorMsg} (permanent: ${val.permanent})');
          this.onError?.call(val);
        },
        onStatus: (val) {
          debugPrint('Speech status: $val');
          this.onStatus?.call(val);
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

  Future<String?> resolveLocale(String? requestedLocale) async {
    if (requestedLocale == null || requestedLocale.isEmpty) return null;
    try {
      final locales = await getLocales();
      if (locales.isEmpty) return requestedLocale;

      // 1. Exact match
      for (final loc in locales) {
        if (loc.localeId.toLowerCase() == requestedLocale.toLowerCase()) {
          return loc.localeId;
        }
      }

      // 2. Prefix match (e.g. 'vi' matches 'vi_VN' or 'vi-VN')
      final langPrefix = requestedLocale.split(RegExp(r'[-_]')).first.toLowerCase();
      for (final loc in locales) {
        if (loc.localeId.toLowerCase().startsWith(langPrefix)) {
          return loc.localeId;
        }
      }
    } catch (e) {
      debugPrint('Error resolving locale: $e');
    }
    return requestedLocale;
  }

  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(double level)? onSoundLevel,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      final available = await initialize(onError: onError, onStatus: onStatus);
      if (!available) return;
    }

    _lastWords = '';
    final resolvedLocaleId = await resolveLocale(localeId);
    debugPrint('Starting speech recognition with locale: $resolvedLocaleId (original: $localeId)');

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastWords = result.recognizedWords;
          debugPrint('Speech result: words="${result.recognizedWords}", isFinal=${result.finalResult}');
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (level) {
          _soundLevel = level;
          onSoundLevel?.call(level);
        },
        listenOptions: SpeechListenOptions(
          localeId: resolvedLocaleId,
          cancelOnError: false,
          partialResults: true,
          listenMode: ListenMode.dictation,
          autoPunctuation: true,
          enableHapticFeedback: true,
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 5),
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
