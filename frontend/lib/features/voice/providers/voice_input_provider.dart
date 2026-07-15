import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/speech_recognition_service.dart';

class VoiceInputState {
  const VoiceInputState({
    this.isRequestingPermission = false,
    this.isListening = false,
    this.transcript = '',
    this.isFinalTranscript = false,
    this.permissionState,
    this.error,
  });

  final bool isRequestingPermission;
  final bool isListening;
  final String transcript;
  final bool isFinalTranscript;
  final VoicePermissionState? permissionState;
  final String? error;

  VoiceInputState copyWith({
    bool? isRequestingPermission,
    bool? isListening,
    String? transcript,
    bool? isFinalTranscript,
    VoicePermissionState? permissionState,
    String? error,
    bool clearError = false,
  }) =>
      VoiceInputState(
        isRequestingPermission:
            isRequestingPermission ?? this.isRequestingPermission,
        isListening: isListening ?? this.isListening,
        transcript: transcript ?? this.transcript,
        isFinalTranscript: isFinalTranscript ?? this.isFinalTranscript,
        permissionState: permissionState ?? this.permissionState,
        error: clearError ? null : error ?? this.error,
      );
}

final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>(
  (_) => PlatformSpeechRecognitionService(),
);

final voiceInputProvider =
    StateNotifierProvider.autoDispose<VoiceInputNotifier, VoiceInputState>(
        (ref) {
  return VoiceInputNotifier(ref.watch(speechRecognitionServiceProvider));
});

class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  VoiceInputNotifier(this._service) : super(const VoiceInputState());

  final SpeechRecognitionService _service;

  Future<void> startListening() async {
    if (state.isRequestingPermission || state.isListening) return;
    state = state.copyWith(isRequestingPermission: true, clearError: true);
    final permissionState = await _service.requestPermission();
    if (permissionState != VoicePermissionState.granted) {
      state = state.copyWith(
        isRequestingPermission: false,
        permissionState: permissionState,
        error: _permissionMessage(permissionState),
      );
      return;
    }

    final started = await _service.start(
      onTranscript: (text, isFinal) {
        if (!mounted) return;
        state = state.copyWith(
          transcript: text,
          isFinalTranscript: isFinal,
          isListening: !isFinal,
          permissionState: VoicePermissionState.granted,
          clearError: true,
        );
      },
      onStatus: (isListening) {
        if (!mounted) return;
        state = state.copyWith(isListening: isListening);
      },
      onError: (message) {
        if (!mounted) return;
        state = state.copyWith(isListening: false, error: message);
      },
    );
    if (!mounted) return;
    state = state.copyWith(
      isRequestingPermission: false,
      isListening: started,
      permissionState: VoicePermissionState.granted,
      error: started ? null : 'Не вдалося почати слухати. Спробуйте ще раз.',
    );
  }

  Future<void> stopListening() async {
    await _service.stop();
    if (mounted) state = state.copyWith(isListening: false);
  }

  Future<void> cancelListening() async {
    await _service.cancel();
    if (mounted) {
      state = state.copyWith(
        isListening: false,
        transcript: '',
        isFinalTranscript: false,
        clearError: true,
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    _service.cancel();
  }

  String _permissionMessage(VoicePermissionState state) => switch (state) {
        VoicePermissionState.denied =>
          'Доступ до мікрофона не надано. Ви все одно можете ввести запит текстом.',
        VoicePermissionState.permanentlyDenied =>
          'Доступ до мікрофона вимкнено в налаштуваннях. Введіть запит текстом або змініть дозвіл.',
        VoicePermissionState.unavailable =>
          'Голосове введення недоступне на цьому пристрої. Введіть запит текстом.',
        VoicePermissionState.granted => '',
      };
}
