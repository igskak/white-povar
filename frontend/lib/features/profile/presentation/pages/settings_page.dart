import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme_mode_controller.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/config/product_config.dart';
import '../../../../core/services/analytics_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({
    super.key,
    this.productConfig = ProductConfig.pilot,
    this.embeddedInDesktopShell = false,
  });
  final ProductConfig productConfig;
  final bool embeddedInDesktopShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    return LayoutBuilder(builder: (context, pageConstraints) {
      final usesGlobalDesktopHeader =
          embeddedInDesktopShell && MediaQuery.sizeOf(context).width >= 1024;
      return Scaffold(
        appBar: usesGlobalDesktopHeader
            ? null
            : AppBar(title: const Text('Налаштування')),
        body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final content = Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        Text('Оформлення',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.sm),
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                child: _ThemeModeOptions(
                                    selected: themeMode,
                                    onChanged: (mode) => ref
                                        .read(appThemeModeProvider.notifier)
                                        .setMode(mode)))),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Сповіщення',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.sm),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.notifications_outlined),
                            title: const Text('Налаштування сповіщень'),
                            subtitle: const Text(
                                'Новий контент, нагадування й таймери'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.push('/notification-preferences'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Мова та підтримка',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.sm),
                        Card(
                            child: Column(children: [
                          const ListTile(
                              leading: Icon(Icons.language_outlined),
                              title: Text('Мова'),
                              trailing: Text('Українська')),
                          const Divider(height: 1),
                          _ConfigRow(
                              icon: Icons.help_outline,
                              title: 'Допомога та підтримка',
                              value: productConfig.supportEmail,
                              unavailable: 'Контакт підтримки налаштовується.'),
                          const Divider(height: 1),
                          _NoticeRow(
                              icon: Icons.description_outlined,
                              title: 'Конфіденційність у демо',
                              notice: productConfig.demoPrivacyNotice),
                          const Divider(height: 1),
                          _NoticeRow(
                              icon: Icons.info_outline,
                              title: 'Умови демо-доступу',
                              notice: productConfig.demoUseNotice),
                        ])),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Конфіденційність',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.sm),
                        const Card(child: _AnalyticsConsentTile()),
                        const SizedBox(height: AppSpacing.xl),
                        Center(
                            child: Text(
                                '${productConfig.appName} · ${productConfig.versionLabel}',
                                style:
                                    Theme.of(context).textTheme.labelMedium)),
                      ])));
          if (constraints.maxWidth < 1024) return content;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: 320, child: _DesktopSettingsSidebar()),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        })),
      );
    });
  }
}

class _DesktopSettingsSidebar extends StatelessWidget {
  const _DesktopSettingsSidebar();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Акаунт', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Профіль'),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            onTap: () => context.go('/profile'),
          ),
          const SizedBox(height: AppSpacing.xs),
          const ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Налаштування'),
            selected: true,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
          ),
          const SizedBox(height: AppSpacing.xs),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Підписка'),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            onTap: () => context.go('/offers/subscription'),
          ),
        ]),
      );
}

class _AnalyticsConsentTile extends ConsumerStatefulWidget {
  const _AnalyticsConsentTile();

  @override
  ConsumerState<_AnalyticsConsentTile> createState() =>
      _AnalyticsConsentTileState();
}

class _AnalyticsConsentTileState extends ConsumerState<_AnalyticsConsentTile> {
  bool _enabled = false;
  bool _loaded = false;
  bool _saving = false;

  Future<void> _load() async {
    try {
      final enabled = await ref.read(analyticsServiceProvider).consent();
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: _enabled,
        onChanged: !_loaded || _saving
            ? null
            : (value) async {
                setState(() => _saving = true);
                try {
                  await ref.read(analyticsServiceProvider).setConsent(value);
                  if (mounted) setState(() => _enabled = value);
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              },
        title: const Text('Анонімна аналітика використання'),
        subtitle: const Text(
            'Допомагає покращувати пошук і приготування. Не надсилаємо текст запитів, інгредієнти, email або чеки.'),
      );
}

class _ThemeModeOptions extends StatelessWidget {
  const _ThemeModeOptions({required this.selected, required this.onChanged});
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;
  @override
  Widget build(BuildContext context) => SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('Система')),
          ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Світла')),
          ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Темна')),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onChanged(selection.first),
        showSelectedIcon: false,
      );
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow(
      {required this.icon,
      required this.title,
      required this.value,
      required this.unavailable});
  final IconData icon;
  final String title;
  final String? value;
  final String unavailable;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value ?? unavailable),
        trailing:
            Icon(value == null ? Icons.schedule_outlined : Icons.open_in_new),
        onTap: value == null
            ? null
            : () => ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(value!))),
      );
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow(
      {required this.icon, required this.title, required this.notice});
  final IconData icon;
  final String title;
  final String notice;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: const Text('Переглянути'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(notice),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Зрозуміло'),
              ),
            ],
          ),
        ),
      );
}
