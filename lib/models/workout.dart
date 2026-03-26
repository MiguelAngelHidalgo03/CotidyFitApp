import 'package:flutter/material.dart';

import 'exercise.dart';

enum WorkoutPlace {
  casaSinMaterial,
  casaConMaterial,
  aireLibre,
  parqueCalistenia,
  gimnasio,
}

extension WorkoutPlaceX on WorkoutPlace {
  String get label {
    switch (this) {
      case WorkoutPlace.casaSinMaterial:
        return 'Casa sin material';
      case WorkoutPlace.casaConMaterial:
        return 'Casa con material';
      case WorkoutPlace.aireLibre:
        return 'Aire libre';
      case WorkoutPlace.parqueCalistenia:
        return 'Parque calistenia';
      case WorkoutPlace.gimnasio:
        return 'Gimnasio';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkoutPlace.casaSinMaterial:
        return Icons.home_outlined;
      case WorkoutPlace.casaConMaterial:
        return Icons.home_repair_service_outlined;
      case WorkoutPlace.aireLibre:
        return Icons.park_outlined;
      case WorkoutPlace.parqueCalistenia:
        return Icons.sports_gymnastics_outlined;
      case WorkoutPlace.gimnasio:
        return Icons.fitness_center_outlined;
    }
  }
}

enum WorkoutGoal {
  perderGrasa,
  ganarMasaMuscular,
  tonificar,
  principiantes,
  flexibilidad,
  movilidad,
  cardio,
}

extension WorkoutGoalX on WorkoutGoal {
  String get label {
    switch (this) {
      case WorkoutGoal.perderGrasa:
        return 'Perder grasa';
      case WorkoutGoal.ganarMasaMuscular:
        return 'Ganar masa muscular';
      case WorkoutGoal.tonificar:
        return 'Tonificar';
      case WorkoutGoal.principiantes:
        return 'Principiantes';
      case WorkoutGoal.flexibilidad:
        return 'Flexibilidad';
      case WorkoutGoal.movilidad:
        return 'Movilidad';
      case WorkoutGoal.cardio:
        return 'Cardio';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkoutGoal.perderGrasa:
        return Icons.local_fire_department_outlined;
      case WorkoutGoal.ganarMasaMuscular:
        return Icons.fitness_center_outlined;
      case WorkoutGoal.tonificar:
        return Icons.check_circle_outline;
      case WorkoutGoal.principiantes:
        return Icons.school_outlined;
      case WorkoutGoal.flexibilidad:
        return Icons.self_improvement_outlined;
      case WorkoutGoal.movilidad:
        return Icons.accessibility_new_outlined;
      case WorkoutGoal.cardio:
        return Icons.favorite_border;
    }
  }
}

enum WorkoutDifficulty { leve, moderado, experto }

extension WorkoutDifficultyX on WorkoutDifficulty {
  String get label {
    switch (this) {
      case WorkoutDifficulty.leve:
        return 'Leve';
      case WorkoutDifficulty.moderado:
        return 'Moderado';
      case WorkoutDifficulty.experto:
        return 'Experto';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkoutDifficulty.leve:
        return Icons.spa_outlined;
      case WorkoutDifficulty.moderado:
        return Icons.trending_up;
      case WorkoutDifficulty.experto:
        return Icons.whatshot;
    }
  }
}

enum WorkoutDurationFilter { min10_15, min20_30, min30_45, min45Plus }

extension WorkoutDurationFilterX on WorkoutDurationFilter {
  String get label {
    switch (this) {
      case WorkoutDurationFilter.min10_15:
        return '10–15';
      case WorkoutDurationFilter.min20_30:
        return '20–30';
      case WorkoutDurationFilter.min30_45:
        return '30–45';
      case WorkoutDurationFilter.min45Plus:
        return '45+';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkoutDurationFilter.min10_15:
      case WorkoutDurationFilter.min20_30:
      case WorkoutDurationFilter.min30_45:
      case WorkoutDurationFilter.min45Plus:
        return Icons.schedule;
    }
  }

