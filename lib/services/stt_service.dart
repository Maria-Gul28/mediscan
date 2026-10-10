import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wraps speech_to_text for the voice-input flow: the user taps the mic,
/// speaks a medicine name, and this returns the transcribed text - which
/// then gets sent to the backend for identification (see
/// ApiService.identifyByName).
class SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize();
    return _initialized;
  }

  /// [localeId] should be 'ur_PK' when the app's current language is Urdu,
  /// or null to use the device default.
  Future<void> startListening({
    required void Function(String text) onResult,
    String? localeId,
  }) async {
    final available = await initialize();
    if (!available) return;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> stopListening() => _speech.stop();

  bool get isListening => _speech.isListening;

  Future<bool> isUrduLocaleAvailable() async {
    await initialize();
    final locales = await _speech.locales();
    return locales.any((l) => l.localeId.toLowerCase().startsWith('ur'));
  }
}
