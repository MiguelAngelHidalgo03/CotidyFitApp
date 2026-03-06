import 'package:flutter/material.dart';

enum MuscleGroup {
  pierna,
  pecho,
  espalda,
  hombros,
  biceps,
  triceps,
  abdomen,
  gluteos,
  cardio,
  fullBody,
  otros,
}

extension MuscleGroupX on MuscleGroup {
  String get label {
    switch (this) {
      case MuscleGroup.pierna:
        return 'Pierna';
      case MuscleGroup.pecho:
        return 'Pecho';
      case MuscleGroup.espalda:
        return 'Espalda';
      case MuscleGroup.hombros:
        return 'Hombros';
      case MuscleGroup.biceps:
        return 'Bíceps';
      case MuscleGroup.triceps:
        return 'Tríceps';
      case MuscleGroup.abdomen:
        return 'Abdomen';
      case MuscleGroup.gluteos:
        return 'Glúteos';
      case MuscleGroup.cardio:
        return 'Cardio';
      case MuscleGroup.fullBody:
        return 'Full body';
      case MuscleGroup.otros:
        return 'Otros';
    }
  }

  String get firestoreKey {
    switch (this) {
      case MuscleGroup.pierna:
        return 'pierna';
      case MuscleGroup.pecho:
        return 'pecho';
      case MuscleGroup.espalda:
        return 'espalda';
      case MuscleGroup.hombros:
        return 'hombros';
      case MuscleGroup.biceps:
        return 'biceps';
      case MuscleGroup.triceps:
        return 'triceps';
      case MuscleGroup.abdomen:
        return 'abdomen';
      case MuscleGroup.gluteos:
        return 'gluteos';
      case MuscleGroup.cardio:
        return 'cardio';
      case MuscleGroup.fullBody:
        return 'full_body';
      case MuscleGroup.otros:
        return 'otros';
    }
  }

  IconData get icon {
    switch (this) {
      case MuscleGroup.pierna:
        return Icons.directions_run_outlined;
      case MuscleGroup.pecho:
        return Icons.accessibility_new_outlined;
      case MuscleGroup.espalda:
        return Icons.self_improvement_outlined;
      case MuscleGroup.hombros:
        return Icons.sports_gymnastics_outlined;
      case MuscleGroup.biceps:
        return Icons.fitness_center_outlined;
      case MuscleGroup.triceps:
        return Icons.fitness_center_outlined;
      case MuscleGroup.abdomen:
        return Icons.health_and_safety_outlined;
      case MuscleGroup.gluteos:
        return Icons.hiking_outlined;
      case MuscleGroup.cardio:
        return Icons.favorite_border;
      case MuscleGroup.fullBody:
        return Icons.bolt_outlined;
      case MuscleGroup.otros:
        return Icons.category_outlined;
    }
  }
}

MuscleGroup muscleGroupFromFirestore(Object? value) {
  final raw =
      (value is String ? value : value?.toString())?.trim().toLowerCase() ?? '';
  switch (raw) {
    case 'pierna':
    case 'piernas':
    case 'legs':
      return MuscleGroup.pierna;
    case 'pecho':
    case 'chest':
      return MuscleGroup.pecho;
    case 'espalda':
    case 'back':
      return MuscleGroup.espalda;
    case 'hombro':
    case 'hombros':
    case 'shoulders':
      return MuscleGroup.hombros;
    case 'biceps':
    case 'bíceps':
      return MuscleGroup.biceps;
    case 'triceps':
    case 'tríceps':
      return MuscleGroup.triceps;
    case 'abdomen':
    case 'abdominal':
    case 'abs':
      return MuscleGroup.abdomen;
    case 'gluteos':
    case 'glúteos':
    case 'gluteo':
    case 'glúteo':
    case 'glutes':
      return MuscleGroup.gluteos;
    case 'cardio':
      return MuscleGroup.cardio;
    case 'full_body':
    case 'fullbody':
    case 'full body':
    case 'cuerpo completo':
      return MuscleGroup.fullBody;
    default:
      return MuscleGroup.otros;
  }
}

class ExerciseVariant {
  final String name;
  final String description;
  final String? imageUrl;
  final String? videoUrl;

  const ExerciseVariant({
    required this.name,
    required this.description,
    this.imageUrl,
    this.videoUrl,
  });
}

class Exercise {
  final String name;

  /// e.g. "12 reps" or "45 s" or "3 min"
  final String repsOrTime;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
  final List<ExerciseVariant> variants;

  /// Primary muscle group for filtering (stored in Firestore as a string).
  final MuscleGroup muscleGroup;

  /// Rep-based metadata (optional).
  final int? sets;
  final int? reps;

  /// Rest suggestion after completing a set / before next exercise.
  final int? restSeconds;

  /// Time-based metadata (optional). If set, exercise is treated as timed.
  final int? durationSeconds;

  const Exercise({
    required this.name,
    required this.repsOrTime,
    this.description = '',
    this.imageUrl,
    this.videoUrl,
    this.variants = const [],
    this.muscleGroup = MuscleGroup.otros,
    this.sets,
    this.reps,
    this.restSeconds,
    this.durationSeconds,
  });

  bool get isTimed => durationSeconds != null;
}
