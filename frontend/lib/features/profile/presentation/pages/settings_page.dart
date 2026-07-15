import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme_mode_controller.dart';
import '../../../../app/theme/tokens/app_tokens.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'Оформлення',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.palette_outlined),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Тема Chef’s Table',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ThemeModeOptions(
                      selected: themeMode,
                      onChanged: (mode) =>
                          ref.read(appThemeModeProvider.notifier).setMode(mode),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Акаунт',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Основні дії доступні в профілі'),
                subtitle: Text(
                  'Підписка, вихід з акаунта і статус доступу залишаються в реальних існуючих розділах.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeOptions extends StatelessWidget {
  const _ThemeModeOptions({required this.selected, required this.onChanged});

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: selected,
            onChanged: (mode) => onChanged(mode!),
            secondary: const Icon(Icons.brightness_auto_outlined),
            title: const Text('Система'),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: selected,
            onChanged: (mode) => onChanged(mode!),
            secondary: const Icon(Icons.light_mode_outlined),
            title: const Text('Світла'),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: selected,
            onChanged: (mode) => onChanged(mode!),
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Темна'),
          ),
        ],
      );
}
