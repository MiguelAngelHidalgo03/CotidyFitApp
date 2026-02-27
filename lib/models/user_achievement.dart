class UserAchievement {
  const UserAchievement({
    required this.achievementId,
    required this.unlocked,
    this.unlockedAt,
    required this.progress,
    required this.visible,
  });

  final String achievementId;
  final bool unlocked;
  final DateTime? unlockedAt;
  final int progress;
  final bool visible;

  factory UserAchievement.fromFirestore({
    required String achievementId,
    required Map<String, dynamic> data,
  }) {
    final unlockedAtRaw = data['unlockedAt'];
    return UserAchievement(
      achievementId: achievementId,
      unlocked: data['unlocked'] == true,
      unlockedAt: _asDateTime(unlockedAtRaw),
      progress: _asInt(data['progress']) ?? 0,
      visible: data['visible'] != false,
    );
  }

  Map<String, Object?> toFirestore() {
    return {
      'unlocked': unlocked,
      'unlockedAt': unlockedAt,
      'progress': progress,
      'visible': visible,
    };
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is DateTime) return value;
    final dynamic raw = value;
    if (raw != null) {
      try {
        final dt = raw.toDate();
        if (dt is DateTime) return dt;
      } catch (_) {}
    }
    return null;
  }
}
