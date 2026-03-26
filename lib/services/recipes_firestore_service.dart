import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/recipe_model.dart';
import '../utils/meal_slot_utils.dart';
import 'recipe_repository.dart';

class RecipesFirestoreService implements RecipeRepository {
  RecipesFirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _dbOverride = db,
      _authOverride = auth;

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  String? get _uid => Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _recipes =>
      _db.collection('recipes');

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

  num _readNum(Map<String, dynamic> data, List<String> keys, num fallback) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value;
      if (value is String) {
        final parsed = num.tryParse(value.trim().replaceAll(',', '.'));
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  List<String> _readStringList(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        final out = value
            .map((entry) => entry?.toString().trim() ?? '')
            .where((entry) => entry.isNotEmpty)
            .toList();
        if (out.isNotEmpty) return out;
      }
      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(RegExp(r'[|,\n]'))
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  List<String> _normalizeMealTypes(List<String> values) {
    final out = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final normalized = normalizeMealTypeValue(value);
      if (normalized == null || !seen.add(normalized)) continue;
      out.add(normalized);
    }
    return out;
  }

  String _normalizeDifficulty(String value) {
    switch (value.trim().toLowerCase()) {
      case 'facil':
      case 'fácil':
      case 'easy':
        return 'easy';
      case 'dificil':
      case 'difícil':
      case 'hard':
        return 'hard';
      case 'medio':
      case 'media':
      case 'medium':
      default:
        return 'medium';
    }
  }

  String? _normalizeMediaUrl(String? url) {
    final clean = url?.trim();
    if (clean == null || clean.isEmpty) return null;

    if (clean.contains('drive.google.com')) {
      final uri = Uri.tryParse(clean);
      final segments = uri?.pathSegments ?? const <String>[];
      final fileIndex = segments.indexOf('d');
      if (fileIndex >= 0 && fileIndex + 1 < segments.length) {
        final fileId = segments[fileIndex + 1];
        if (fileId.isNotEmpty) {
          return 'https://drive.google.com/uc?export=view&id=$fileId';
        }
      }

      final fileId = uri?.queryParameters['id'];
      if (fileId != null && fileId.isNotEmpty) {
        return 'https://drive.google.com/uc?export=view&id=$fileId';
      }
    }

    return clean;
  }

