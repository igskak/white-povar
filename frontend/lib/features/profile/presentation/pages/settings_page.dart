import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme_mode_controller.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/config/product_config.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.productConfig = ProductConfig.pilot});
  final ProductConfig productConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: SafeArea(
          child: Align(
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
                        Text('Інше',
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
                              unavailable:
                                  'Контакти підтримки зʼявляться перед запуском.'),
                          const Divider(height: 1),
                          _ConfigRow(
                              icon: Icons.description_outlined,
                              title: 'Умови та конфіденційність',
                              value: productConfig.privacyUrl ??
                                  productConfig.termsUrl,
                              unavailable:
                                  'Правові документи зʼявляться перед запуском.'),
                        ])),
                        const SizedBox(height: AppSpacing.xl),
                        Center(
                            child: Text(
                                '${productConfig.appName} · ${productConfig.versionLabel}',
                                style:
                                    Theme.of(context).textTheme.labelMedium)),
                      ])))),
    );
  }
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
