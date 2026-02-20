class ExerciseModel {
  const ExerciseModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.variantes,
    required this.imagenUrl,
    required this.videoUrl,
    required this.duracion,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final List<String> variantes;
  final String? imagenUrl;
  final String? videoUrl;

  /// Duration in seconds (null when rep-based).
  final int? duracion;

  Map<String, Object?> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'variantes': variantes,
        'imagenUrl': imagenUrl,
        'videoUrl': videoUrl,
        'duracion': duracion,
      };

  static ExerciseModel? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    if (id is! String || id.trim().isEmpty) return null;
    if (nombre is! String || nombre.trim().isEmpty) return null;

    final variantesRaw = json['variantes'];
    final variantes = <String>[];
    if (variantesRaw is List) {
      for (final v in variantesRaw) {
        if (v is String && v.trim().isNotEmpty) variantes.add(v.trim());
      }
    }

    final durRaw = json['duracion'];
    final duracion = durRaw is int ? durRaw : (durRaw is num ? durRaw.round() : null);

    return ExerciseModel(
      id: id.trim(),
      nombre: nombre.trim(),
      descripcion: json['descripcion'] is String ? (json['descripcion'] as String) : '',
      variantes: variantes,
      imagenUrl: json['imagenUrl'] is String ? (json['imagenUrl'] as String) : null,
      videoUrl: json['videoUrl'] is String ? (json['videoUrl'] as String) : null,
      duracion: (duracion != null && duracion > 0) ? duracion : null,
    );
  }
}
