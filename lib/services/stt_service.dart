import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// On-device speech recognition for medicine-name input.
/// The screen starts listening on pointer-down and calls stopListening on
/// pointer-up/cancel. Partial results are kept so quick release still works.
class SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  String _latestWords = '';
  String? _lastError;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (error) {
        _lastError = error.errorMsg;
      },
    );
    return _initialized;
  }

  Future<bool> startListening({String? localeId}) async {
    _latestWords = '';
    _lastError = null;
    final available = await initialize();
    if (!available) return false;

    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) _latestWords = words;
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 10),
        partialResults: true,
        cancelOnError: true,
      ),
    );
    return true;
  }

  /// Stops recognition and returns the most recent transcript. Some devices
  /// deliver the final transcript just after stop() completes, so allow a
  /// short grace period for that callback.
  Future<String> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return _latestWords.trim();
  }

  bool get isListening => _speech.isListening;
  String? get lastError => _lastError;

  Future<bool> isUrduLocaleAvailable() async {
    if (!await initialize()) return false;
    final locales = await _speech.locales();
    return locales.any((locale) => locale.localeId.toLowerCase().startsWith('ur'));
  }
}
