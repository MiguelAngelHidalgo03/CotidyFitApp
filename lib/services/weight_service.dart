import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weight_entry.dart';
import '../utils/date_utils.dart';

class WeightSummary {
  final WeightEntry? latest;
  final double? diffFromPrevious; // latest - previous
  final double? diffFromWeekBefore; // latest - entry near (latest - 7d)
  final List<WeightEntry> history; // oldest -> newest

  const WeightSummary({
    required this.latest,
    required this.diffFromPrevious,
    required this.diffFromWeekBefore,
    required this.history,
  });
}

class WeightService {
  static const _kWeightHistoryKey = 'cf_weight_history_json';

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  WeightService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _dbOverride = db,
      _authOverride = auth;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  bool get _ready => Firebase.apps.isNotEmpty;
  String? get _uid => _ready ? _auth.currentUser?.uid : null;

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<WeightEntry>> getHistory() async {
    final uid = _uid;
    if (uid != null) {
      try {
        final qs = await _db
            .collection('users')
            .doc(uid)
            .collection('weightEntries')
            .orderBy('dateKey')
            .get();

        final cloud = <WeightEntry>[];
        for (final doc in qs.docs) {
          final map = Map<String, Object?>.from(doc.data());
          map['dateKey'] = (map['dateKey'] as String?) ?? doc.id;
          final entry = WeightEntry.fromJson(map);
          if (entry != null) cloud.add(entry);
        }

        if (cloud.isNotEmpty) {
          await _saveLocalHistory(cloud);
          return cloud;
        }
      } catch (_) {
        // Fallback to local cache.
      }
    }

    final p = await _prefs();
    final raw = p.getString(_kWeightHistoryKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    final out = <WeightEntry>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = <String, Object?>{};
      for (final e in item.entries) {
        if (e.key is String) map[e.key as String] = e.value;
      }
      final entry = WeightEntry.fromJson(map);
      if (entry != null) out.add(entry);
    }

    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  Future<void> upsertToday(double weight) async {
    final today = DateUtilsCF.dateOnly(DateTime.now());
    await upsertForDate(today, weight);
  }

  Future<void> upsertForDate(DateTime date, double weight) async {
    final normalized = DateUtilsCF.dateOnly(date);
    final key = DateUtilsCF.toKey(normalized);

    final history = (await getHistory()).toList();
    final idx = history.indexWhere((e) => e.dateKey == key);

    final entry = WeightEntry(date: normalized, weight: weight);
    if (idx >= 0) {
      history[idx] = entry;
    } else {
      history.add(entry);
    }

    history.sort((a, b) => a.date.compareTo(b.date));
    await _saveLocalHistory(history);

    final uid = _uid;
    if (uid != null) {
      try {
        await _db
            .collection('users')
            .doc(uid)
            .collection('weightEntries')
            .doc(key)
            .set({
              'dateKey': key,
              'weight': weight,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (_) {
        // Keep local write as fallback.
      }
    }
  }

  Future<void> _saveLocalHistory(List<WeightEntry> history) async {
    final raw = jsonEncode(history.map((e) => e.toJson()).toList());
    final p = await _prefs();
    await p.setString(_kWeightHistoryKey, raw);
  }

  Future<WeightSummary> getSummary({int maxPoints = 30}) async {
    final all = await getHistory();
    final history = all.length <= maxPoints
        ? all
        : all.sublist(all.length - maxPoints);

    if (history.isEmpty) {
      return const WeightSummary(
        latest: null,
        diffFromPrevious: null,
        diffFromWeekBefore: null,
        history: [],
      );
    }

    final latest = history.last;

    double? diffPrev;
    if (history.length >= 2) {
      diffPrev = latest.weight - history[history.length - 2].weight;
    }

    // Compare with the closest entry on/before (latest - 7 days).
    final targetDate = latest.date.subtract(const Duration(days: 7));
    WeightEntry? weekBefore;
    for (var i = history.length - 1; i >= 0; i--) {
      final e = history[i];
      if (!e.date.isAfter(targetDate)) {
        weekBefore = e;
        break;
      }
    }

    final diffWeek = weekBefore == null
        ? null
        : (latest.weight - weekBefore.weight);

    return WeightSummary(
      latest: latest,
      diffFromPrevious: diffPrev,
      diffFromWeekBefore: diffWeek,
      history: history,
    );
  }
}
