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

  const WorkoutFilters({
    required this.places,
    required this.goals,
    required this.difficulties,
    required this.durations,
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
  });

  bool matchesFilters(WorkoutFilters f) {
    final placeOk = f.places.isEmpty || places.any(f.places.contains);
    final goalOk = f.goals.isEmpty || goals.any(f.goals.contains);
    final diffOk = f.difficulties.isEmpty || f.difficulties.contains(difficulty);
    final durOk = f.durations.isEmpty || f.durations.any((d) => d.matchesMinutes(durationMinutes));
    return placeOk && goalOk && diffOk && durOk;
  }
}
