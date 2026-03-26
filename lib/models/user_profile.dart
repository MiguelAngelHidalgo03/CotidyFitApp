enum UserLevel {
  principiante,
  intermedio,
  avanzado,
}

enum UserSex {
  hombre,
  mujer,
  otro,
}

extension UserSexX on UserSex {
  String get label {
    switch (this) {
      case UserSex.hombre:
        return 'Hombre';
      case UserSex.mujer:
        return 'Mujer';
      case UserSex.otro:
        return 'Otro';
    }
  }
}

enum WorkType {
  oficina,
  fisico,
  estudiante,
  desempleado,
  mixto,
}

extension WorkTypeX on WorkType {
  String get label {
    switch (this) {
      case WorkType.oficina:
        return 'Oficina';
      case WorkType.fisico:
        return 'Trabajo físico';
      case WorkType.estudiante:
        return 'Estudiante';
      case WorkType.desempleado:
        return 'Desempleado';
      case WorkType.mixto:
        return 'Mixto';
    }
  }
}

enum UserStreakFocusArea {
  nutrition,
  training,
  water,
  steps,
  dailyChallenge,
}

extension UserStreakFocusAreaX on UserStreakFocusArea {
  String get label {
    switch (this) {
      case UserStreakFocusArea.nutrition:
        return 'Nutricion';
      case UserStreakFocusArea.training:
        return 'Entrenamientos';
      case UserStreakFocusArea.water:
        return 'Agua';
      case UserStreakFocusArea.steps:
        return 'Pasos';
      case UserStreakFocusArea.dailyChallenge:
        return 'Retos diarios';
    }
  }

  String get shortLabel {
    switch (this) {
      case UserStreakFocusArea.nutrition:
        return 'Nutricion';
      case UserStreakFocusArea.training:
        return 'Entrenos';
      case UserStreakFocusArea.water:
        return 'Agua';
      case UserStreakFocusArea.steps:
        return 'Pasos';
      case UserStreakFocusArea.dailyChallenge:
        return 'Retos';
    }
  }

  String get subtitle {
    switch (this) {
      case UserStreakFocusArea.nutrition:
        return 'Cuenta el dia si registras al menos 3 comidas.';
      case UserStreakFocusArea.training:
        return 'Cuenta el dia si completas un entrenamiento.';
      case UserStreakFocusArea.water:
        return 'Cuenta el dia si llegas al objetivo de agua.';
      case UserStreakFocusArea.steps:
        return 'Cuenta el dia si alcanzas tu objetivo de pasos.';
      case UserStreakFocusArea.dailyChallenge:
        return 'Cuenta el dia si completas la mision diaria.';
    }
  }
}

enum UserStreakMixMode {
  any,
  all,
}

extension UserStreakMixModeX on UserStreakMixMode {
  String get label {
    switch (this) {
      case UserStreakMixMode.any:
        return 'Cumplir cualquiera';
      case UserStreakMixMode.all:
        return 'Cumplir todo';
    }
  }

  String get subtitle {
    switch (this) {
      case UserStreakMixMode.any:
        return 'La racha suma si completas al menos uno de tus focos.';
      case UserStreakMixMode.all:
        return 'La racha solo suma si completas todos tus focos elegidos.';
    }
  }
}

class UserStreakPreferences {
  const UserStreakPreferences._({
    required this.focusAreas,
    required this.mixMode,
  });

  factory UserStreakPreferences({
    List<UserStreakFocusArea> focusAreas = const [],
    UserStreakMixMode mixMode = UserStreakMixMode.any,
  }) {
    final normalized = _normalizeAreas(focusAreas);
    return UserStreakPreferences._(
      focusAreas: normalized,
      mixMode: normalized.length <= 1 ? UserStreakMixMode.any : mixMode,
    );
  }

  static const UserStreakPreferences defaultTraining =
      UserStreakPreferences._(
        focusAreas: <UserStreakFocusArea>[UserStreakFocusArea.training],
        mixMode: UserStreakMixMode.any,
      );

  final List<UserStreakFocusArea> focusAreas;
  final UserStreakMixMode mixMode;

  bool get isConfigured => focusAreas.isNotEmpty;
  bool get isMultiFocus => focusAreas.length > 1;

  String get title {
    if (!isConfigured) return 'Sin configurar';
    if (!isMultiFocus) return focusAreas.first.label;
    return mixMode == UserStreakMixMode.all ? 'Mix completo' : 'Mix flexible';
  }