  bool matchesMinutes(int minutes) {
    switch (this) {
      case WorkoutDurationFilter.min10_15:
        return minutes >= 10 && minutes <= 15;
      case WorkoutDurationFilter.min20_30:
        return minutes >= 20 && minutes <= 30;
      case WorkoutDurationFilter.min30_45:
        return minutes >= 30 && minutes <= 45;
      case WorkoutDurationFilter.min45Plus:
        return minutes >= 45;
    }
  }
}

class WorkoutFilters {
  final Set<WorkoutPlace> places;
  final Set<WorkoutGoal> goals;
  final Set<WorkoutDifficulty> difficulties;
  final Set<WorkoutDurationFilter> durations;
  final Set<MuscleGroup> muscleGroups;

  const WorkoutFilters({
    required this.places,
    required this.goals,
    required this.difficulties,
    required this.durations,
    required this.muscleGroups,
  });
}

class Workout {
  final String id;
  final String name;
  final String category;
  final int durationMinutes;
  final String level; // e.g. "Principiante", "Intermedio", "Avanzado"
  final List<Exercise> exercises;

  // New scalable filter fields.
  final List<WorkoutPlace> places;
  final List<WorkoutGoal> goals;
  final WorkoutDifficulty difficulty;

  // Firestore training metadata (backward compatible defaults).
  final String equipmentNeeded;
  final String sportCategory;
  final List<String> recommendedForGoals;
  final List<String> contraindications;
  final List<String> medicalWarnings;
  final List<String> recommendedProfileTags;
  final bool periodFriendly;
  final List<String> periodSupportTags;
  final List<String> periodBenefits;

  const Workout({
    required this.id,
    required this.name,
    required this.category,
    required this.durationMinutes,
    required this.level,
    required this.exercises,
    this.places = const [],
    this.goals = const [],
    this.difficulty = WorkoutDifficulty.moderado,
    this.equipmentNeeded = 'none',
    this.sportCategory = '',
    this.recommendedForGoals = const [],
    this.contraindications = const [],
    this.medicalWarnings = const [],
    this.recommendedProfileTags = const [],
    this.periodFriendly = false,
    this.periodSupportTags = const [],
    this.periodBenefits = const [],
  });

  Set<MuscleGroup> get muscleGroups => {
        for (final e in exercises) e.muscleGroup,
      };

  bool matchesFilters(WorkoutFilters f) {
    final placeOk = f.places.isEmpty || places.any(f.places.contains);
    final goalOk = f.goals.isEmpty || goals.any(f.goals.contains);
    final diffOk = f.difficulties.isEmpty || f.difficulties.contains(difficulty);
    final durOk = f.durations.isEmpty || f.durations.any((d) => d.matchesMinutes(durationMinutes));
    final muscleOk = f.muscleGroups.isEmpty || exercises.any((e) => f.muscleGroups.contains(e.muscleGroup));
    return placeOk && goalOk && diffOk && durOk && muscleOk;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'durationMinutes': durationMinutes,
        'level': level,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'places': places.map((p) => p.name).toList(),
        'goals': goals.map((g) => g.name).toList(),
        'difficulty': difficulty.name,
        'equipmentNeeded': equipmentNeeded,
        'sportCategory': sportCategory,
        'recommendedForGoals': recommendedForGoals,
        'contraindications': contraindications,
        'medicalWarnings': medicalWarnings,
        'recommendedProfileTags': recommendedProfileTags,
        'periodFriendly': periodFriendly,
        'periodSupportTags': periodSupportTags,
        'periodBenefits': periodBenefits,
      };

