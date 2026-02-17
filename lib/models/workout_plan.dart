import '../utils/date_utils.dart';

class WeekPlan {
  /// Monday of the week.
  final DateTime weekStart;

  /// 0..6 (Mon..Sun) -> workoutId
  final Map<int, String> assignments;

  const WeekPlan({required this.weekStart, required this.assignments});

  String get weekKey => DateUtilsCF.toKey(weekStart);

  WeekPlan copyWith({DateTime? weekStart, Map<int, String>? assignments}) {
    return WeekPlan(
      weekStart: weekStart ?? this.weekStart,
      assignments: assignments ?? this.assignments,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'weekStartKey': weekKey,
      'assignments': {for (final e in assignments.entries) '${e.key}': e.value},
    };
  }

  static WeekPlan? fromJson(Map<String, Object?> json) {
    final startKey = json['weekStartKey'];
    if (startKey is! String) return null;
    final start = DateUtilsCF.fromKey(startKey);
    if (start == null) return null;

    final a = json['assignments'];
    if (a is! Map) return WeekPlan(weekStart: start, assignments: const {});

    final out = <int, String>{};
    for (final e in a.entries) {
      final k = int.tryParse('${e.key}');
      final v = e.value;
      if (k == null) continue;
      if (v is! String) continue;
      if (k < 0 || k > 6) continue;
      out[k] = v;
    }

    return WeekPlan(weekStart: start, assignments: out);
  }
}