  String get summary {
    if (!isConfigured) return 'Elige que acciones cuentan para tu racha.';
    if (!isMultiFocus) return 'Tu racha cuenta con ${focusAreas.first.label.toLowerCase()}.';

    final focusText = focusAreas.map((area) => area.shortLabel).join(' · ');
    if (mixMode == UserStreakMixMode.all) {
      return 'Tu racha cuenta cuando completas todo este mix: $focusText.';
    }
    return 'Tu racha cuenta cuando completas cualquiera de este mix: $focusText.';
  }

  String get chipLabel {
    if (!isConfigured) return 'Sin configurar';
    if (!isMultiFocus) return focusAreas.first.label;
    return mixMode == UserStreakMixMode.all ? 'Mix total' : 'Mix flexible';
  }

  String get cacheKey {
    final focusKey = focusAreas.map((area) => area.name).join(',');
    return '${mixMode.name}:$focusKey';
  }

  UserStreakPreferences copyWith({
    List<UserStreakFocusArea>? focusAreas,
    UserStreakMixMode? mixMode,
  }) {
    return UserStreakPreferences(
      focusAreas: focusAreas ?? this.focusAreas,
      mixMode: mixMode ?? this.mixMode,
    );
  }

  Map<String, Object?> toJson() => {
        'focusAreas': focusAreas.map((area) => area.name).toList(),
        'mixMode': mixMode.name,
      };

  static UserStreakPreferences? fromJson(Map<String, Object?> json) {
    final focusRaw = json['focusAreas'];
    final focusAreas = <UserStreakFocusArea>[];
    if (focusRaw is List) {
      for (final value in focusRaw) {
        final area = UserStreakFocusArea.values
            .where((entry) => entry.name == value)
            .cast<UserStreakFocusArea?>()
            .firstWhere((entry) => entry != null, orElse: () => null);
        if (area != null && !focusAreas.contains(area)) {
          focusAreas.add(area);
        }
      }
    }

    final mixRaw = json['mixMode'];
    final mixMode = UserStreakMixMode.values
        .where((entry) => entry.name == mixRaw)
        .cast<UserStreakMixMode?>()
        .firstWhere((entry) => entry != null, orElse: () => null);

    final normalized = UserStreakPreferences(
      focusAreas: focusAreas,
      mixMode: mixMode ?? UserStreakMixMode.any,
    );
    return normalized.isConfigured ? normalized : null;
  }

  static List<UserStreakFocusArea> _normalizeAreas(
    List<UserStreakFocusArea> areas,
  ) {
    final out = <UserStreakFocusArea>[];
    for (final area in areas) {
      if (!out.contains(area)) out.add(area);
    }
    out.sort((a, b) => a.index.compareTo(b.index));
    return List<UserStreakFocusArea>.unmodifiable(out);
  }
}

extension UserLevelX on UserLevel {
  String get label {
    switch (this) {
      case UserLevel.principiante:
        return 'Principiante';
      case UserLevel.intermedio:
        return 'Intermedio';
      case UserLevel.avanzado:
        return 'Avanzado';
    }
  }
}

enum AvatarIcon {
  persona,
  atleta,
  rayo,
  corona,
}

class AvatarSpec {
  final AvatarIcon icon;
  // Index into a UI-provided palette; keeps persistence stable.
  final int colorIndex;

  const AvatarSpec({required this.icon, required this.colorIndex});

  Map<String, Object?> toJson() => {
        'icon': icon.name,
        'colorIndex': colorIndex,
      };

  static AvatarSpec fromJson(Map<String, Object?> json) {
    final iconRaw = json['icon'];
    final colorIndexRaw = json['colorIndex'];

    final icon = AvatarIcon.values.where((e) => e.name == iconRaw).cast<AvatarIcon?>().firstWhere(
          (e) => e != null,
          orElse: () => null,
        );

    final colorIndex = colorIndexRaw is int ? colorIndexRaw : 0;
    return AvatarSpec(
      icon: icon ?? AvatarIcon.persona,
      colorIndex: colorIndex.clamp(0, 20),
    );
  }
}

class UserProfile {
  final String goal;

  final String name;
  final UserLevel level;
  final AvatarSpec avatar;
  final bool isPremium;

