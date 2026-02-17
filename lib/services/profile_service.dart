import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class ProfileService {
  static const _kUserProfileKey = 'cf_user_profile_json';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<UserProfile?> getProfile() async {
    final p = await _prefs();
    final raw = p.getString(_kUserProfileKey);
    if (raw == null || raw.trim().isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;

    final map = <String, Object?>{};
    for (final e in decoded.entries) {
      if (e.key is String) map[e.key as String] = e.value;
    }

    return UserProfile.fromJson(map);
  }

  Future<UserProfile> getOrCreateProfile({String fallbackGoal = 'Salud'}) async {
    final existing = await getProfile();
    if (existing != null) return existing;
    final created = UserProfile(goal: fallbackGoal);
    await saveProfile(created);
    return created;
  }

  Future<String?> getGoal() async {
    final profile = await getProfile();
    return profile?.goal;
  }

  Future<void> setGoal(String goal) async {
    final cleaned = goal.trim();
    if (cleaned.isEmpty) return;

    final current = await getProfile();
    final next = (current ?? const UserProfile(goal: 'Salud')).copyWith(goal: cleaned);
    await saveProfile(next);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final p = await _prefs();
    await p.setString(_kUserProfileKey, jsonEncode(profile.toJson()));
  }

  Future<void> clearProfile() async {
    final p = await _prefs();
    await p.remove(_kUserProfileKey);
  }
}
