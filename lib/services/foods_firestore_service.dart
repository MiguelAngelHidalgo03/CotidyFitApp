import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/food_model.dart';

/// Service for the global `foods` collection (admin-editable).
///
/// Read-only for regular users.
class FoodsFirestoreService {
  final FirebaseFirestore? _dbOverride;

  FoodsFirestoreService({FirebaseFirestore? db}) : _dbOverride = db;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  String _readText(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value != null) {
        final raw = value.toString().trim();
        if (raw.isNotEmpty) return raw;
      }
    }
    return fallback;
  }

  int _readInt(Map<String, dynamic> data, List<String> keys, int fallback) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = num.tryParse(value.trim().replaceAll(',', '.'));
        if (parsed != null) return parsed.toInt();
      }
    }
    return fallback;
  }

  FoodModel? _foodFromDocument(String id, Map<String, dynamic> data) {
    final normalized = <String, dynamic>{...data};
    normalized['name'] = _readText(normalized, const [
      'name',
      'nombre',
    ], fallback: id);
    normalized['category'] = _readText(normalized, const [
      'category',
      'categoria',
    ]);
    normalized['kcalPer100g'] = _readInt(normalized, const [
      'kcalPer100g',
      'kcal_per_100g',
      'calorias',
      'calorias_por_100g',
    ], 0);
    normalized['proteinPer100g'] = _readInt(normalized, const [
      'proteinPer100g',
      'protein_per_100g',
      'proteinas',
      'proteinas_por_100g',
    ], 0);
    normalized['carbsPer100g'] = _readInt(normalized, const [
      'carbsPer100g',
      'carbs_per_100g',
      'carbohidratos',
      'carbohidratos_por_100g',
    ], 0);
    normalized['fatPer100g'] = _readInt(normalized, const [
      'fatPer100g',
      'fat_per_100g',
      'grasas',
      'grasas_por_100g',
    ], 0);
    return FoodModel.fromFirestore(id, normalized);
  }

  /// Returns all global foods, cached locally for 10 min.
  Future<List<FoodModel>> getAllFoods() async {
    if (Firebase.apps.isEmpty) return const [];
    if (FirebaseAuth.instance.currentUser == null) return const [];

    final qs = await _db
        .collection('foods')
        .get(const GetOptions(source: Source.serverAndCache));

    final out = <FoodModel>[];
    for (final doc in qs.docs) {
      final m = _foodFromDocument(doc.id, doc.data());
      if (m != null) out.add(m);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  /// Search foods by name (client-side filter on cached list).
  Future<List<FoodModel>> searchFoods(String query) async {
    final all = await getAllFoods();
    if (query.trim().isEmpty) return all;

    final q = query.trim().toLowerCase();
    return all.where((f) => f.name.toLowerCase().contains(q)).toList();
  }
}
