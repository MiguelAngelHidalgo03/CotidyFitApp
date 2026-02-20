import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/custom_meal_model.dart';
import '../../../models/recipe_model.dart';
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

  static const List<FoodPreset> presets = [
    FoodPreset(name: 'Pechuga de pollo', kcalPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 4),
    FoodPreset(name: 'Atún al natural', kcalPer100g: 116, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 1),
    FoodPreset(name: 'Huevo', kcalPer100g: 143, proteinPer100g: 13, carbsPer100g: 1, fatPer100g: 10),
    FoodPreset(name: 'Arroz cocido', kcalPer100g: 130, proteinPer100g: 3, carbsPer100g: 28, fatPer100g: 0),
    FoodPreset(name: 'Avena', kcalPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7),
    FoodPreset(name: 'Yogur griego', kcalPer100g: 97, proteinPer100g: 10, carbsPer100g: 4, fatPer100g: 5),
    FoodPreset(name: 'Plátano', kcalPer100g: 89, proteinPer100g: 1, carbsPer100g: 23, fatPer100g: 0),
    FoodPreset(name: 'Lentejas cocidas', kcalPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0),
    FoodPreset(name: 'Aceite de oliva', kcalPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100),
    FoodPreset(name: 'Pan integral', kcalPer100g: 247, proteinPer100g: 13, carbsPer100g: 41, fatPer100g: 4),
  ];

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

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = CustomMealBottomSheet.presets
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
