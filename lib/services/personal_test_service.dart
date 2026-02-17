import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/personal_test.dart';

class PersonalTestService {
  static const _kKey = 'cf_personal_test_json';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<PersonalTest> getTest() async {
    final p = await _prefs();
    final raw = p.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return PersonalTest.defaults();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return PersonalTest.defaults();
      final map = <String, Object?>{};
      for (final e in decoded.entries) {
        map[e.key.toString()] = e.value;
      }
      return PersonalTest.fromJson(map);
    } catch (_) {
      return PersonalTest.defaults();
    }
  }

  Future<void> saveTest(PersonalTest test) async {
    final p = await _prefs();
    await p.setString(_kKey, jsonEncode(test.toJson()));
  }

  Future<void> clear() async {
    final p = await _prefs();
    await p.remove(_kKey);
  }
}
