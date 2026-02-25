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

  const Exercise({
    required this.name,
    required this.repsOrTime,
    this.description = '',
    this.imageUrl,
    this.videoUrl,
    this.variants = const [],
  });
}
