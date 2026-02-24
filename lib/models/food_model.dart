/// Global food item from the `foods` collection.
///
/// Admin-editable via the admin panel.
/// Used in custom-meal builder as searchable food presets.
class FoodModel {
  const FoodModel({
    required this.id,
    required this.name,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.category = '',
  });

  final String id;
  final String name;
  final int kcalPer100g;
  final int proteinPer100g;
  final int carbsPer100g;
  final int fatPer100g;
  final String category;

  Map<String, dynamic> toJson() => {
        'name': name,
        'kcalPer100g': kcalPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
        'category': category,
      };

  static FoodModel? fromFirestore(String id, Map<String, dynamic> data) {
    final name = data['name'];
    if (name is! String || name.trim().isEmpty) return null;

    final kcal = data['kcalPer100g'];
    final protein = data['proteinPer100g'];
    final carbs = data['carbsPer100g'];
    final fat = data['fatPer100g'];

    if (kcal is! num || protein is! num || carbs is! num || fat is! num) {
      return null;
    }

    final category = data['category'];

    return FoodModel(
      id: id,
      name: name,
      kcalPer100g: kcal.toInt(),
      proteinPer100g: protein.toInt(),
      carbsPer100g: carbs.toInt(),
      fatPer100g: fat.toInt(),
      category: category is String ? category : '',
    );
  }
}
