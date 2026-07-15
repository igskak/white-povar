import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../auth/providers/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Профіль')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline_rounded, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    'Зробіть кухню своєю',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Увійдіть, щоб зберігати рецепти, памʼятати налаштування і продовжувати на будь-якому пристрої.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.login),
                    label: const Text('Увійти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final email = user.email ?? 'Email не вказано';
    final userId = user.id;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профіль'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ви увійшли як',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userId,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('Підписка'),
                    subtitle:
                        const Text('Поточний рівень і доступні можливості'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/offers/subscription'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Налаштування'),
                    subtitle: const Text('Тема, уподобання і дії акаунта'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Потрібна допомога з підпискою?'),
                subtitle: const Text(
                  'Відкрийте розділ підписки, щоб перевірити статус premium.',
                ),
                trailing: TextButton(
                  onPressed: () => context.go('/offers/subscription'),
                  child: const Text('Відкрити'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonalIcon(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Вийти'),
            ),
          ],
        ),
      ),
    );
  }
}