  // Onboarding
  final bool onboardingCompleted;
  final UserSex? sex;
  final int? availableTimeStartMinutes; // minutes from midnight
  final int? availableTimeEndMinutes; // minutes from midnight
  final List<int> availableDays; // 1..7 (Mon..Sun)
  final List<String> injuries;
  final List<String> healthConditions;
  final WorkType? workType;
  final int? notificationMinutes; // minutes from midnight
  final UserStreakPreferences? streakPreferences;

  // Personal info
  final int? age;
  final double? heightCm;
  final double? currentWeightKg;

  // Training bridge fields
  final int? availableMinutes;
  final String? usualTrainingPlace; // keep as string for flexibility
  final List<String> preferences;

  const UserProfile({
    required this.goal,
    this.name = 'CotidyFit',
    this.level = UserLevel.principiante,
    this.avatar = const AvatarSpec(icon: AvatarIcon.persona, colorIndex: 0),
    this.isPremium = false,
    this.onboardingCompleted = false,
    this.sex,
    this.age,
    this.heightCm,
    this.currentWeightKg,
    this.availableTimeStartMinutes,
    this.availableTimeEndMinutes,
    this.availableMinutes,
    this.usualTrainingPlace,
    this.preferences = const [],
    this.availableDays = const [],
    this.injuries = const [],
    this.healthConditions = const [],
    this.workType,
    this.notificationMinutes,
    this.streakPreferences,
  });

    bool get hasPersonalizedStreakPreferences =>
      streakPreferences?.isConfigured == true;

    UserStreakPreferences get effectiveStreakPreferences =>
      streakPreferences?.isConfigured == true
        ? streakPreferences!
        : UserStreakPreferences.defaultTraining;

    String get streakPreferencesTitle => hasPersonalizedStreakPreferences
      ? effectiveStreakPreferences.title
      : 'Sin configurar';

    String get streakPreferencesSummary => hasPersonalizedStreakPreferences
      ? effectiveStreakPreferences.summary
      : 'Elige que quieres que cuente para mantener tu racha.';

  UserProfile copyWith({
    String? goal,
    String? name,
    UserLevel? level,
    AvatarSpec? avatar,
    bool? isPremium,
    bool? onboardingCompleted,
    UserSex? sex,
    int? age,
    double? heightCm,
    double? currentWeightKg,
    int? availableTimeStartMinutes,
    int? availableTimeEndMinutes,
    int? availableMinutes,
    String? usualTrainingPlace,
    List<String>? preferences,
    List<int>? availableDays,
    List<String>? injuries,
    List<String>? healthConditions,
    WorkType? workType,
    int? notificationMinutes,
    UserStreakPreferences? streakPreferences,
  }) {
    return UserProfile(
      goal: goal ?? this.goal,
      name: name ?? this.name,
      level: level ?? this.level,
      avatar: avatar ?? this.avatar,
      isPremium: isPremium ?? this.isPremium,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      sex: sex ?? this.sex,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      availableTimeStartMinutes: availableTimeStartMinutes ?? this.availableTimeStartMinutes,
      availableTimeEndMinutes: availableTimeEndMinutes ?? this.availableTimeEndMinutes,
      availableMinutes: availableMinutes ?? this.availableMinutes,
      usualTrainingPlace: usualTrainingPlace ?? this.usualTrainingPlace,
      preferences: preferences ?? this.preferences,
      availableDays: availableDays ?? this.availableDays,
      injuries: injuries ?? this.injuries,
      healthConditions: healthConditions ?? this.healthConditions,
      workType: workType ?? this.workType,
      notificationMinutes: notificationMinutes ?? this.notificationMinutes,
      streakPreferences: streakPreferences ?? this.streakPreferences,
    );
  }

  Map<String, Object?> toJson() => {
        'goal': goal,
        'name': name,
        'level': level.name,
        'avatar': avatar.toJson(),
        'isPremium': isPremium,
      'onboardingCompleted': onboardingCompleted,
      'sex': sex?.name,
        'age': age,
        'heightCm': heightCm,
        'currentWeightKg': currentWeightKg,
      'availableTimeStartMinutes': availableTimeStartMinutes,
      'availableTimeEndMinutes': availableTimeEndMinutes,
        'availableMinutes': availableMinutes,
        'usualTrainingPlace': usualTrainingPlace,
        'preferences': preferences,
      'availableDays': availableDays,
      'injuries': injuries,
      'healthConditions': healthConditions,
      'workType': workType?.name,
      'notificationMinutes': notificationMinutes,
      'streakPreferences': streakPreferences?.toJson(),
      };

