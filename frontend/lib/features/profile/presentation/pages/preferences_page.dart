import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../models/preference_profile.dart';
import '../../providers/preference_provider.dart';

class PreferencesPage extends ConsumerStatefulWidget {
  const PreferencesPage({super.key});

  @override
  ConsumerState<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends ConsumerState<PreferencesPage> {
  final _diets = TextEditingController();
  final _allergens = TextEditingController();
  final _dislikes = TextEditingController();
  final _equipment = TextEditingController();
  final _time = TextEditingController();
  final _household = TextEditingController();
  bool _consent = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _diets,
      _allergens,
      _dislikes,
      _equipment,
      _time,
      _household
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _populate(PreferenceProfile value) {
    if (_loaded) return;
    _loaded = true;
    _diets.text = value.diets.join(', ');
    _allergens.text = value.allergens.join(', ');
    _dislikes.text = value.dislikes.join(', ');
    _equipment.text = value.equipment.join(', ');
    _time.text = value.preferredMaxTotalTime?.toString() ?? '';
    _household.text = value.householdSize?.toString() ?? '';
    _consent = value.personalizationConsent;
  }

  List<String> _terms(TextEditingController controller) => controller.text
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Підтвердьте згоду, щоб зберегти профіль.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(preferenceServiceProvider).save(PreferenceProfile(
            diets: _terms(_diets),
            allergens: _terms(_allergens),
            dislikes: _terms(_dislikes),
            equipment: _terms(_equipment),
            preferredMaxTotalTime: int.tryParse(_time.text),
            householdSize: int.tryParse(_household.text),
            personalizationConsent: true,
          ));
      ref.invalidate(preferenceProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Налаштування збережено')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    await ref.read(preferenceServiceProvider).reset();
    setState(() {
      _loaded = false;
      _consent = false;
      for (final controller in [
        _diets,
        _allergens,
        _dislikes,
        _equipment,
        _time,
        _household
      ]) {
        controller.clear();
      }
    });
    ref.invalidate(preferenceProfileProvider);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Харчові налаштування')),
        body: ref.watch(preferenceProfileProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                  child: Text('Не вдалося завантажити налаштування')),
              data: (profile) {
                _populate(profile);
                return ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      const Text('Допоможемо підібрати рецепти',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                          'Алергени виключають рецепти з пошуку. Перевіряйте склад самостійно, особливо для важких алергій.'),
                      const SizedBox(height: AppSpacing.lg),
                      _field(_diets, 'Раціон', 'Наприклад: vegetarian, vegan'),
                      _field(
                          _allergens, 'Алергени', 'Наприклад: горіхи, молоко'),
                      _field(_dislikes, 'Не люблю', 'Наприклад: кінза'),
                      _field(_equipment, 'Обладнання',
                          'Наприклад: духовка, блендер'),
                      _field(_time, 'Бажаний час, хв', 'До 60', numeric: true),
                      _field(_household, 'Кількість людей удома', '2',
                          numeric: true),
                      SwitchListTile(
                        value: _consent,
                        onChanged: (value) => setState(() => _consent = value),
                        title: const Text('Згода на персоналізацію'),
                        subtitle: const Text(
                            'Зберігаємо ці дані у вашому профілі та застосовуємо їх до пошуку.'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                          label: _saving ? 'Зберігаємо…' : 'Зберегти',
                          expand: true,
                          onPressed: _saving ? null : _save),
                      TextButton(
                          onPressed: _saving ? null : _reset,
                          child: const Text('Скинути профіль')),
                    ]);
              },
            ),
      );

  Widget _field(TextEditingController controller, String label, String hint,
          {bool numeric = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: TextField(
            controller: controller,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(labelText: label, hintText: hint)),
      );
}
