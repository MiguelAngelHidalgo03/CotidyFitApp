import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/theme.dart';
import '../../../models/custom_meal_model.dart';
import '../../../models/food_model.dart';
import '../../../models/recipe_model.dart';
import '../../../services/custom_foods_firestore_service.dart';
import '../../../services/foods_firestore_service.dart';
import '../../../widgets/progress/progress_section_card.dart';

class FoodPreset {
  const FoodPreset({
    required this.name,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  final String name;
  final int kcalPer100g;
  final int proteinPer100g;
  final int carbsPer100g;
  final int fatPer100g;

  CustomMealFoodItem toItemForGrams(int grams) {
    int scale(int v) => ((v * grams) / 100).round();
    return CustomMealFoodItem(
      name: name,
      grams: grams,
      kcal: scale(kcalPer100g),
      proteinG: scale(proteinPer100g),
      carbsG: scale(carbsPer100g),
      fatG: scale(fatPer100g),
    );
  }
}

class CustomMealDraftResult {
  const CustomMealDraftResult({
    required this.mealType,
    required this.meal,
  });

  final MealType mealType;
  final CustomMealModel meal;
}

class CustomMealBottomSheet extends StatefulWidget {
  const CustomMealBottomSheet({
    super.key,
    this.initialMealType = MealType.lunch,
  });

  final MealType initialMealType;

  @override
  State<CustomMealBottomSheet> createState() => _CustomMealBottomSheetState();
}

class _CustomMealBottomSheetState extends State<CustomMealBottomSheet> {
  final _nameCtrl = TextEditingController();

  MealType _mealType = MealType.lunch;
  final List<CustomMealFoodItem> _items = [];

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _kcalTotal => _items.fold<int>(0, (a, b) => a + b.kcal);
  int get _proteinTotal => _items.fold<int>(0, (a, b) => a + b.proteinG);
  int get _carbsTotal => _items.fold<int>(0, (a, b) => a + b.carbsG);
  int get _fatTotal => _items.fold<int>(0, (a, b) => a + b.fatG);

  Future<void> _addPresetFlow() async {
    final preset = await showModalBottomSheet<FoodPreset>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _PresetPickerSheet(),
    );

    if (!mounted) return;

    if (preset == null) return;

    final grams = await showDialog<int>(
      context: context,
      builder: (context) => _GramsDialog(foodName: preset.name),
    );

    if (!mounted) return;

    if (grams == null) return;

    setState(() {
      _items.add(preset.toItemForGrams(grams));
    });
  }

  void _removeAt(int index) {
    setState(() => _items.removeAt(index));
  }

  void _save() {
    final nombre = _nameCtrl.text.trim();
    if (nombre.isEmpty) return;
    if (_items.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final meal = CustomMealModel(
      id: 'm_$now',
      nombre: nombre,
      listaAlimentos: [..._items],
      calorias: _kcalTotal,
      proteinas: _proteinTotal,
      carbohidratos: _carbsTotal,
      grasas: _fatTotal,
    );

    Navigator.of(context).pop(CustomMealDraftResult(mealType: _mealType, meal: meal));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ProgressSectionCard(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Agregar comida personalizada',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del plato',
                    hintText: 'Ej: Bowl de pollo y arroz',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MealType>(
                  initialValue: _mealType,
                  decoration: const InputDecoration(labelText: 'Tipo de comida'),
                  items: [
                    for (final m in MealType.values)
                      DropdownMenuItem(
                        value: m,
                        child: Text(m.label),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _mealType = v);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Alimentos',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addPresetFlow,
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_items.isEmpty)
                  Text(
                    'Añade al menos un alimento predeterminado para estimar macros.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                for (var i = 0; i < _items.length; i++) ...[
                  _FoodRow(
                    item: _items[i],
                    onRemove: () => _removeAt(i),
                  ),
                  if (i != _items.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CFColors.background,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    border: Border.all(color: CFColors.softGray),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _TotalStat(label: 'Kcal', value: '$_kcalTotal')),
                      Expanded(child: _TotalStat(label: 'Proteína', value: '${_proteinTotal}g')),
                      Expanded(child: _TotalStat(label: 'Carbohidratos', value: '${_carbsTotal}g')),
                      Expanded(child: _TotalStat(label: 'Grasas', value: '${_fatTotal}g')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.item, required this.onRemove});

  final CustomMealFoodItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.grams} g · ${item.kcal} kcal · P ${item.proteinG}g · C ${item.carbsG}g · G ${item.fatG}g',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, color: CFColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TotalStat extends StatelessWidget {
  const _TotalStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900, color: CFColors.textPrimary),
        ),
      ],
    );
  }
}

class _PresetPickerSheet extends StatefulWidget {
  const _PresetPickerSheet();

  @override
  State<_PresetPickerSheet> createState() => _PresetPickerSheetState();
}

