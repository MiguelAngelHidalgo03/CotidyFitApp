import 'package:shared_preferences/shared_preferences.dart';

import '../models/my_day_entry_model.dart';
import '../models/recipe_model.dart';

class MyDayLocalService {
  static const _kKey = 'cf_my_day_entries_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<MyDayEntryModel>> getAll() async {
    final p = await _prefs();
    final raw = p.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = MyDayEntryModel.decodeList(raw);
    decoded.sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
    return decoded;
  }

  Future<List<MyDayEntryModel>> getForDate(DateTime day) async {
    final key = dateKeyFromDate(day);
    final all = await getAll();
    return all.where((e) => e.dateKey == key).toList();
  }

  Future<void> add({
    required DateTime day,
    required MealType mealType,
    required String recipeId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = MyDayEntryModel(
      id: 'd_${now}_$recipeId',
      dateKey: dateKeyFromDate(day),
      mealType: mealType,
      recipeId: recipeId,
      addedAtMs: now,
    );

    final all = await getAll();
    final updated = [entry, ...all];

    final p = await _prefs();
    await p.setString(_kKey, MyDayEntryModel.encodeList(updated));
  }

  Future<void> remove(String entryId) async {
    final all = await getAll();
    final updated = all.where((e) => e.id != entryId).toList();
    final p = await _prefs();
    await p.setString(_kKey, MyDayEntryModel.encodeList(updated));
  }
}
