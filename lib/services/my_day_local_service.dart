import 'package:shared_preferences/shared_preferences.dart';

import '../models/my_day_entry_model.dart';
import '../models/recipe_model.dart';
import 'my_day_repository.dart';

class MyDayLocalService implements MyDayRepository {
  static const _kKey = 'cf_my_day_entries_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<List<MyDayEntryModel>> getAll() async {
    final p = await _prefs();
    final raw = p.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = MyDayEntryModel.decodeList(raw);
    decoded.sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
    return decoded;
  }

  @override
  Future<List<MyDayEntryModel>> getForDate(DateTime day) async {
    final key = dateKeyFromDate(day);
    final all = await getAll();
    return all.where((e) => e.dateKey == key).toList();
  }

  @override
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

  /// Adds multiple entries in one write (helper for template-to-day save).
  ///
  /// entries: list of (mealType, recipeId)
  @override
  Future<void> addMany({
    required DateTime day,
    required List<({MealType mealType, String recipeId})> entries,
  }) async {
    if (entries.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final dateKey = dateKeyFromDate(day);

    final newEntries = <MyDayEntryModel>[];
    var i = 0;
    for (final e in entries) {
      final rid = e.recipeId.trim();
      if (rid.isEmpty) continue;
      newEntries.add(
        MyDayEntryModel(
          id: 'd_${now}_${i}_$rid',
          dateKey: dateKey,
          mealType: e.mealType,
          recipeId: rid,
          addedAtMs: now,
        ),
      );
      i++;
    }
    if (newEntries.isEmpty) return;

    final all = await getAll();
    final updated = [...newEntries, ...all];

    final p = await _prefs();
    await p.setString(_kKey, MyDayEntryModel.encodeList(updated));
  }

  @override
  Future<void> remove(String entryId) async {
    final all = await getAll();
    final updated = all.where((e) => e.id != entryId).toList();
    final p = await _prefs();
    await p.setString(_kKey, MyDayEntryModel.encodeList(updated));
  }
}
