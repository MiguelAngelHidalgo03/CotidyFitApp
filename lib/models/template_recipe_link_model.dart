import '../utils/meal_slot_utils.dart';

/// Link between a dynamic nutrition template and a recipe.
///
/// Collection: template_recipes
/// Fields:
/// - template_id
/// - recipe_id
/// - meal_slot (desayuno | comida | post_entreno | cena | merienda |
///   postre | tentempie | entrante)
class TemplateRecipeLinkModel {
  const TemplateRecipeLinkModel({
    required this.id,
    required this.templateId,
    required this.recipeId,
    required this.mealSlot,
  });

  final String id;
  final String templateId;
  final String recipeId;
  final String mealSlot;

  static TemplateRecipeLinkModel? fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final templateId = (data['template_id'] as String?)?.trim() ?? '';
    final recipeId = (data['recipe_id'] as String?)?.trim() ?? '';
    final rawMealSlot = (data['meal_slot'] as String?)?.trim() ?? '';
    final mealSlot = normalizeMealSlot(rawMealSlot, fallback: rawMealSlot);

    if (templateId.isEmpty || recipeId.isEmpty || mealSlot.isEmpty) return null;

    return TemplateRecipeLinkModel(
      id: id,
      templateId: templateId,
      recipeId: recipeId,
      mealSlot: mealSlot,
    );
  }
}
