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
    this.equipmentNeeded = 'none',
    this.recommendedProfileTags = const [],
    this.contraindications = const [],
    this.medicalWarnings = const [],
    this.durationMinutes = 0,
    this.periodFriendly = false,
    this.periodSupportTags = const [],
    this.periodBenefits = const [],
  });

  final String id;
  final String nombre;
  final String descripcion;
  final String nivel;
  final String objetivo;
  final int semanas;

  /// Number of planned days per week (for display only).
  final int diasPorSemana;

  final String equipmentNeeded;
  final List<String> recommendedProfileTags;
  final List<String> contraindications;
  final List<String> medicalWarnings;
  final int durationMinutes;
  final bool periodFriendly;
  final List<String> periodSupportTags;
  final List<String> periodBenefits;

  /// Weeks -> 7 days (Mon..Sun) -> workoutId or null.
  final List<List<String?>> estructuraDias;

  static List<Map<String, Object?>> _serializeWeekStructure(
    List<List<String?>> weeks,
  ) {
    return [
      for (var index = 0; index < weeks.length; index++)
        () {
          final week = weeks[index];
          return {
          'week': index + 1,
          'day1': week.isNotEmpty ? week[0] : null,
          'day2': week.length > 1 ? week[1] : null,
          'day3': week.length > 2 ? week[2] : null,
          'day4': week.length > 3 ? week[3] : null,
          'day5': week.length > 4 ? week[4] : null,
          'day6': week.length > 5 ? week[5] : null,
          'day7': week.length > 6 ? week[6] : null,
        };
        }(),
    ];
  }

  static List<String?>? _parseWeekStructureEntry(Object? raw) {
    if (raw is List) {
      final days = <String?>[];
      for (final value in raw) {
        days.add(value is String && value.trim().isNotEmpty ? value.trim() : null);
      }
      return days;
    }

    if (raw is Map) {
      String? readDay(String key) {
        final value = raw[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
        return null;
      }

      return <String?>[
        readDay('day1'),
        readDay('day2'),
        readDay('day3'),
        readDay('day4'),
        readDay('day5'),
        readDay('day6'),
        readDay('day7'),
      ];
    }

    return null;
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'nivel': nivel,
      'objetivo': objetivo,
      'semanas': semanas,
      'diasPorSemana': diasPorSemana,
      'equipmentNeeded': equipmentNeeded,
      'recommendedProfileTags': recommendedProfileTags,
      'contraindications': contraindications,
      'medicalWarnings': medicalWarnings,
      'durationMinutes': durationMinutes,
      'periodFriendly': periodFriendly,
      'periodSupportTags': periodSupportTags,
      'periodBenefits': periodBenefits,
      'estructuraDias': _serializeWeekStructure(estructuraDias),
    };
  }

  static WeeklyProgramModel? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final nombreRaw = json['nombre'] ?? json['name'];
    if (id is! String || id.trim().isEmpty) return null;
    if (nombreRaw is! String || nombreRaw.trim().isEmpty) return null;

    final semanasRaw = json['semanas'];
    final semanas = semanasRaw is int ? semanasRaw : 1;

    final diasPorSemanaRaw = json['diasPorSemana'];
    final diasPorSemana = diasPorSemanaRaw is int ? diasPorSemanaRaw : 3;
    final equipmentNeeded = json['equipmentNeeded'] is String
        ? (json['equipmentNeeded'] as String)
        : ((json['equipment_needed'] is String)
            ? (json['equipment_needed'] as String)
            : 'none');
    final durationWeeksRaw = json['durationWeeks'];
    final durationWeeks = durationWeeksRaw is int
        ? durationWeeksRaw
        : (durationWeeksRaw is num ? durationWeeksRaw.toInt() : null);
    final durationMinutesRaw = json['durationMinutes'];
    final durationMinutes = durationMinutesRaw is int
        ? durationMinutesRaw
        : (durationMinutesRaw is num ? durationMinutesRaw.toInt() : 0);

    List<String> parseStringList(String key, {String? snake}) {
      final raw = json[key] ?? (snake == null ? null : json[snake]);
      if (raw is List) {
        final out = <String>[];
        for (final e in raw) {
          if (e is String && e.trim().isNotEmpty) out.add(e.trim());
        }
        return out;
      }
      if (raw is String && raw.trim().isNotEmpty) {
        return raw
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    bool parseBool(String key, {String? snake, bool fallback = false}) {
      final raw = json[key] ?? (snake == null ? null : json[snake]);
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        switch (raw.trim().toLowerCase()) {
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

    final estructuraRaw = json['estructuraDias'];
    final estructuraDias = <List<String?>>[];
    if (estructuraRaw is List) {
      for (final w in estructuraRaw) {
        final days = _parseWeekStructureEntry(w);
        if (days == null) continue;
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
      nombre: nombreRaw.trim(),
      descripcion: (json['description'] is String)
          ? (json['description'] as String)
          : ((json['descripcion'] is String) ? (json['descripcion'] as String) : ''),
      nivel: (json['level'] is String)
          ? (json['level'] as String)
          : ((json['nivel'] is String) ? (json['nivel'] as String) : 'Principiante'),
      objetivo: (json['goal'] is String)
          ? (json['goal'] as String)
          : ((json['objetivo'] is String) ? (json['objetivo'] as String) : ''),
      semanas: (durationWeeks ?? normalizedWeeks).clamp(1, 52),
      diasPorSemana: diasPorSemana.clamp(1, 7),
      estructuraDias: estructuraDias,
      equipmentNeeded: equipmentNeeded,
      recommendedProfileTags: parseStringList('recommendedProfileTags', snake: 'recommended_profile_tags'),
      contraindications: parseStringList('contraindications'),
      medicalWarnings: parseStringList('medicalWarnings', snake: 'medical_warnings'),
      durationMinutes: durationMinutes < 0 ? 0 : durationMinutes,
      periodFriendly: parseBool('periodFriendly', snake: 'period_friendly'),
      periodSupportTags: parseStringList('periodSupportTags', snake: 'period_support_tags'),
      periodBenefits: parseStringList('periodBenefits', snake: 'period_benefits'),
    );
  }
}
