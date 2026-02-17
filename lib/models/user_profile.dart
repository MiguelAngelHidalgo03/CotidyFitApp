enum UserLevel {
  principiante,
  intermedio,
  avanzado,
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
    this.age,
    this.heightCm,
    this.currentWeightKg,
    this.availableMinutes,
    this.usualTrainingPlace,
    this.preferences = const [],
  });

  UserProfile copyWith({
    String? goal,
    String? name,
    UserLevel? level,
    AvatarSpec? avatar,
    bool? isPremium,
    int? age,
    double? heightCm,
    double? currentWeightKg,
    int? availableMinutes,
    String? usualTrainingPlace,
    List<String>? preferences,
  }) {
    return UserProfile(
      goal: goal ?? this.goal,
      name: name ?? this.name,
      level: level ?? this.level,
      avatar: avatar ?? this.avatar,
      isPremium: isPremium ?? this.isPremium,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      availableMinutes: availableMinutes ?? this.availableMinutes,
      usualTrainingPlace: usualTrainingPlace ?? this.usualTrainingPlace,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, Object?> toJson() => {
        'goal': goal,
        'name': name,
        'level': level.name,
        'avatar': avatar.toJson(),
        'isPremium': isPremium,
        'age': age,
        'heightCm': heightCm,
        'currentWeightKg': currentWeightKg,
        'availableMinutes': availableMinutes,
        'usualTrainingPlace': usualTrainingPlace,
        'preferences': preferences,
      };

  static UserProfile? fromJson(Map<String, Object?> json) {
    final goal = json['goal'];
    if (goal is! String || goal.trim().isEmpty) return null;

    final name = json['name'];
    final levelRaw = json['level'];
    final isPremiumRaw = json['isPremium'];

    final level = UserLevel.values.where((e) => e.name == levelRaw).cast<UserLevel?>().firstWhere(
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

    return UserProfile(
      goal: goal.trim(),
      name: name is String && name.trim().isNotEmpty ? name.trim() : 'CotidyFit',
      level: level ?? UserLevel.principiante,
      avatar: avatar,
      isPremium: isPremiumRaw is bool ? isPremiumRaw : false,
      age: json['age'] is int ? json['age'] as int : null,
      heightCm: json['heightCm'] is num ? (json['heightCm'] as num).toDouble() : null,
      currentWeightKg: json['currentWeightKg'] is num ? (json['currentWeightKg'] as num).toDouble() : null,
      availableMinutes: json['availableMinutes'] is int ? json['availableMinutes'] as int : null,
      usualTrainingPlace: json['usualTrainingPlace'] is String ? json['usualTrainingPlace'] as String : null,
      preferences: prefs,
    );
  }
}
