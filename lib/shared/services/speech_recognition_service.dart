import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SpeechTextCallback = void Function(String text, bool isFinal);
typedef SpeechStatusCallback = void Function(String status);
typedef SpeechErrorCallback = void Function(String message);

class SpeechRecognitionService {
  SpeechRecognitionService({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  String? _localeId;
  SpeechStatusCallback? _onStatus;
  SpeechErrorCallback? _onError;

  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    SpeechStatusCallback? onStatus,
    SpeechErrorCallback? onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;

    if (_initialized) return true;

    _initialized = await _speech.initialize(
      onStatus: _handleStatus,
      onError: _handleError,
    );

    if (_initialized) {
      _localeId = await _resolveThaiLocale();
    }

    return _initialized;
  }

  Future<void> startListening({
    required SpeechTextCallback onText,
    Duration listenFor = const Duration(hours: 1),
    Duration pauseFor = const Duration(seconds: 10),
  }) async {
    if (!_initialized) {
      throw StateError('Speech recognition is not initialized.');
    }

    await _speech.listen(
      localeId: _localeId,
      listenFor: listenFor,
      pauseFor: pauseFor,
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (SpeechRecognitionResult result) {
        onText(result.recognizedWords.trim(), result.finalResult);
      },
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();

  Future<String?> _resolveThaiLocale() async {
    final locales = await _speech.locales();
    for (final locale in locales) {
      final localeId = locale.localeId.toLowerCase();
      if (localeId == 'th_th' || localeId == 'th-th') {
        return locale.localeId;
      }
    }
    for (final locale in locales) {
      final localeId = locale.localeId.toLowerCase();
      if (localeId.startsWith('th_') || localeId.startsWith('th-')) {
        return locale.localeId;
      }
    }
    return 'th-TH';
  }

  void _handleStatus(String status) {
    _onStatus?.call(status);
  }

  void _handleError(SpeechRecognitionError error) {
    if (error.errorMsg == 'not-allowed') {
      _initialized = false;
    }
    _onError?.call(error.errorMsg);
  }
}
