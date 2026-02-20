enum WorkoutSoundSourceType {
  system,
  asset,
  remote,
}

class WorkoutSoundModel {
  const WorkoutSoundModel({
    required this.id,
    required this.nombre,
    required this.sourceType,
    this.assetPath,
    this.remoteUrl,
  });

  final String id;
  final String nombre;
  final WorkoutSoundSourceType sourceType;

  // Prepared for future database/asset delivery.
  final String? assetPath;
  final String? remoteUrl;
}
