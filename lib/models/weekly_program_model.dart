class WeeklyProgramModel {
  const WeeklyProgramModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.nivel,
    required this.objetivo,
    required this.semanas,
    required this.estructuraDias,
    required this.diasPorSemana,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final String nivel;
  final String objetivo;
  final int semanas;

  /// Number of planned days per week (for display only).
  final int diasPorSemana;

  /// Weeks -> 7 days (Mon..Sun) -> workoutId or null.
  final List<List<String?>> estructuraDias;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'nivel': nivel,
      'objetivo': objetivo,
      'semanas': semanas,
      'diasPorSemana': diasPorSemana,
      'estructuraDias': [
        for (final week in estructuraDias)
          [for (final day in week) day],
      ],
    };
  }

  static WeeklyProgramModel? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    if (id is! String || id.trim().isEmpty) return null;
    if (nombre is! String || nombre.trim().isEmpty) return null;

    final semanasRaw = json['semanas'];
    final semanas = semanasRaw is int ? semanasRaw : 1;

    final diasPorSemanaRaw = json['diasPorSemana'];
    final diasPorSemana = diasPorSemanaRaw is int ? diasPorSemanaRaw : 3;

    final estructuraRaw = json['estructuraDias'];
    final estructuraDias = <List<String?>>[];
    if (estructuraRaw is List) {
      for (final w in estructuraRaw) {
        if (w is! List) continue;
        final days = <String?>[];
        for (final d in w) {
          days.add(d is String && d.trim().isNotEmpty ? d : null);
        }
        while (days.length < 7) {
          days.add(null);
        }
        if (days.length > 7) {
          days.removeRange(7, days.length);
        }
        estructuraDias.add(days);
      }
    }

    final normalizedWeeks = semanas.clamp(1, 52);
    while (estructuraDias.length < normalizedWeeks) {
      estructuraDias.add(List<String?>.filled(7, null));
    }
    if (estructuraDias.length > normalizedWeeks) {
      estructuraDias.removeRange(normalizedWeeks, estructuraDias.length);
    }

    return WeeklyProgramModel(
      id: id.trim(),
      nombre: nombre.trim(),
      descripcion: (json['descripcion'] is String) ? (json['descripcion'] as String) : '',
      nivel: (json['nivel'] is String) ? (json['nivel'] as String) : 'Principiante',
      objetivo: (json['objetivo'] is String) ? (json['objetivo'] as String) : '',
      semanas: normalizedWeeks,
      diasPorSemana: diasPorSemana.clamp(1, 7),
      estructuraDias: estructuraDias,
    );
  }
}