  Map<String, dynamic> _normalizeRecipeDocument(
    String id,
    Map<String, dynamic> data,
  ) {
    final normalized = <String, dynamic>{...data};
    normalized['id'] = id;
    normalized['name'] = _readText(normalized, const [
      'name',
      'nombre',
    ], fallback: id);
    normalized['country'] = _readText(normalized, const [
      'country',
      'pais',
      'origen',
    ], fallback: 'General');
    normalized['priceTier'] = _readText(normalized, const [
      'priceTier',
      'price_tier',
      'price_level',
    ], fallback: 'medium');
    normalized['ratingAvg'] = _readNum(normalized, const [
      'ratingAvg',
      'avg_rating',
    ], 0);
    normalized['ratingCount'] = _readNum(normalized, const [
      'ratingCount',
      'rating_count',
    ], 0);
    normalized['likes'] = _readNum(normalized, const [
      'likes',
      'total_likes',
    ], 0);
    normalized['kcalPerServing'] = _readNum(normalized, const [
      'kcalPerServing',
      'kcal_per_serving',
    ], 0);
    normalized['gramsPerServing'] = _readNum(normalized, const [
      'gramsPerServing',
      'grams_per_serving',
    ], 100);
    normalized['servings'] = _readNum(normalized, const ['servings'], 1);
    normalized['durationMinutes'] = _readNum(normalized, const [
      'durationMinutes',
      'duration_minutes',
    ], 0);

    final macrosRaw =
        normalized['macrosPerServing'] ?? normalized['macros_per_serving'];
    if (macrosRaw is Map) {
      final casted = macrosRaw.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      normalized['macrosPerServing'] = {
        'proteinG': _readNum(casted, const ['proteinG', 'protein_g'], 0),
        'carbsG': _readNum(casted, const ['carbsG', 'carbs_g'], 0),
        'fatG': _readNum(casted, const ['fatG', 'fat_g'], 0),
      };
    } else {
      normalized['macrosPerServing'] = {
        'proteinG': _readNum(normalized, const [
          'proteinG',
          'protein_g',
          'proteinas',
          'proteinas_por_racion',
        ], 0),
        'carbsG': _readNum(normalized, const [
          'carbsG',
          'carbs_g',
          'carbohidratos',
          'carbohidratos_por_racion',
        ], 0),
        'fatG': _readNum(normalized, const [
          'fatG',
          'fat_g',
          'grasas',
          'grasas_por_racion',
        ], 0),
      };
    }

    normalized['dietTypes'] = _readStringList(normalized, const [
      'dietTypes',
      'diet_types',
      'diet_type',
      'tipos_dieta',
    ]);
    normalized['allergenFree'] = _readStringList(normalized, const [
      'allergenFree',
      'allergen_free',
      'sin_alergenos',
    ]);
    normalized['mealTypes'] = _normalizeMealTypes(
      _readStringList(normalized, const [
        'mealTypes',
        'meal_types',
        'tipos_comida',
        'tipo_de_receta',
      ]),
    );
    normalized['goals'] = _readStringList(normalized, const [
      'goals',
      'goal_tags',
      'objetivos',
      'objetivo',
    ]);
    normalized['difficulty'] = _normalizeDifficulty(
      _readText(normalized, const [
        'difficulty',
        'dificultad',
        'nivel_de_dificultad',
      ], fallback: 'medium'),
    );
    normalized['utensils'] = _readStringList(normalized, const [
      'utensils',
      'utensilios',
    ]);
    normalized['imageUrl'] = _normalizeMediaUrl(
      _readText(normalized, const [
        'imageUrl',
        'image_url',
        'url_imagen',
        'imagen',
        'photoUrl',
        'photo_url',
      ]),
    );
    normalized['videoUrl'] = _normalizeMediaUrl(
      _readText(normalized, const ['videoUrl', 'video_url', 'url_video', 'video']),
    );
    if (normalized['ingredients'] is! List) {
      normalized['ingredients'] = const [];
    }
    if (normalized['steps'] is! List) normalized['steps'] = const [];
    if (normalized['steps'] is List) {
      normalized['steps'] = (normalized['steps'] as List)
          .map((entry) {
            if (entry is! Map) return entry;
            final casted = entry.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            final normalizedStep = <String, dynamic>{...casted};
            normalizedStep['videoUrl'] = _normalizeMediaUrl(
              _readText(casted, const ['videoUrl', 'video_url', 'url_video', 'video']),
            );
            return normalizedStep;
          })
          .toList();
    }
    return normalized;
  }

  @override
  Future<void> seedIfEmpty() async {
    // No-op: recipes are managed in Firestore.
  }

  @override
  Future<List<RecipeModel>> getAllRecipes() async {
    final uid = _uid;
    if (uid == null) return const [];

    final qs = await _recipes.limit(500).get();
    final out = <RecipeModel>[];

    for (final doc in qs.docs) {
      final json = _normalizeRecipeDocument(doc.id, doc.data());
      final m = RecipeModel.fromJson(json);
      if (m != null) out.add(m);
    }

    return out;
  }

  @override
  Future<RecipeModel?> getRecipeById(String id) async {
    final uid = _uid;
    if (uid == null) return null;

    final rid = id.trim();
    if (rid.isEmpty) return null;

    final snap = await _recipes.doc(rid).get();
    if (!snap.exists) return null;

    final data = snap.data();
    if (data == null) return null;

    final json = _normalizeRecipeDocument(snap.id, data);
    return RecipeModel.fromJson(json);
  }
}
