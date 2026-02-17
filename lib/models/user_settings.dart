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

  const UserSettings({
    required this.language,
    required this.notificationMinutes,
    required this.privacyMode,
  });

  static UserSettings defaults() {
    return const UserSettings(
      language: AppLanguage.es,
      notificationMinutes: 20 * 60,
      privacyMode: false,
    );
  }

  UserSettings copyWith({
    AppLanguage? language,
    int? notificationMinutes,
    bool? privacyMode,
  }) {
    return UserSettings(
      language: language ?? this.language,
      notificationMinutes: notificationMinutes ?? this.notificationMinutes,
      privacyMode: privacyMode ?? this.privacyMode,
    );
  }

  Map<String, Object?> toJson() => {
        'language': language.name,
        'notificationMinutes': notificationMinutes,
        'privacyMode': privacyMode,
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

    return UserSettings(
      language: lang,
      notificationMinutes: mins.clamp(0, 24 * 60 - 1),
      privacyMode: priv,
    );
  }
}
