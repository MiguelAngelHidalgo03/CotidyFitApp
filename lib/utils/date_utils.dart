class DateUtilsCF {
  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static String toKey(DateTime dt) {
    final d = dateOnly(dt);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static DateTime? fromKey(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isYesterdayOf(DateTime candidate, DateTime today) {
    final t = dateOnly(today);
    final y = t.subtract(const Duration(days: 1));
    return isSameDay(candidate, y);
  }
}
