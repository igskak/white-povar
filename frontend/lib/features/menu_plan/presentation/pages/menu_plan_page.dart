import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/state_views.dart';
import '../../models/menu_plan.dart';
import '../../providers/menu_plan_provider.dart';

class MenuPlanPage extends ConsumerStatefulWidget {
  const MenuPlanPage({super.key});
  @override
  ConsumerState<MenuPlanPage> createState() => _MenuPlanPageState();
}

class _MenuPlanPageState extends ConsumerState<MenuPlanPage> {
  late DateTime _monday = _weekStart(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(menuPlanWeekProvider(_monday));
    return Scaffold(
      appBar: AppBar(title: const Text('Меню на тиждень'), actions: [
        IconButton(
            tooltip: 'Поділитися',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _share),
        IconButton(
            tooltip: 'До покупок',
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: _shopping),
      ]),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => StateView.error(
            title: 'Не вдалося відкрити план',
            onRetry: () => ref.invalidate(menuPlanWeekProvider(_monday))),
        data: (plan) => Column(children: [
          _WeekHeader(
              monday: _monday,
              onPrevious: () => setState(
                  () => _monday = _monday.subtract(const Duration(days: 7))),
              onNext: () => setState(
                  () => _monday = _monday.add(const Duration(days: 7)))),
          Expanded(
              child: _Planner(
                  days: List.generate(
                      7, (index) => _monday.add(Duration(days: index))),
                  slots: plan.slots,
                  onChanged: () =>
                      ref.invalidate(menuPlanWeekProvider(_monday)))),
        ]),
      ),
    );
  }

  Future<void> _share() async {
    final text = await ref.read(menuPlanServiceProvider).share(_monday);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Меню скопійовано для поширення')));
    }
  }

  Future<void> _shopping() async {
    await ref.read(menuPlanServiceProvider).addMissing(_monday);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Відсутні інгредієнти об’єднано у покупках')));
    }
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader(
      {required this.monday, required this.onPrevious, required this.onNext});
  final DateTime monday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Expanded(
            child: Text(
                '${monday.day}.${monday.month} — ${monday.add(const Duration(days: 6)).day}.${monday.add(const Duration(days: 6)).month}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium)),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ]));
}

class _Planner extends ConsumerWidget {
  const _Planner(
      {required this.days, required this.slots, required this.onChanged});
  final List<DateTime> days;
  final List<MenuPlanSlot> slots;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(children: [
        for (final day in days)
          _Day(
              day: day,
              slots: slots
                  .where((slot) => _sameDay(slot.plannedFor, day))
                  .toList(),
              onChanged: onChanged)
      ]);
}

class _Day extends ConsumerWidget {
  const _Day({required this.day, required this.slots, required this.onChanged});
  final DateTime day;
  final List<MenuPlanSlot> slots;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Padding(
            padding: const EdgeInsets.all(8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_dayName(day),
                  style: Theme.of(context).textTheme.titleMedium),
              if (slots.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Ще нічого не заплановано')),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex--;
                  final changed = [...slots];
                  final slot = changed.removeAt(oldIndex);
                  changed.insert(newIndex, slot);
                  await ref
                      .read(menuPlanServiceProvider)
                      .reorder(_weekStart(day), changed);
                  onChanged();
                },
                children: [
                  for (final slot in slots)
                    _Slot(
                        key: ValueKey(slot.id),
                        slot: slot,
                        onChanged: onChanged)
                ],
              ),
            ])),
      );
}

class _Slot extends ConsumerWidget {
  const _Slot({super.key, required this.slot, required this.onChanged});
  final MenuPlanSlot slot;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
        leading: const Icon(Icons.drag_handle),
        title: Text(slot.title),
        subtitle: Text(
            '${slot.servings} порц.${slot.isPremium ? ' · Premium перевіряється при відкритті' : ''}'),
        onTap: () => context.push('/recipes/${slot.recipeId}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'delete') {
              await ref.read(menuPlanServiceProvider).remove(slot.id);
            } else {
              await ref.read(menuPlanServiceProvider).update(slot.copyWith(
                  servings: value == 'plus'
                      ? slot.servings + 1
                      : (slot.servings - 1).clamp(1, 100)));
            }
            onChanged();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'minus', child: Text('Менше порцій')),
            PopupMenuItem(value: 'plus', child: Text('Більше порцій')),
            PopupMenuItem(value: 'delete', child: Text('Прибрати'))
          ],
        ),
      );
}

DateTime _weekStart(DateTime date) => DateTime(date.year, date.month, date.day)
    .subtract(Duration(days: date.weekday - 1));
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _dayName(DateTime day) => const [
      'Понеділок',
      'Вівторок',
      'Середа',
      'Четвер',
      'П’ятниця',
      'Субота',
      'Неділя'
    ][day.weekday - 1];
