import '../models/diet_template_model.dart';
import '../models/price_tier.dart';
import 'diet_templates_repository.dart';

class DietTemplatesLocalService implements DietTemplatesRepository {
  static const List<DietTemplateModel> _templates = [
    DietTemplateModel(
      id: 'tpl_fat_loss_v1',
      kind: DietTemplateKind.fatLoss,
      priceTier: PriceTier.medium,
      estimatedCalories: 1800,
      macros: MacroSplit(proteinPct: 35, carbsPct: 35, fatPct: 30),
      exampleDay: [
        DietExampleMeal(meal: 'Desayuno', example: 'Yogur griego + avena + frutos rojos'),
        DietExampleMeal(meal: 'Comida', example: 'Ensalada de pollo + patata cocida'),
        DietExampleMeal(meal: 'Merienda', example: 'Manzana + proteína en polvo (batido)'),
        DietExampleMeal(meal: 'Cena', example: 'Salmón + brócoli + arroz'),
      ],
      shoppingList: [
        'Yogur griego natural',
        'Avena',
        'Frutos rojos',
        'Pechuga de pollo',
        'Mix de ensalada',
        'Patata',
        'Manzana',
        'Proteína en polvo',
        'Salmón',
        'Brócoli',
        'Arroz',
      ],
    ),
    DietTemplateModel(
      id: 'tpl_maintenance_v1',
      kind: DietTemplateKind.maintenance,
      priceTier: PriceTier.high,
      estimatedCalories: 2300,
      macros: MacroSplit(proteinPct: 30, carbsPct: 40, fatPct: 30),
      exampleDay: [
        DietExampleMeal(meal: 'Desayuno', example: 'Tortilla (2-3 huevos) + pan integral'),
        DietExampleMeal(meal: 'Comida', example: 'Pasta integral + atún + verduras'),
        DietExampleMeal(meal: 'Merienda', example: 'Fruta + frutos secos'),
        DietExampleMeal(meal: 'Cena', example: 'Pavo + quinoa + ensalada'),
      ],
      shoppingList: [
        'Huevos',
        'Pan integral',
        'Pasta integral',
        'Atún',
        'Verduras variadas',
        'Fruta',
        'Frutos secos',
        'Pavo',
        'Quinoa',
        'Ensalada',
      ],
    ),
    DietTemplateModel(
      id: 'tpl_bulk_v1',
      kind: DietTemplateKind.bulk,
      priceTier: PriceTier.economical,
      estimatedCalories: 2800,
      macros: MacroSplit(proteinPct: 25, carbsPct: 50, fatPct: 25),
      exampleDay: [
        DietExampleMeal(meal: 'Desayuno', example: 'Avena + leche + plátano + crema de cacahuete'),
        DietExampleMeal(meal: 'Comida', example: 'Arroz + ternera + aceite de oliva + verduras'),
        DietExampleMeal(meal: 'Merienda', example: 'Bocadillo integral + yogur'),
        DietExampleMeal(meal: 'Cena', example: 'Sándwich de pollo + patata + ensalada'),
      ],
      shoppingList: [
        'Avena',
        'Leche',
        'Plátano',
        'Crema de cacahuete',
        'Arroz',
        'Ternera',
        'Aceite de oliva',
        'Verduras variadas',
        'Pan integral',
        'Yogur',
        'Pechuga de pollo',
        'Patata',
        'Ensalada',
      ],
    ),
  ];

  @override
  Future<List<DietTemplateModel>> getTemplates() async {
    return _templates;
  }

  @override
  Future<DietTemplateModel?> getTemplateById(String id) async {
    for (final t in _templates) {
      if (t.id == id) return t;
    }
    return null;
  }
}
