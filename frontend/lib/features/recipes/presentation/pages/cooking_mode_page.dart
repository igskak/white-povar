import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../providers/recipe_provider.dart';

class CookingModePage extends ConsumerStatefulWidget {
  const CookingModePage({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<CookingModePage> createState() => _CookingModePageState();
}

class _CookingModePageState extends ConsumerState<CookingModePage> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));

    return Scaffold(
      backgroundColor: AppColorsV2.ink,
      appBar: AppBar(
        backgroundColor: AppColorsV2.ink,
        foregroundColor: AppColorsV2.onInk,
        title: const Text('Cooking mode'),
      ),
      body: recipeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not start cooking: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColorsV2.onInk),
            ),
          ),
        ),
        data: (recipe) {
          final instructions = recipe.instructions;
          if (instructions.isEmpty) {
            return const Center(
              child: Text(
                'This recipe has no cooking steps yet.',
                style: TextStyle(color: AppColorsV2.onInk),
              ),
            );
          }

          final lastStep = _step == instructions.length - 1;
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              recipe.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColorsV2.onInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${_step + 1} / ${instructions.length}',
                            style: TextStyle(
                              color: AppColorsV2.onInk.withOpacity(.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: AppRadius.sm,
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: (_step + 1) / instructions.length,
                          color: AppColorsV2.accent,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'STEP ${_step + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColorsV2.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          instructions[_step],
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: AppColorsV2.onInk,
                                height: 1.18,
                              ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColorsV2.onInk,
                                side: const BorderSide(color: Colors.white30),
                              ),
                              onPressed: _step == 0
                                  ? null
                                  : () => setState(() => _step--),
                              child: const Text('Previous'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColorsV2.accent,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: lastStep
                                  ? () => Navigator.of(context).pop()
                                  : () => setState(() => _step++),
                              icon: Icon(
                                  lastStep ? Icons.check : Icons.arrow_forward),
                              label: Text(
                                  lastStep ? 'Finish cooking' : 'Next step'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
