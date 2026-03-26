class AchievementCatalogItem {
  const AchievementCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.conditionType,
    required this.conditionValue,
    this.difficulty = '',
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final String category;
  final String conditionType;
  final int conditionValue;
  /// Optional: 'easy' | 'medium' | 'hard'.
  /// If empty, the UI may fall back to a heuristic based on conditionValue.
  final String difficulty;
  final DateTime? createdAt;

  factory AchievementCatalogItem.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final created = data['createdAt'];
    return AchievementCatalogItem(
      id: id,
      title: (data['title'] as String? ?? '').trim(),
      description: (data['description'] as String? ?? '').trim(),
      icon: (data['icon'] as String? ?? 'emoji_events_outlined').trim(),
      category: (data['category'] as String? ?? 'progreso').trim(),
      conditionType: (data['conditionType'] as String? ?? '').trim(),
      conditionValue: _asInt(data['conditionValue']) ?? 0,
      difficulty: (data['difficulty'] as String? ?? '').trim(),
      createdAt: _asDateTime(created),
    );
  }

  Map<String, Object?> toFirestore() {
    return {
      'title': title,
      'description': description,
      'icon': icon,
      'category': category,
      'conditionType': conditionType,
      'conditionValue': conditionValue,
      'difficulty': difficulty,
      'createdAt': createdAt,
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
