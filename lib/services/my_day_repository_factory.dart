import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/my_day_entry_model.dart';
import '../models/recipe_model.dart';
import 'my_day_firestore_service.dart';
import 'my_day_local_service.dart';
import 'my_day_repository.dart';

class MyDayRepositoryFactory {
  static MyDayRepository create() {
    if (Firebase.apps.isEmpty) return MyDayLocalService();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return MyDayLocalService();
    return _MyDayMigratingRepository(
      remote: MyDayFirestoreService(),
      local: MyDayLocalService(),
    );
  }
}

class _MyDayMigratingRepository implements MyDayRepository {
  _MyDayMigratingRepository({required this.remote, required this.local});

  final MyDayFirestoreService remote;
  final MyDayLocalService local;

  @override
  Future<List<MyDayEntryModel>> getAll() async {
    try {
      final remoteAll = await remote.getAll();
      if (remoteAll.isNotEmpty) return remoteAll;
    } catch (_) {
      // ignore
    }
    return local.getAll();
  }

  @override
  Future<List<MyDayEntryModel>> getForDate(DateTime day) async {
    List<MyDayEntryModel> remoteItems = const [];
    try {
      remoteItems = await remote.getForDate(day);
    } catch (_) {
      remoteItems = const [];
    }

    if (remoteItems.isNotEmpty) return remoteItems;

    final localItems = await local.getForDate(day);
    if (localItems.isEmpty) return const [];

    // Best-effort migration: keep the same entry ids.
    try {
      await remote.setEntries(localItems);
      final after = await remote.getForDate(day);
      if (after.isNotEmpty) return after;
    } catch (_) {
      // ignore
    }

    return localItems;
  }

  @override
  Future<void> add({
    required DateTime day,
    required MealType mealType,
    required String recipeId,
  }) async {
    await remote.add(day: day, mealType: mealType, recipeId: recipeId);
  }

  @override
  Future<void> addMany({
    required DateTime day,
    required List<({MealType mealType, String recipeId})> entries,
  }) async {
    await remote.addMany(day: day, entries: entries);
  }

  @override
  Future<void> remove(String entryId) async {
    await remote.remove(entryId);
  }
}
