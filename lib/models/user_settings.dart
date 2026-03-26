enum AppLanguage { es, en }

enum AppThemeMode { system, light, dark }

extension AppLanguageX on AppLanguage {
  String get label {
    switch (this) {
      case AppLanguage.es:
        return 'Español';
      case AppLanguage.en:
        return 'English';
    }
  }
}

extension AppThemeModeX on AppThemeMode {
  String get label {
    switch (this) {
      case AppThemeMode.system:
        return 'Automático';
      case AppThemeMode.light:
        return 'Claro';
      case AppThemeMode.dark:
        return 'Oscuro';
    }
  }
}

class UserSettings {
  final AppLanguage language;
  final AppThemeMode appThemeMode;
  final int notificationMinutes; // minutes from midnight
  final bool privacyMode;
  final bool showNutritionValues;
  final bool workoutEndSoundEnabled;
  final String workoutEndSoundId;

  const UserSettings({
    required this.language,
    required this.appThemeMode,
    required this.notificationMinutes,
    required this.privacyMode,
    required this.showNutritionValues,
    required this.workoutEndSoundEnabled,
    required this.workoutEndSoundId,
  });

  static UserSettings defaults() {
    return const UserSettings(
      language: AppLanguage.es,
      appThemeMode: AppThemeMode.system,
      notificationMinutes: 20 * 60,
      privacyMode: false,
      showNutritionValues: true,
      workoutEndSoundEnabled: true,
      workoutEndSoundId: 'training_bell',
    );
  }

  UserSettings copyWith({
    AppLanguage? language,
    AppThemeMode? appThemeMode,
    int? notificationMinutes,
    bool? privacyMode,
    bool? showNutritionValues,
    bool? workoutEndSoundEnabled,
    String? workoutEndSoundId,
  }) {
    return UserSettings(
      language: language ?? this.language,
      appThemeMode: appThemeMode ?? this.appThemeMode,
      notificationMinutes: notificationMinutes ?? this.notificationMinutes,
      privacyMode: privacyMode ?? this.privacyMode,
      showNutritionValues: showNutritionValues ?? this.showNutritionValues,
      workoutEndSoundEnabled:
          workoutEndSoundEnabled ?? this.workoutEndSoundEnabled,
      workoutEndSoundId: workoutEndSoundId ?? this.workoutEndSoundId,
    );
  }

  Map<String, Object?> toJson() => {
    'language': language.name,
    'appThemeMode': appThemeMode.name,
    'notificationMinutes': notificationMinutes,
    'privacyMode': privacyMode,
    'showNutritionValues': showNutritionValues,
    'workoutEndSoundEnabled': workoutEndSoundEnabled,
    'workoutEndSoundId': workoutEndSoundId,
  };

  static UserSettings fromJson(Map<String, Object?> json) {
    final langRaw = json['language'];
    AppLanguage lang = AppLanguage.es;
    for (final v in AppLanguage.values) {
      if (v.name == langRaw) {
        lang = v;
        break;
      }
    }

    final themeRaw = json['appThemeMode'];
    AppThemeMode appThemeMode = AppThemeMode.system;
    for (final value in AppThemeMode.values) {
      if (value.name == themeRaw) {
        appThemeMode = value;
        break;
      }
    }

    final mins = json['notificationMinutes'] is int
        ? json['notificationMinutes'] as int
        : 20 * 60;
    final priv = json['privacyMode'] is bool
        ? json['privacyMode'] as bool
        : false;
    final showNutritionValues = json['showNutritionValues'] is bool
        ? json['showNutritionValues'] as bool
        : true;
    final soundEnabled = json['workoutEndSoundEnabled'] is bool
        ? json['workoutEndSoundEnabled'] as bool
        : true;
    final sound = json['workoutEndSoundId'] is String
        ? json['workoutEndSoundId'] as String
        : 'training_bell';

    return UserSettings(
      language: lang,
      appThemeMode: appThemeMode,
      notificationMinutes: mins.clamp(0, 24 * 60 - 1),
      privacyMode: priv,
      showNutritionValues: showNutritionValues,
      workoutEndSoundEnabled: soundEnabled,
      workoutEndSoundId: sound.trim().isEmpty ? 'training_bell' : sound.trim(),
    );
  }
}
