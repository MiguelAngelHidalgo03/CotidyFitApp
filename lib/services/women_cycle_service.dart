import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe_model.dart';
import '../utils/date_utils.dart';

class WomenCycleData {
  const WomenCycleData({required this.start, this.end});

  final DateTime start;
  final DateTime? end;

  bool get isOpen => end == null;

  bool includes(DateTime date) {
    final d = DateUtilsCF.dateOnly(date);
    final s = DateUtilsCF.dateOnly(start);
    if (d.isBefore(s)) return false;

    final e = end == null ? null : DateUtilsCF.dateOnly(end!);
    if (e == null) return true;
    return !d.isAfter(e);
  }

  Map<String, Object?> toJson() => {
    'startKey': DateUtilsCF.toKey(start),
    if (end != null) 'endKey': DateUtilsCF.toKey(end!),
  };

  static WomenCycleData? fromMap(Map<String, dynamic> map) {
    final startKey = (map['startKey'] as String? ?? '').trim();
    final endKey = (map['endKey'] as String? ?? '').trim();

    final start = DateUtilsCF.fromKey(startKey);
    final end = endKey.isEmpty ? null : DateUtilsCF.fromKey(endKey);
    if (start == null) return null;
    final s = DateUtilsCF.dateOnly(start);
    final e = end == null ? null : DateUtilsCF.dateOnly(end);
    if (e != null && e.isBefore(s)) return null;
    return WomenCycleData(start: s, end: e);
  }
}

class WomenCycleFoodTip {
  const WomenCycleFoodTip({
    required this.title,
    required this.reason,
    this.recipes = const [],
  });

  final String title;
  final String reason;
  final List<RecipeModel> recipes;
}

class WomenCycleService {
  WomenCycleService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _dbOverride = db,
      _authOverride = auth;

  static const _kLocalKey = 'cf_women_cycle_current_v1';

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  bool get _ready => Firebase.apps.isNotEmpty;
  String? get _uid => _ready ? _auth.currentUser?.uid : null;

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<WomenCycleData?> getCurrentCycle() async {
    final uid = _uid;
    if (uid != null) {
      try {
        final snap = await _db
            .collection('users')
            .doc(uid)
            .collection('womenCycle')
            .doc('current')
            .get();
        final data = snap.data();
        if (data != null) {
          final parsed = WomenCycleData.fromMap(data);
          if (parsed != null) {
            await _saveLocal(parsed);
            return parsed;
          }
        }

        final logs = await _db
            .collection('users')
            .doc(uid)
            .collection('cycleLogs')
            .orderBy('updatedAt', descending: true)
            .limit(1)
            .get();
        if (logs.docs.isNotEmpty) {
          final parsed = WomenCycleData.fromMap(logs.docs.first.data());
          if (parsed != null) {
            await _saveLocal(parsed);
            return parsed;
          }
        }
      } catch (_) {
        // fallback local
      }
    }

    final p = await _prefs();
    final raw = p.getString(_kLocalKey);
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final map = <String, dynamic>{};
    for (final e in decoded.entries) {
      if (e.key is String) map[e.key as String] = e.value;
    }
    return WomenCycleData.fromMap(map);
  }

  Future<WomenCycleData> startPeriod({DateTime? startDate}) async {
    final s = DateUtilsCF.dateOnly(startDate ?? DateTime.now());
    final data = WomenCycleData(start: s, end: null);
    await saveCurrentCycle(data);
    return data;
  }

  Future<WomenCycleData?> endPeriod({DateTime? endDate}) async {
    final current = await getCurrentCycle();
    if (current == null) return null;
    if (current.end != null) return current;

    final e0 = DateUtilsCF.dateOnly(endDate ?? DateTime.now());
    final e = e0.isBefore(current.start) ? current.start : e0;
    final data = WomenCycleData(start: current.start, end: e);
    await saveCurrentCycle(data);
    return data;
  }

  Future<void> saveCurrentCycle(WomenCycleData data) async {
    await _saveLocal(data);

    final uid = _uid;
    if (uid != null) {
      try {
        final payload = <String, Object?>{
          ...data.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (data.end == null) {
          // Ensure old endKey doesn't linger when starting a new period.
          payload['endKey'] = FieldValue.delete();
        }

        await _db
            .collection('users')
            .doc(uid)
            .collection('womenCycle')
            .doc('current')
            .set(payload, SetOptions(merge: true));

        final end = data.end;
        if (end != null) {
          final cycleId =
              '${DateUtilsCF.toKey(data.start)}_${DateUtilsCF.toKey(end)}';
          await _db
              .collection('users')
              .doc(uid)
              .collection('cycleLogs')
              .doc(cycleId)
              .set({
                ...data.toJson(),
                'cycleId': cycleId,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }
      } catch (_) {
        // local already saved
      }
    }
  }

  Future<void> _saveLocal(WomenCycleData data) async {
    final p = await _prefs();
    await p.setString(_kLocalKey, jsonEncode(data.toJson()));
  }

  List<WomenCycleFoodTip> buildFoodTips({
    required DateTime now,
    required List<RecipeModel> recipes,
  }) {
    final out = <WomenCycleFoodTip>[];

    final highProtein = recipes
        .where(
          (r) =>
              r.macrosPerServing.proteinG >= 22 ||
              r.goals.contains(RecipeGoal.highProtein),
        )
        .take(2)
        .toList();

    final ironKeywords = [
      'espinaca',
      'lenteja',
      'garbanzo',
      'ternera',
      'hígado',
      'alubia',
      'acelga',
    ];
    final ironRich = recipes
        .where((r) {
          final hay = r.ingredients.map((i) => i.name.toLowerCase()).join(' ');
          return ironKeywords.any(hay.contains);
        })
        .take(2)
        .toList();

    final moderateCarbs = recipes
        .where(
          (r) =>
              r.macrosPerServing.carbsG >= 25 &&
              r.macrosPerServing.carbsG <= 55,
        )
        .take(2)
        .toList();

    if (highProtein.isNotEmpty) {
      out.add(
        WomenCycleFoodTip(
          title: 'Proteína útil',
          reason: 'Ayuda a recuperar energía y reducir antojos.',
          recipes: highProtein,
        ),
      );
    }

    if (ironRich.isNotEmpty) {
      out.add(
        WomenCycleFoodTip(
          title: 'Hierro',
          reason: 'Útil en días de regla para fatiga y vitalidad.',
          recipes: ironRich,
        ),
      );
    }

    if (moderateCarbs.isNotEmpty) {
      out.add(
        WomenCycleFoodTip(
          title: 'Carbohidrato estable',
          reason: 'Mejor tolerancia energética y menos hinchazón por picos.',
          recipes: moderateCarbs,
        ),
      );
    }

    if (out.isEmpty) {
      out.add(
        const WomenCycleFoodTip(
          title: 'Prioriza proteína + hierro + carbohidrato complejo',
          reason: 'Combinación útil para energía, hinchazón y recuperación.',
        ),
      );
    }

    return out;
  }
}
