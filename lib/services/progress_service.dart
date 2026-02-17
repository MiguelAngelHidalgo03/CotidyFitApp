import '../models/cf_history_point.dart';
import '../models/daily_entry.dart';
import '../utils/date_utils.dart';
import 'local_storage_service.dart';

class ProgressData {
  final int currentCf;
  final int average7Days;
  final List<CfHistoryPoint> last7Days; // oldest -> newest, always 7 points

  const ProgressData({
    required this.currentCf,
    required this.average7Days,
    required this.last7Days,
  });
}

class ProgressService {
  ProgressService({required LocalStorageService storage}) : _storage = storage;

  final LocalStorageService _storage;

  Future<ProgressData> loadProgress({int days = 7}) async {
    final now = DateTime.now();
    final today = DateUtilsCF.dateOnly(now);
    final history = await _storage.getCfHistory();

    final points = <CfHistoryPoint>[];
    for (var i = days - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final key = DateUtilsCF.toKey(date);
      final value = history[key] ?? 0;
      points.add(CfHistoryPoint(date: date, value: value));
    }

    final sum = points.fold<int>(0, (acc, p) => acc + p.value);
    final avg = (sum / days).round().clamp(0, 100);

    final todayKey = DateUtilsCF.toKey(today);
    var current = history[todayKey] ?? 0;

    // If today has an entry stored (completed), prefer that value.
    final entry = await _storage.getTodayEntry();
    if (entry is DailyEntry && entry.dateKey == todayKey) {
      current = (current > entry.cfIndex ? current : entry.cfIndex).clamp(0, 100);
    }

    return ProgressData(currentCf: current, average7Days: avg, last7Days: points);
  }

  String motivationalMessageForAverage(int avg) {
    if (avg >= 80) return 'Excelente constancia';
    if (avg >= 50) return 'Buen progreso';
    if (avg >= 20) return 'Puedes mejorar';
    return 'Empieza hoy';
  }

  String formatShortDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }
}
