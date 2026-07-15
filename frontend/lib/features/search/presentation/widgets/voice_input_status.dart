import 'package:flutter/material.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../voice/providers/voice_input_provider.dart';

class VoiceInputStatus extends StatelessWidget {
  const VoiceInputStatus({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onStop,
    required this.onCancel,
  });

  final VoiceInputState state;
  final VoidCallback onRetry;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (!state.isRequestingPermission &&
        !state.isListening &&
        state.transcript.isEmpty &&
        state.error == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final message = state.isRequestingPermission
        ? 'Запитуємо доступ до мікрофона…'
        : state.isListening
            ? 'Слухаємо. Скажіть, що хочете приготувати.'
            : state.error ??
                'Текст розпізнано. За потреби відредагуйте його перед пошуком.';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Semantics(
        liveRegion: true,
        label: message,
        child: Row(
          children: [
            Icon(
              state.isListening ? Icons.graphic_eq : Icons.mic_none_outlined,
              size: 18,
              color: state.error == null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
            if (state.isListening) ...[
              AppButton(
                label: 'Готово',
                variant: AppButtonVariant.text,
                onPressed: onStop,
              ),
              AppIconButton(
                icon: Icons.close,
                tooltip: 'Скасувати голосове введення',
                onPressed: onCancel,
              ),
            ] else if (state.error != null)
              AppButton(
                label: 'Повторити',
                variant: AppButtonVariant.text,
                onPressed: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}
