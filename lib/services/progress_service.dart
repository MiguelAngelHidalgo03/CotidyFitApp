import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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
  ProgressService({
    required LocalStorageService storage,
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  }) : _storage = storage,
       _dbOverride = db,
       _authOverride = auth;

  final LocalStorageService _storage;
  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  bool get _ready => Firebase.apps.isNotEmpty;
  String? get _uid => _ready ? _auth.currentUser?.uid : null;

  Future<ProgressData> loadProgress({int days = 7}) async {
    final now = DateTime.now();
    final today = DateUtilsCF.dateOnly(now);
    var history = await _storage.getCfHistory();

    final uid = _uid;
    if (uid != null) {
      try {
        final from = today.subtract(Duration(days: days + 45));
        final qs = await _db
            .collection('users')
            .doc(uid)
            .collection('dailyStats')
            .where('dateKey', isGreaterThanOrEqualTo: DateUtilsCF.toKey(from))
            .orderBy('dateKey')
            .get();

        if (qs.docs.isNotEmpty) {
          history = {...history};
          for (final doc in qs.docs) {
            final data = doc.data();
            final key = (data['dateKey'] as String? ?? doc.id).trim();
            if (key.isEmpty) continue;
            final raw = data['cfIndex'];
            final v = raw is int
                ? raw
                : raw is num
                ? raw.round()
                : int.tryParse(raw?.toString() ?? '');
            if (v == null) continue;
            history[key] = v.clamp(0, 100);
            await _storage.upsertCfForDate(dateKey: key, cf: v);
          }
        }
      } catch (_) {
        // Keep local fallback.
      }
    }

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
      current = (current > entry.cfIndex ? current : entry.cfIndex).clamp(
        0,
        100,
      );
    }

    return ProgressData(
      currentCf: current,
      average7Days: avg,
      last7Days: points,
    );
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
