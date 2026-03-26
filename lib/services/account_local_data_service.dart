import 'package:shared_preferences/shared_preferences.dart';

class AccountLocalDataService {
  static const _kLastSignedInUidKey = 'cf_last_signed_in_uid';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<String?> getLastSignedInUid() async {
    final prefs = await _prefs();
    final value = prefs.getString(_kLastSignedInUidKey)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setLastSignedInUid(String? uid) async {
    final prefs = await _prefs();
    final cleaned = uid?.trim() ?? '';
    if (cleaned.isEmpty) {
      await prefs.remove(_kLastSignedInUidKey);
      return;
    }
    await prefs.setString(_kLastSignedInUidKey, cleaned);
  }

  Future<void> clearAllLocalAccountData() async {
    final prefs = await _prefs();
    await prefs.clear();
  }

  Future<bool> resetIfAccountChanged(String currentUid) async {
    final cleanedUid = currentUid.trim();
    if (cleanedUid.isEmpty) return false;

    final previousUid = await getLastSignedInUid();
    if (previousUid != null && previousUid != cleanedUid) {
      await clearAllLocalAccountData();
    }

    await setLastSignedInUid(cleanedUid);
    return previousUid != null && previousUid != cleanedUid;
  }
}