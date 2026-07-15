import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../auth/providers/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профіль'),
        actions: user == null
            ? null
            : [
                AppIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Налаштування',
                  onPressed: () => context.push('/settings'),
                ),
              ],
      ),
      body: SafeArea(
        child: user == null
            ? const _GuestProfile()
            : _SignedInProfile(
                email: user.email ?? 'Email не вказано',
                name: _displayName(user.userMetadata ?? const {})),
      ),
    );
  }

  String _displayName(Map<String, dynamic> metadata) =>
      (metadata['full_name'] ?? metadata['name'] ?? '').toString();
}

class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const UserAvatar(radius: 36),
                const SizedBox(height: AppSpacing.lg),
                Text('Зробіть кухню своєю',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                    'Увійдіть, щоб зберігати рецепти, памʼятати налаштування і продовжувати на будь-якому пристрої.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                    label: 'Увійти',
                    icon: Icons.login,
                    expand: true,
                    onPressed: () => context.go(
                        '/login?returnTo=${Uri.encodeComponent('/profile')}')),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                    label: 'Створити акаунт',
                    variant: AppButtonVariant.secondary,
                    expand: true,
                    onPressed: () => context.go(
                        '/login?returnTo=${Uri.encodeComponent('/profile')}')),
              ],
            ),
          ),
        ),
      );
}

class _SignedInProfile extends ConsumerWidget {
  const _SignedInProfile({required this.email, required this.name});
  final String email;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = name.isEmpty ? email.split('@').first : name;
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Row(children: [
              UserAvatar(name: displayName, radius: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(displayName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(email, style: theme.textTheme.bodyMedium)
                  ]))
            ]),
            const SizedBox(height: AppSpacing.lg),
            const _FutureStats(),
            const SizedBox(height: AppSpacing.lg),
            Card(
                child: Column(children: [
              _ProfileRow(
                  icon: Icons.bookmark_outline,
                  title: 'Збережені рецепти',
                  subtitle: 'Ваші рецепти в одному місці',
                  onTap: () => context.go('/saved')),
              const Divider(height: 1),
              const _ProfileRow(
                  icon: Icons.history,
                  title: 'Історія приготування',
                  subtitle: 'Зʼявиться після запуску історії',
                  onTap: null),
              const Divider(height: 1),
              _ProfileRow(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Підписка',
                  subtitle: 'Переглянути статус і доступ',
                  onTap: () => context.go('/offers/subscription')),
              const Divider(height: 1),
              _ProfileRow(
                  icon: Icons.settings_outlined,
                  title: 'Налаштування',
                  subtitle: 'Тема, підтримка і правові документи',
                  onTap: () => context.push('/settings')),
            ])),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
                label: 'Вийти з акаунта',
                icon: Icons.logout,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: () => ref.read(authProvider.notifier).signOut()),
          ],
        ),
      ),
    );
  }
}

class _FutureStats extends StatelessWidget {
  const _FutureStats();
  @override
  Widget build(BuildContext context) => const Row(children: [
        Expanded(child: _Stat(value: '—', label: 'Збережено')),
        SizedBox(width: AppSpacing.xs),
        Expanded(child: _Stat(value: '—', label: 'Приготовано')),
        SizedBox(width: AppSpacing.xs),
        Expanded(child: _Stat(value: '—', label: 'Сканувань')),
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.labelSmall)
          ])));
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing:
          Icon(onTap == null ? Icons.schedule_outlined : Icons.chevron_right),
      onTap: onTap);
}
