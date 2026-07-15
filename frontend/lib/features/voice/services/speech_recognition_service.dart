import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoicePermissionState { granted, denied, permanentlyDenied, unavailable }

typedef VoiceTranscriptCallback = void Function(String text, bool isFinal);
typedef VoiceStatusCallback = void Function(bool isListening);
typedef VoiceErrorCallback = void Function(String message);

/// Boundary around the platform recognizer. It exposes text only: neither this
/// service nor the feature writes audio to disk or sends it to the API.
abstract class SpeechRecognitionService {
  Future<VoicePermissionState> requestPermission();

  Future<bool> start({
    required VoiceTranscriptCallback onTranscript,
    required VoiceStatusCallback onStatus,
    required VoiceErrorCallback onError,
  });

  Future<void> stop();
  Future<void> cancel();
}

class PlatformSpeechRecognitionService implements SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();

  @override
  Future<VoicePermissionState> requestPermission() async {
    if (!kIsWeb) {
      final microphone = await Permission.microphone.request();
      if (!microphone.isGranted) {
        return microphone.isPermanentlyDenied
            ? VoicePermissionState.permanentlyDenied
            : VoicePermissionState.denied;
      }
    }

    return VoicePermissionState.granted;
  }

  @override
  Future<bool> start({
    required VoiceTranscriptCallback onTranscript,
    required VoiceStatusCallback onStatus,
    required VoiceErrorCallback onError,
  }) async {
    final available = await _speech.initialize(
      onStatus: (status) => onStatus(status == 'listening'),
      onError: (error) => onError(error.errorMsg),
    );
    if (!available) return false;
    await _speech.listen(
      onResult: (result) =>
          onTranscript(result.recognizedWords, result.finalResult),
      onSoundLevelChange: (_) {},
      listenOptions: SpeechListenOptions(
        localeId: 'uk_UA',
        partialResults: true,
        listenMode: ListenMode.search,
        cancelOnError: true,
      ),
    );
    onStatus(_speech.isListening);
    return _speech.isListening;
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}
