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

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'videoUrl': videoUrl,
  };

  static ExerciseVariant? fromJson(Map<String, Object?> json) {
    final nameRaw = json['name'];
    final name =
        (nameRaw is String ? nameRaw : nameRaw?.toString())?.trim() ?? '';
    if (name.isEmpty) return null;

    final descriptionRaw = json['description'];
    final description =
        (descriptionRaw is String ? descriptionRaw : descriptionRaw?.toString())
            ?.trim() ??
        '';

    final imageUrlRaw = json['imageUrl'];
    final imageUrl =
        (imageUrlRaw is String ? imageUrlRaw : imageUrlRaw?.toString())?.trim();

    final videoUrlRaw = json['videoUrl'];
    final videoUrl =
        (videoUrlRaw is String ? videoUrlRaw : videoUrlRaw?.toString())?.trim();

    return ExerciseVariant(
      name: name,
      description: description,
      imageUrl: imageUrl != null && imageUrl.isNotEmpty ? imageUrl : null,
      videoUrl: videoUrl != null && videoUrl.isNotEmpty ? videoUrl : null,
    );
  }
}

class Exercise {
  final String? id;
  final String name;

  /// e.g. "12 reps" or "45 s" or "3 min"
  final String repsOrTime;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
  final List<ExerciseVariant> variants;
  final List<String> howToSteps;
  final List<String> commonMistakes;
  final List<String> tips;

  /// Primary muscle group for filtering (stored in Firestore as a string).
  final MuscleGroup muscleGroup;

  /// Whether the workout flow should ask the user for weight used.
  final bool askWeight;

  /// Whether the entered weight should be stored for future metrics.
  final bool trackWeight;

  /// Rep-based metadata (optional).
  final int? sets;
  final int? reps;

  /// Rest suggestion after completing a set / before next exercise.
  final int? restSeconds;

  /// Time-based metadata (optional). If set, exercise is treated as timed.
  final int? durationSeconds;

  const Exercise({
    this.id,
    required this.name,
    required this.repsOrTime,
    this.description = '',
    this.imageUrl,
    this.videoUrl,
    this.variants = const [],
    this.howToSteps = const [],
    this.commonMistakes = const [],
    this.tips = const [],
    this.muscleGroup = MuscleGroup.otros,
    this.askWeight = false,
    this.trackWeight = false,
    this.sets,
    this.reps,
    this.restSeconds,
    this.durationSeconds,
  });

  bool get isTimed => durationSeconds != null;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'repsOrTime': repsOrTime,
    'description': description,
    'imageUrl': imageUrl,
    'videoUrl': videoUrl,
    'variants': variants.map((v) => v.toJson()).toList(),
    'howToSteps': howToSteps,
    'commonMistakes': commonMistakes,
    'tips': tips,
    'muscleGroup': muscleGroup.firestoreKey,
    'askWeight': askWeight,
    'trackWeight': trackWeight,
    'sets': sets,
    'reps': reps,
    'restSeconds': restSeconds,
    'durationSeconds': durationSeconds,
  };

  static Exercise? fromJson(Map<String, Object?> json) {
    String s(Object? v, {String fallback = ''}) {
      final raw = (v is String ? v : v?.toString())?.trim();
      return (raw == null || raw.isEmpty) ? fallback : raw;
    }

    int? i(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      final raw = (v is String ? v : v?.toString())?.trim();
      if (raw == null || raw.isEmpty) return null;
      return int.tryParse(raw);
    }

    List<String> sl(Object? v) {
      if (v is! List) return const [];
      return v
          .map((e) => (e is String ? e : e?.toString())?.trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    final name = s(json['name']);
    if (name.isEmpty) return null;

    final repsOrTime = s(json['repsOrTime'], fallback: '');
    final description = s(json['description']);

    final imageUrl = s(json['imageUrl']);
    final videoUrl = s(json['videoUrl']);
    final howToSteps = sl(json['howToSteps']);
    final commonMistakes = sl(json['commonMistakes']);
    final tips = sl(json['tips']);

    final variantsRaw = json['variants'];
    final variants = <ExerciseVariant>[];
    if (variantsRaw is List) {
      for (final item in variantsRaw) {
        if (item is! Map) continue;
        final map = item.map((k, v) => MapEntry(k.toString(), v));
        final parsed = ExerciseVariant.fromJson(map);
        if (parsed != null) variants.add(parsed);
      }
    }

    final muscleGroup = muscleGroupFromFirestore(json['muscleGroup']);

    final sets = i(json['sets']);
    final reps = i(json['reps']);
    final restSeconds = i(json['restSeconds']);
    final durationSeconds = i(json['durationSeconds']);

    return Exercise(
      id: s(json['id']),
      name: name,
      repsOrTime: repsOrTime.isEmpty ? '10 reps' : repsOrTime,
      description: description,
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      videoUrl: videoUrl.isEmpty ? null : videoUrl,
      variants: variants,
      howToSteps: howToSteps,
      commonMistakes: commonMistakes,
      tips: tips,
      muscleGroup: muscleGroup,
      askWeight: json['askWeight'] == true,
      trackWeight: json['trackWeight'] == true,
      sets: sets,
      reps: reps,
      restSeconds: (restSeconds ?? 0) > 0 ? restSeconds : null,
      durationSeconds: (durationSeconds ?? 0) > 0 ? durationSeconds : null,
    );
  }
}
