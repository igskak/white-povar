import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../features/studio/studio_brand_draft_service.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../subscription/providers/subscription_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key, this.embeddedInDesktopShell = false});

  final bool embeddedInDesktopShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return LayoutBuilder(builder: (context, constraints) {
      final usesGlobalDesktopHeader =
          embeddedInDesktopShell && constraints.maxWidth >= 1024;
      return Scaffold(
        appBar: usesGlobalDesktopHeader
            ? null
            : AppBar(
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
    });
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
    final studioSession = ref.watch(studioSessionProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final content = ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(children: [
          UserAvatar(name: displayName, radius: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(displayName, style: theme.textTheme.titleLarge),
                    AppBadge(
                      label: isPremium ? 'Premium активна' : 'Free',
                      icon: isPremium
                          ? Icons.workspace_premium
                          : Icons.person_outline,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(email, style: theme.textTheme.bodyMedium)
              ]))
        ]),
        const SizedBox(height: AppSpacing.lg),
        const _FutureStats(),
        const SizedBox(height: AppSpacing.lg),
        studioSession.when(
          data: (session) => session == null
              ? const SizedBox.shrink()
              : _StudioAccessCard(role: session.role),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
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
              subtitle:
                  isPremium ? 'Premium доступ активний' : 'Безкоштовний доступ',
              onTap: () => context.go('/offers/subscription')),
          const Divider(height: 1),
          _ProfileRow(
              icon: Icons.tune_outlined,
              title: 'Харчові налаштування',
              subtitle: 'Раціон, алергени та вподобання',
              onTap: () => context.push('/preferences')),
          const Divider(height: 1),
          _ProfileRow(
              icon: Icons.notifications_outlined,
              title: 'Сповіщення',
              subtitle: 'Новий контент, нагадування й таймери',
              onTap: () => context.push('/notification-preferences')),
          const Divider(height: 1),
          _ProfileRow(
              icon: Icons.kitchen_outlined,
              title: 'Кладова і покупки',
              subtitle: 'Продукти вдома та список покупок',
              onTap: () => context.push('/pantry')),
          const Divider(height: 1),
          _ProfileRow(
              icon: Icons.settings_outlined,
              title: 'Налаштування',
              subtitle: 'Тема, підтримка і правові документи',
              onTap: () => context.push('/settings')),
        ])),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Column(children: [
            _ProfileRow(
              icon: Icons.link,
              title: 'Спосіб входу',
              subtitle: 'Підключити Google до цього акаунта',
              onTap: () => ref
                  .read(authProvider.notifier)
                  .linkIdentity(OAuthProvider.google),
            ),
            const Divider(height: 1),
            _ProfileRow(
              icon: Icons.delete_outline,
              title: 'Видалити акаунт',
              subtitle: 'Назавжди видалити профіль і приватні дані',
              onTap: () => _confirmDeletion(context, ref),
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
            label: 'Вийти з акаунта',
            icon: Icons.logout,
            variant: AppButtonVariant.secondary,
            expand: true,
            onPressed: () => ref.read(authProvider.notifier).signOut()),
      ],
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 1024) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680), child: content),
        );
      }
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                width: 320,
                child: _DesktopProfileSidebar(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _confirmDeletion(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити акаунт?'),
        content: const Text(
          'Збережені рецепти, історія та інші приватні дані буде видалено назавжди.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).deleteAccount();
    }
  }
}

class _DesktopProfileSidebar extends StatelessWidget {
  const _DesktopProfileSidebar();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SidebarDestination(
              icon: Icons.person_outline,
              label: 'Профіль',
              selected: true,
              onTap: () {}),
          _SidebarDestination(
              icon: Icons.bookmark_outline,
              label: 'Збережене',
              onTap: () => context.go('/saved')),
          _SidebarDestination(
              icon: Icons.workspace_premium_outlined,
              label: 'Підписка',
              onTap: () => context.go('/offers/subscription')),
          _SidebarDestination(
              icon: Icons.settings_outlined,
              label: 'Налаштування',
              onTap: () => context.push('/settings')),
        ]),
      );
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: ListTile(
          selected: selected,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          leading: Icon(icon),
          title: Text(label),
          onTap: onTap,
        ),
      );
}

class _StudioAccessCard extends StatelessWidget {
  const _StudioAccessCard({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.dashboard_customize_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Creator Studio',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Text(role == 'admin' ? 'Адміністратор' : 'Редактор',
                      style: Theme.of(context).textTheme.labelSmall),
                ]),
                const SizedBox(height: AppSpacing.xs),
                Text('Оформлення бренду, контент і колекції.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Відкрити Studio',
                  icon: Icons.arrow_forward,
                  expand: true,
                  onPressed: () => context.go('/studio/brand'),
                ),
              ],
            ),
          ),
        ),
      );
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
