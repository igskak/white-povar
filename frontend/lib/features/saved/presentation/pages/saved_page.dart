import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../auth/providers/auth_provider.dart';

class SavedPage extends ConsumerWidget {
  const SavedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(currentUserProvider) != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved recipes')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: AppColorsV2.surfaceStrong,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark_add_outlined,
                      size: 38,
                      color: AppColorsV2.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    isSignedIn
                        ? 'Your cookbook starts here'
                        : 'Keep the good ones close',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    isSignedIn
                        ? 'Save a recipe from its page and it will appear in your personal collection.'
                        : 'Browse freely. Sign in only when you want to save recipes and sync them across devices.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColorsV2.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () =>
                        context.go(isSignedIn ? '/home' : '/login'),
                    icon:
                        Icon(isSignedIn ? Icons.explore_outlined : Icons.login),
                    label:
                        Text(isSignedIn ? 'Find a recipe' : 'Sign in to save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