  static Workout? fromJson(Map<String, Object?> json) {
    String s(Object? v, {String fallback = ''}) {
      final raw = (v is String ? v : v?.toString())?.trim();
      return (raw == null || raw.isEmpty) ? fallback : raw;
    }

    int i(Object? v, {int fallback = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      final raw = (v is String ? v : v?.toString())?.trim();
      if (raw == null || raw.isEmpty) return fallback;
      return int.tryParse(raw) ?? fallback;
    }

    List<String> sl(Object? v) {
      if (v is! List) return const [];
      return v
          .map((e) => (e is String ? e : e?.toString())?.trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    List<String> slFromKeys(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is List) return sl(value);
        final raw = (value is String ? value : value?.toString())?.trim();
        if (raw == null || raw.isEmpty) continue;
        return raw
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    bool readBool(List<String> keys, {bool fallback = false}) {
      for (final key in keys) {
        final value = json[key];
        if (value is bool) return value;
        if (value is num) return value != 0;
        final raw = (value is String ? value : value?.toString())?.trim().toLowerCase();
        if (raw == null || raw.isEmpty) continue;
        switch (raw) {
          case 'true':
          case '1':
          case 'si':
          case 'yes':
            return true;
          case 'false':
          case '0':
          case 'no':
            return false;
        }
      }
      return fallback;
    }

    T? enumFromName<T extends Enum>(List<T> values, Object? v) {
      final raw = s(v);
      if (raw.isEmpty) return null;
      for (final e in values) {
        if (e.name == raw) return e;
      }
      return null;
    }

    final id = s(json['id']);
    final name = s(json['name']);
    if (id.isEmpty || name.isEmpty) return null;

    final category = s(json['category'], fallback: 'General');
    final durationMinutes = i(json['durationMinutes'], fallback: 20);
    final level = s(json['level'], fallback: 'Intermedio');

    final exercisesRaw = json['exercises'];
    final exercises = <Exercise>[];
    if (exercisesRaw is List) {
      for (final item in exercisesRaw) {
        if (item is! Map) continue;
        final map = item.map((k, v) => MapEntry(k.toString(), v));
        final ex = Exercise.fromJson(map);
        if (ex != null) exercises.add(ex);
      }
    }

    final places = <WorkoutPlace>[];
    final placesRaw = json['places'];
    if (placesRaw is List) {
      for (final item in placesRaw) {
        final raw = s(item);
        final parsed = enumFromName(WorkoutPlace.values, raw);
        if (parsed != null) places.add(parsed);
      }
    }

    final goals = <WorkoutGoal>[];
    final goalsRaw = json['goals'];
    if (goalsRaw is List) {
      for (final item in goalsRaw) {
        final raw = s(item);
        final parsed = enumFromName(WorkoutGoal.values, raw);
        if (parsed != null) goals.add(parsed);
      }
    }

    final difficulty =
        enumFromName(WorkoutDifficulty.values, json['difficulty']) ??
            WorkoutDifficulty.moderado;

    return Workout(
      id: id,
      name: name,
      category: category,
      durationMinutes: durationMinutes,
      level: level,
      exercises: exercises,
      places: places,
      goals: goals,
      difficulty: difficulty,
      equipmentNeeded: s(json['equipmentNeeded'], fallback: 'none'),
      sportCategory: s(json['sportCategory']),
      recommendedForGoals: sl(json['recommendedForGoals']),
      contraindications: sl(json['contraindications']),
      medicalWarnings: sl(json['medicalWarnings']),
      recommendedProfileTags: sl(json['recommendedProfileTags']),
      periodFriendly: readBool([
        'periodFriendly',
        'period_friendly',
        'isPeriodFriendly',
        'is_period_friendly',
        'recommendedForPeriod',
        'recommended_for_period',
      ]),
      periodSupportTags: slFromKeys([
        'periodSupportTags',
        'period_support_tags',
        'periodTags',
        'period_tags',
        'womenCycleTags',
        'women_cycle_tags',
      ]),
      periodBenefits: slFromKeys([
        'periodBenefits',
        'period_benefits',
        'periodSupportBenefits',
        'period_support_benefits',
      ]),
    );
  }
}
