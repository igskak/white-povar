import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/state_views.dart';
import '../../models/pantry_models.dart';
import '../../providers/pantry_provider.dart';

class PantryPage extends ConsumerWidget {
  const PantryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
      length: 2,
      child: Scaffold(
          appBar: AppBar(
              title: const Text('Кладова і покупки'),
              bottom: const TabBar(
                  tabs: [Tab(text: 'Кладова'), Tab(text: 'Покупки')])),
          floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Додати')),
          body: TabBarView(
              children: [_PantryTab(ref: ref), _ShoppingTab(ref: ref)])));
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<List<String>>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Додати продукт'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Назва')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Скасувати')),
                  TextButton(
                      onPressed: () =>
                          Navigator.pop(context, ['shopping', controller.text]),
                      child: const Text('До покупок')),
                  TextButton(
                      onPressed: () =>
                          Navigator.pop(context, ['pantry', controller.text]),
                      child: const Text('До кладової'))
                ]));
    if (result == null || result[1].trim().isEmpty) return;
    if (result[0] == 'pantry') {
      await ref
          .read(pantryServiceProvider)
          .addPantry(PantryItem(id: '', name: result[1].trim()));
      ref.invalidate(pantryProvider);
    } else {
      await ref.read(pantryServiceProvider).addShopping(
          ShoppingItem(id: '', name: result[1].trim(), category: 'Інше'));
      ref.invalidate(shoppingProvider);
    }
  }
}

class _PantryTab extends StatelessWidget {
  const _PantryTab({required this.ref});
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(pantryProvider);
    return value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => StateView.error(
            title: 'Не вдалося завантажити кладову',
            onRetry: () => ref.invalidate(pantryProvider)),
        data: (items) => items.isEmpty
            ? const StateView.empty(
                title: 'Кладова порожня',
                subtitle:
                    'Додайте продукти вручну або після підтвердження фото.',
                icon: Icons.kitchen_outlined)
            : ListView(
                children: items
                    .map((item) => ListTile(
                        leading: const Icon(Icons.kitchen_outlined),
                        title: Text(item.name),
                        subtitle: Text(item.quantity == null
                            ? 'Кількість не вказана'
                            : '${item.quantity} ${item.unit ?? ''}')))
                    .toList()));
  }
}

class _ShoppingTab extends StatelessWidget {
  const _ShoppingTab({required this.ref});
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(shoppingProvider);
    return value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => StateView.error(
            title: 'Не вдалося завантажити список',
            onRetry: () => ref.invalidate(shoppingProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const StateView.empty(
                title: 'Список покупок порожній',
                subtitle: 'Додайте інгредієнти з рецепта або вручну.',
                icon: Icons.shopping_cart_outlined);
          }
          final groups = <String, List<ShoppingItem>>{};
          for (final item in items) {
            (groups[item.category] ??= []).add(item);
          }
          return ListView(children: [
            for (final group in groups.entries) ...[
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(group.key,
                      style: Theme.of(context).textTheme.titleSmall)),
              ...group.value.map((item) => CheckboxListTile(
                  value: item.checked,
                  title: Text(item.name),
                  subtitle: item.quantity == null
                      ? null
                      : Text('${item.quantity} ${item.unit ?? ''}'),
                  onChanged: (checked) async {
                    await ref
                        .read(pantryServiceProvider)
                        .updateShopping(item.copyWith(checked: checked));
                    ref.invalidate(shoppingProvider);
                  }))
            ]
          ]);
        });
  }
}
