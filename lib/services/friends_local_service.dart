import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/friend_model.dart';

class FriendsLocalService {
  static const _kFriendsKey = 'cf_friends_json_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> seedIfEmpty() async {
    final p = await _prefs();
    final raw = p.getString(_kFriendsKey);
    if (raw != null && raw.trim().isNotEmpty) return;

    final friends = <FriendModel>[
      const FriendModel(
        id: 'friend_ana',
        name: 'Ana',
        avatarKey: 'ana',
        status: FriendStatus.accepted,
      ),
      const FriendModel(
        id: 'friend_mario',
        name: 'Mario',
        avatarKey: 'mario',
        status: FriendStatus.pending,
      ),
    ];

    await _save(friends);
  }

  Future<List<FriendModel>> getFriends() async {
    await seedIfEmpty();
    final list = await _load();
    list.sort((a, b) {
      if (a.status != b.status) {
        return a.status == FriendStatus.pending ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<void> addFriendMock(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return;

    final list = await _load();
    final now = DateTime.now().millisecondsSinceEpoch;
    list.insert(
      0,
      FriendModel(
        id: 'friend_$now',
        name: cleaned,
        avatarKey: cleaned,
        status: FriendStatus.pending,
      ),
    );
    await _save(list);
  }

  Future<void> markAccepted(String friendId) async {
    final list = await _load();
    final idx = list.indexWhere((f) => f.id == friendId);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(status: FriendStatus.accepted);
    await _save(list);
  }

  Future<List<FriendModel>> _load() async {
    final p = await _prefs();
    final raw = p.getString(_kFriendsKey);
    if (raw == null || raw.trim().isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    final out = <FriendModel>[];
    for (final v in decoded) {
      if (v is Map) {
        final casted = v.map((k, vv) => MapEntry(k.toString(), vv));
        final f = FriendModel.fromJson(casted);
        if (f != null) out.add(f);
      }
    }
    return out;
  }

  Future<void> _save(List<FriendModel> friends) async {
    final p = await _prefs();
    await p.setString(_kFriendsKey, jsonEncode([for (final f in friends) f.toJson()]));
  }
}
