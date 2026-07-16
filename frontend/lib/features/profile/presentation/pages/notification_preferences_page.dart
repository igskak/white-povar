import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../models/notification_preferences.dart';
import '../../providers/notification_provider.dart';

class NotificationPreferencesPage extends ConsumerStatefulWidget {
  const NotificationPreferencesPage({super.key});
  @override
  ConsumerState<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends ConsumerState<NotificationPreferencesPage> {
  NotificationPreferences? _value;
  bool _saving = false;

  void _load(NotificationPreferences value) => _value ??= value;

  Future<void> _save() async {
    final value = _value;
    if (value == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(notificationServiceProvider).save(value);
      ref.invalidate(notificationPreferencesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Налаштування сповіщень збережено')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Сповіщення')),
        body: ref.watch(notificationPreferencesProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                  child: Text('Не вдалося завантажити налаштування')),
              data: (saved) {
                _load(saved);
                final value = _value!;
                return ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      const Text('Керуйте тим, що надсилає Олександр',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                          'Нові матеріали — маркетингові повідомлення й вимкнені, доки ви не дасте згоду.'),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile(
                        value: value.marketingConsent,
                        onChanged: (enabled) =>
                            setState(() => _value = value.copyWith(
                                  marketingConsent: enabled,
                                  newContent:
                                      enabled ? value.newContent : false,
                                )),
                        title: const Text('Згода на маркетингові повідомлення'),
                      ),
                      SwitchListTile(
                        value: value.newContent,
                        onChanged: value.marketingConsent
                            ? (enabled) => setState(() =>
                                _value = value.copyWith(newContent: enabled))
                            : null,
                        title: const Text('Нові рецепти й колекції'),
                        subtitle: const Text(
                            'Повідомлення про новий контент Олександра'),
                      ),
                      const Divider(),
                      SwitchListTile(
                        value: value.savedRecipeReminders,
                        onChanged: (enabled) => setState(() => _value =
                            value.copyWith(savedRecipeReminders: enabled)),
                        title: const Text('Нагадати про збережене'),
                      ),
                      SwitchListTile(
                        value: value.cookingReminders,
                        onChanged: (enabled) => setState(() =>
                            _value = value.copyWith(cookingReminders: enabled)),
                        title: const Text('Продовжити приготування'),
                      ),
                      SwitchListTile(
                        value: value.timerAlerts,
                        onChanged: (enabled) => setState(() =>
                            _value = value.copyWith(timerAlerts: enabled)),
                        title: const Text('Таймери'),
                        subtitle: const Text(
                            'Сервісне сповіщення про завершення таймера'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.bedtime_outlined),
                        title: const Text('Тихі години'),
                        subtitle: Text(_quietHoursLabel(value)),
                        trailing: TextButton(
                          onPressed: () => _chooseQuietHours(value),
                          child: const Text('Змінити'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                          label: _saving ? 'Зберігаємо…' : 'Зберегти',
                          expand: true,
                          onPressed: _saving ? null : _save),
                    ]);
              },
            ),
      );

  String _quietHoursLabel(NotificationPreferences value) {
    final start = value.quietHoursStart;
    final end = value.quietHoursEnd;
    return start == null || end == null
        ? 'Не налаштовано'
        : '$start — $end; не стосується активного таймера';
  }

  Future<void> _chooseQuietHours(NotificationPreferences value) async {
    final start = await showTimePicker(
      context: context,
      initialTime:
          _time(value.quietHoursStart) ?? const TimeOfDay(hour: 22, minute: 0),
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime:
          _time(value.quietHoursEnd) ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (end == null || !mounted) return;
    setState(() => _value = value.copyWith(
          quietHoursStart: _formatTime(start),
          quietHoursEnd: _formatTime(end),
        ));
  }

  TimeOfDay? _time(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    return hour == null || minute == null
        ? null
        : TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
}
