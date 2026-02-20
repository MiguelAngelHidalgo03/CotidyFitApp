enum AppLanguage { es, en }

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

class UserSettings {
  final AppLanguage language;
  final int notificationMinutes; // minutes from midnight
  final bool privacyMode;
  final bool workoutEndSoundEnabled;
  final String workoutEndSoundId;

  const UserSettings({
    required this.language,
    required this.notificationMinutes,
    required this.privacyMode,
    required this.workoutEndSoundEnabled,
    required this.workoutEndSoundId,
  });

  static UserSettings defaults() {
    return const UserSettings(
      language: AppLanguage.es,
      notificationMinutes: 20 * 60,
      privacyMode: false,
      workoutEndSoundEnabled: true,
      workoutEndSoundId: 'system_alert',
    );
  }

  UserSettings copyWith({
    AppLanguage? language,
    int? notificationMinutes,
    bool? privacyMode,
    bool? workoutEndSoundEnabled,
    String? workoutEndSoundId,
  }) {
    return UserSettings(
      language: language ?? this.language,
      notificationMinutes: notificationMinutes ?? this.notificationMinutes,
      privacyMode: privacyMode ?? this.privacyMode,
      workoutEndSoundEnabled: workoutEndSoundEnabled ?? this.workoutEndSoundEnabled,
      workoutEndSoundId: workoutEndSoundId ?? this.workoutEndSoundId,
    );
  }

  Map<String, Object?> toJson() => {
        'language': language.name,
        'notificationMinutes': notificationMinutes,
        'privacyMode': privacyMode,
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

    final mins = json['notificationMinutes'] is int ? json['notificationMinutes'] as int : 20 * 60;
    final priv = json['privacyMode'] is bool ? json['privacyMode'] as bool : false;
    final soundEnabled = json['workoutEndSoundEnabled'] is bool ? json['workoutEndSoundEnabled'] as bool : true;
    final sound = json['workoutEndSoundId'] is String ? json['workoutEndSoundId'] as String : 'system_alert';

    return UserSettings(
      language: lang,
      notificationMinutes: mins.clamp(0, 24 * 60 - 1),
      privacyMode: priv,
      workoutEndSoundEnabled: soundEnabled,
      workoutEndSoundId: sound.trim().isEmpty ? 'system_alert' : sound.trim(),
    );
  }
}
