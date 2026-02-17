class DailyEntry {
  final String dateKey; // yyyy-mm-dd
  final List<String> completedActions;

  const DailyEntry({
    required this.dateKey,
    required this.completedActions,
  });

  int get cfIndex {
    const total = 6;
    final value = (completedActions.length / total) * 100;
    return value.round().clamp(0, 100);
  }

  Map<String, Object?> toJson() => {
        'dateKey': dateKey,
        'completedActions': completedActions,
      };

  static DailyEntry? fromJson(Map<String, Object?> json) {
    final dateKey = json['dateKey'];
    final actions = json['completedActions'];
    if (dateKey is! String) return null;
    if (actions is! List) return null;

    final actionStrings = <String>[];
    for (final a in actions) {
      if (a is String) actionStrings.add(a);
    }

    return DailyEntry(
      dateKey: dateKey,
      completedActions: actionStrings,
    );
  }
}
