import '../models/workout.dart';
import 'training_firestore_service.dart';

class WorkoutService {
  WorkoutService({TrainingFirestoreService? firestore})
    : _firestore = firestore ?? TrainingFirestoreService();

  final TrainingFirestoreService _firestore;
  List<Workout> _cache = const [];

  Future<void> ensureLoaded() async {
    if (_cache.isNotEmpty) return;
    await refreshFromFirestore();
  }

  Future<List<Workout>> refreshFromFirestore() async {
    try {
      final routines = await _firestore.getRoutines();
      final generated = await _firestore.getUserGeneratedRoutines();
      _cache = [...routines, ...generated];
    } catch (_) {
      _cache = const [];
    }
    return _cache;
  }

  List<Workout> getAllWorkouts() => _cache;

  Workout? getWorkoutById(String id) {
    try {
      return _cache.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  List<String> getCategories() {
    final set = <String>{};
    for (final w in _cache) {
      set.add(w.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Workout> getWorkoutsByCategory(String category) {
    final list = _cache.where((w) => w.category == category).toList();
    list.sort((a, b) => a.durationMinutes.compareTo(b.durationMinutes));
    return list;
  }

  List<Workout> getFilteredWorkouts(WorkoutFilters filters) {
    return _cache.where((w) => w.matchesFilters(filters)).toList();
  }
}