class _PresetPickerSheetState extends State<_PresetPickerSheet> {
  String _q = '';
  List<FoodPreset>? _allFoods;
  bool _loading = true;

  final _globalFoodsService = FoodsFirestoreService();
  final _customFoodsService = CustomFoodsFirestoreService();

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    // Guard: skip Firestore when not authenticated.
    if (Firebase.apps.isEmpty ||
        FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _allFoods = const [];
        _loading = false;
      });
      return;
    }

    try {
      final globalFoods = await _globalFoodsService
          .getAllFoods()
          .timeout(const Duration(seconds: 10));

      List<FoodModel> customFoods = const [];
      try {
        customFoods = await _customFoodsService
            .getAll()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('_PresetPickerSheet: custom foods error (ignored): $e');
      }

      final fromFirestore = <FoodPreset>[
        for (final f in globalFoods)
          FoodPreset(
            name: f.name,
            kcalPer100g: f.kcalPer100g,
            proteinPer100g: f.proteinPer100g,
            carbsPer100g: f.carbsPer100g,
            fatPer100g: f.fatPer100g,
          ),
        for (final f in customFoods)
          FoodPreset(
            name: '\u2605 ${f.name}',
            kcalPer100g: f.kcalPer100g,
            proteinPer100g: f.proteinPer100g,
            carbsPer100g: f.carbsPer100g,
            fatPer100g: f.fatPer100g,
          ),
      ];

      if (!mounted) return;

      setState(() {
        _allFoods = fromFirestore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('_PresetPickerSheet._loadFoods error: $e');
      setState(() {
        _allFoods = const [];
        _loading = false;
      });
    }
  }

  Future<void> _createCustomFood() async {
    final result = await showDialog<FoodModel>(
      context: context,
      builder: (context) => const _CreateCustomFoodDialog(),
    );

    if (!mounted || result == null) return;

    try {
      // Save to Firestore
      await _customFoodsService.add(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar alimento: $e')),
      );
      // Still let user pick it even if save fails
    }

    // Add directly to list so user can pick it immediately
    final preset = FoodPreset(
      name: '\u2605 ${result.name}',
      kcalPer100g: result.kcalPer100g,
      proteinPer100g: result.proteinPer100g,
      carbsPer100g: result.carbsPer100g,
      fatPer100g: result.fatPer100g,
    );

    if (!mounted) return;
    Navigator.of(context).pop(preset);
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final foods = _allFoods ?? const <FoodPreset>[];
    final list = foods
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ProgressSectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Añadir alimento', style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar alimento…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _createCustomFood,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Crear alimento personalizado'),
                ),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      _q.isEmpty
                          ? 'No hay alimentos en la base de datos.\nCrea uno personalizado.'
                          : 'Sin resultados para "$_q".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = list[index];
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(p),
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CFColors.surface,
                          borderRadius: const BorderRadius.all(Radius.circular(16)),
                          border: Border.all(color: CFColors.softGray),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Por 100g · ${p.kcalPer100g} kcal · P ${p.proteinPer100g}g · C ${p.carbsPer100g}g · G ${p.fatPer100g}g',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: CFColors.textSecondary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GramsDialog extends StatefulWidget {
  const _GramsDialog({required this.foodName});

  final String foodName;

  @override
  State<_GramsDialog> createState() => _GramsDialogState();
}

class _GramsDialogState extends State<_GramsDialog> {
  final _ctrl = TextEditingController(text: '100');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.foodName),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Cantidad (g)',
          hintText: 'Ej: 150',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(_ctrl.text.trim());
            if (v == null || v <= 0) return;
            Navigator.of(context).pop(v);
          },
          child: const Text('Añadir'),
        ),
      ],
    );
  }
}

class _CreateCustomFoodDialog extends StatefulWidget {
  const _CreateCustomFoodDialog();

  @override
  State<_CreateCustomFoodDialog> createState() => _CreateCustomFoodDialogState();
}

class _CreateCustomFoodDialogState extends State<_CreateCustomFoodDialog> {
  final _nameCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un nombre.')),
      );
      return;
    }
    final kcal = int.tryParse(_kcalCtrl.text.trim());
    final protein = int.tryParse(_proteinCtrl.text.trim());
    final carbs = int.tryParse(_carbsCtrl.text.trim());
    final fat = int.tryParse(_fatCtrl.text.trim());
    if (kcal == null || protein == null || carbs == null || fat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rellena todos los campos numéricos.')),
      );
      return;
    }

    Navigator.of(context).pop(FoodModel(
      id: '',
      name: name,
      kcalPer100g: kcal,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo alimento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Valores por 100 g',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _kcalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kcal'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _proteinCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Proteína (g)'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _carbsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Carbohidratos (g)'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _fatCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Grasas (g)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
