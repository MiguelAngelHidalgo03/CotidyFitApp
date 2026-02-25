import '../models/user_profile.dart';
import '../models/weekly_program_model.dart';
import '../models/workout.dart';

class TrainingRecommendation {
  const TrainingRecommendation({
    required this.score,
    required this.explanation,
  });

  final int score;
  final String explanation;
}

class TrainingRecommendationService {
  static TrainingRecommendation scoreWorkout({
    required UserProfile? profile,
    required Workout workout,
  }) {
    if (profile == null) {
      return const TrainingRecommendation(
        score: 0,
        explanation: 'Completa tu perfil para recomendaciones más precisas.',
      );
    }

    var score = 0;
    final reasons = <String>[];

    final goal = profile.goal.trim().toLowerCase();
    final workoutGoals = <String>{
      ...workout.recommendedForGoals.map((e) => e.toLowerCase()),
      ...workout.goals.map((e) => e.label.toLowerCase()),
    };
    if (_matchesGoal(goal, workoutGoals)) {
      score += 2;
      reasons.add('coincide con tu objetivo ${profile.goal}');
    }

    final level = profile.level.label.toLowerCase();
    if (workout.level.toLowerCase().contains(level)) {
      score += 2;
      reasons.add('encaja con tu nivel ${profile.level.label.toLowerCase()}');
    }

    final location = (profile.usualTrainingPlace ?? '').trim().toLowerCase();
    if (_matchesEquipmentOrLocation(location, workout.equipmentNeeded, workout.places)) {
      score += 1;
      reasons.add('se adapta a dónde entrenas');
    }

    final injuries = profile.injuries.map((e) => e.trim().toLowerCase()).toList();
    if (_conflicts(injuries, workout.contraindications)) {
      score -= 3;
      reasons.add('puede no ser ideal por tus lesiones');
    }

    final conditions = profile.healthConditions
        .map((e) => e.trim().toLowerCase())
        .toList();
    if (_conflicts(conditions, workout.medicalWarnings)) {
      score -= 5;
      reasons.add('requiere cautela por condiciones médicas');
    }

    final prefs = profile.preferences.map((e) => e.toLowerCase()).toList();
    if (_matchesPreference(prefs, workout.sportCategory, workout.recommendedProfileTags)) {
      score += 1;
      reasons.add('coincide con tus preferencias deportivas');
    }

    return TrainingRecommendation(
      score: score,
      explanation: _toExplanation(reasons),
    );
  }

  static TrainingRecommendation scoreWeeklyProgram({
    required UserProfile? profile,
    required WeeklyProgramModel program,
  }) {
    if (profile == null) {
      return const TrainingRecommendation(
        score: 0,
        explanation: 'Completa tu perfil para recomendaciones más precisas.',
      );
    }

    var score = 0;
    final reasons = <String>[];

    final goal = profile.goal.trim().toLowerCase();
    if (_matchesGoal(goal, {program.objetivo.toLowerCase(), ...program.recommendedProfileTags.map((e) => e.toLowerCase())})) {
      score += 2;
      reasons.add('coincide con tu objetivo ${profile.goal}');
    }

    if (program.nivel.toLowerCase().contains(profile.level.label.toLowerCase())) {
      score += 2;
      reasons.add('encaja con tu nivel ${profile.level.label.toLowerCase()}');
    }

    final location = (profile.usualTrainingPlace ?? '').trim().toLowerCase();
    if (_matchesEquipment(location, program.equipmentNeeded)) {
      score += 1;
      reasons.add('encaja con tu lugar de entrenamiento');
    }

    if (_conflicts(profile.injuries.map((e) => e.toLowerCase()).toList(), program.contraindications)) {
      score -= 3;
      reasons.add('podría no ser ideal por tus lesiones');
    }

    if (_conflicts(profile.healthConditions.map((e) => e.toLowerCase()).toList(), program.medicalWarnings)) {
      score -= 5;
      reasons.add('requiere revisión por condiciones médicas');
    }

    if (_matchesPreference(profile.preferences.map((e) => e.toLowerCase()).toList(), program.objetivo, program.recommendedProfileTags)) {
      score += 1;
      reasons.add('coincide con tus preferencias deportivas');
    }

    return TrainingRecommendation(
      score: score,
      explanation: _toExplanation(reasons),
    );
  }

  static bool _matchesGoal(String goal, Set<String> candidates) {
    for (final c in candidates) {
      if (c.trim().isEmpty) continue;
      if (goal.contains(c) || c.contains(goal)) return true;
    }
    return false;
  }

  static bool _matchesEquipmentOrLocation(String location, String equipment, List<WorkoutPlace> places) {
    if (_matchesEquipment(location, equipment)) return true;
    final placeLabel = places.map((e) => e.label.toLowerCase()).join(' ');
    return location.isNotEmpty && placeLabel.contains(location);
  }

  static bool _matchesEquipment(String location, String equipment) {
    if (location.isEmpty) return false;
    final e = equipment.toLowerCase();
    if (location.contains('casa')) return e.contains('casa') || e.contains('none');
    if (location.contains('gim')) return e.contains('gym');
    if (location.contains('parque') || location.contains('aire')) return e.contains('parque');
    return false;
  }

  static bool _conflicts(List<String> profileItems, List<String> warnings) {
    if (profileItems.isEmpty || warnings.isEmpty) return false;
    final warningSet = warnings.map((e) => e.toLowerCase()).toSet();
    for (final item in profileItems) {
      if (item.trim().isEmpty) continue;
      if (warningSet.any((w) => w.contains(item) || item.contains(w))) {
        return true;
      }
    }
    return false;
  }

  static bool _matchesPreference(List<String> prefs, String sportCategory, List<String> tags) {
    if (prefs.isEmpty) return false;
    final category = sportCategory.toLowerCase();
    final tagSet = tags.map((e) => e.toLowerCase()).toSet();
    for (final p in prefs) {
      if (p.trim().isEmpty) continue;
      if (category.contains(p) || p.contains(category)) return true;
      if (tagSet.any((t) => t.contains(p) || p.contains(t))) return true;
    }
    return false;
  }

  static String _toExplanation(List<String> reasons) {
    if (reasons.isEmpty) {
      return 'Te recomendamos esta opción por equilibrio general con tu perfil.';
    }
    if (reasons.length == 1) return 'Te recomendamos esta opción porque ${reasons.first}.';
    if (reasons.length == 2) return 'Te recomendamos esta opción porque ${reasons[0]} y ${reasons[1]}.';
    return 'Te recomendamos esta opción porque ${reasons[0]}, ${reasons[1]} y ${reasons[2]}.';
  }
}
