/// Link between a dynamic nutrition template and a recipe.
///
/// Collection: template_recipes
/// Fields:
/// - template_id
/// - recipe_id
/// - meal_slot (desayuno | comida | merienda | cena)
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
    final mealSlot = (data['meal_slot'] as String?)?.trim() ?? '';

    if (templateId.isEmpty || recipeId.isEmpty || mealSlot.isEmpty) return null;

    return TemplateRecipeLinkModel(
      id: id,
      templateId: templateId,
      recipeId: recipeId,
      mealSlot: mealSlot,
    );
  }
}