  static UserProfile? fromJson(Map<String, Object?> json) {
    final goal = json['goal'];
    if (goal is! String || goal.trim().isEmpty) return null;

    final name = json['name'];
    final levelRaw = json['level'];
    final isPremiumRaw = json['isPremium'];

    final onboardingCompletedRaw = json['onboardingCompleted'];
    final legacyHasGoal = goal.trim().isNotEmpty;

    final level = UserLevel.values.where((e) => e.name == levelRaw).cast<UserLevel?>().firstWhere(
          (e) => e != null,
          orElse: () => null,
        );

    final sexRaw = json['sex'];
    final sex = UserSex.values.where((e) => e.name == sexRaw).cast<UserSex?>().firstWhere(
          (e) => e != null,
          orElse: () => null,
        );

    final workRaw = json['workType'];
    final workType = WorkType.values.where((e) => e.name == workRaw).cast<WorkType?>().firstWhere(
          (e) => e != null,
          orElse: () => null,
        );

    final avatarRaw = json['avatar'];
    final avatar = avatarRaw is Map
        ? AvatarSpec.fromJson(avatarRaw.map((k, v) => MapEntry(k.toString(), v)))
        : const AvatarSpec(icon: AvatarIcon.persona, colorIndex: 0);

    final prefsRaw = json['preferences'];
    final prefs = <String>[];
    if (prefsRaw is List) {
      for (final v in prefsRaw) {
        if (v is String && v.trim().isNotEmpty) prefs.add(v);
      }
    }

    final daysRaw = json['availableDays'];
    final days = <int>[];
    if (daysRaw is List) {
      for (final v in daysRaw) {
        if (v is int) {
          final clamped = v.clamp(1, 7);
          if (!days.contains(clamped)) days.add(clamped);
        }
      }
      days.sort();
    }

    final injuriesRaw = json['injuries'];
    final injuries = <String>[];
    if (injuriesRaw is List) {
      for (final v in injuriesRaw) {
        if (v is String && v.trim().isNotEmpty) injuries.add(v.trim());
      }
    }

    final healthRaw = (json['healthConditions'] is List) ? json['healthConditions'] : json['chronicConditions'];
    final health = <String>[];
    if (healthRaw is List) {
      for (final v in healthRaw) {
        if (v is String && v.trim().isNotEmpty) health.add(v.trim());
      }
    }

    final streakRaw = json['streakPreferences'];
    final streakPreferences = streakRaw is Map
        ? UserStreakPreferences.fromJson(
            streakRaw.map((k, v) => MapEntry(k.toString(), v)),
          )
        : null;

    return UserProfile(
      goal: goal.trim(),
      name: name is String && name.trim().isNotEmpty ? name.trim() : 'CotidyFit',
      level: level ?? UserLevel.principiante,
      avatar: avatar,
      isPremium: isPremiumRaw is bool ? isPremiumRaw : false,
      onboardingCompleted: onboardingCompletedRaw is bool
          ? onboardingCompletedRaw
          : legacyHasGoal,
      sex: sex,
      age: json['age'] is int ? json['age'] as int : null,
      heightCm: json['heightCm'] is num ? (json['heightCm'] as num).toDouble() : null,
      currentWeightKg: json['currentWeightKg'] is num ? (json['currentWeightKg'] as num).toDouble() : null,
      availableTimeStartMinutes: json['availableTimeStartMinutes'] is int
          ? (json['availableTimeStartMinutes'] as int).clamp(0, 24 * 60 - 1)
          : null,
      availableTimeEndMinutes: json['availableTimeEndMinutes'] is int
          ? (json['availableTimeEndMinutes'] as int).clamp(0, 24 * 60 - 1)
          : null,
      availableMinutes: json['availableMinutes'] is int ? json['availableMinutes'] as int : null,
      usualTrainingPlace: json['usualTrainingPlace'] is String ? json['usualTrainingPlace'] as String : null,
      preferences: prefs,
      availableDays: days,
      injuries: injuries,
      healthConditions: health,
      workType: workType,
      notificationMinutes: json['notificationMinutes'] is int
          ? (json['notificationMinutes'] as int).clamp(0, 24 * 60 - 1)
          : null,
      streakPreferences: streakPreferences,
    );
  }
}
