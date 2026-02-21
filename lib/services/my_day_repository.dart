import '../models/my_day_entry_model.dart';
import '../models/recipe_model.dart';

abstract class MyDayRepository {
  Future<List<MyDayEntryModel>> getAll();
  Future<List<MyDayEntryModel>> getForDate(DateTime day);

  Future<void> add({
    required DateTime day,
    required MealType mealType,
    required String recipeId,
  });

  Future<void> addMany({
    required DateTime day,
    required List<({MealType mealType, String recipeId})> entries,
  });

  Future<void> remove(String entryId);
}
