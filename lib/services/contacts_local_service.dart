import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact_model.dart';

class ContactsLocalService {
  static const _kContactsKey = 'cf_contacts_json_v1';

  static const coach = ContactModel(
    id: 'contact_coach',
    name: 'Coach CotidyFit',
    tag: '@coach',
    avatarKey: 'coach',
    status: ContactStatus.accepted,
    isCoach: true,
    requiresPremium: true,
  );

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> seedIfEmpty() async {
    final p = await _prefs();
    final raw = p.getString(_kContactsKey);
    if (raw != null && raw.trim().isNotEmpty) return;

    final contacts = <ContactModel>[
      const ContactModel(
        id: 'contact_ana',
        name: 'Ana',
        tag: '@ana01',
        avatarKey: 'ana',
        status: ContactStatus.accepted,
        isCoach: false,
        requiresPremium: false,
      ),
      const ContactModel(
        id: 'contact_mario',
        name: 'Mario',
        tag: '@mario_fit',
        avatarKey: 'mario',
        status: ContactStatus.pending,
        isCoach: false,
        requiresPremium: false,
      ),
    ];

    await _save(contacts);
  }

  Future<List<ContactModel>> getContacts() async {
    await seedIfEmpty();
    final list = await _load();
    list.sort((a, b) {
      if (a.status != b.status) {
        return a.status == ContactStatus.pending ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<ContactModel?> getContactById(String id) async {
    if (id == coach.id) return coach;
    final list = await getContacts();
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> addFriendMock({required String name, required String tag}) async {
    await seedIfEmpty();
    final cleanedName = name.trim();
    var cleanedTag = tag.trim();

    if (cleanedName.isEmpty) return;
    if (cleanedTag.isEmpty) return;
    if (!cleanedTag.startsWith('@')) cleanedTag = '@$cleanedTag';

    // simple tag validation
    final valid = RegExp(r'^@[a-zA-Z0-9_]{3,20}$');
    if (!valid.hasMatch(cleanedTag)) {
      throw FormatException('Tag inválido');
    }

    final list = await _load();
    if (list.any((c) => c.tag.toLowerCase() == cleanedTag.toLowerCase())) {
      throw StateError('Tag ya existe');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    list.insert(
      0,
      ContactModel(
        id: 'contact_$now',
        name: cleanedName,
        tag: cleanedTag,
        avatarKey: cleanedName,
        status: ContactStatus.pending,
        isCoach: false,
        requiresPremium: false,
      ),
    );

    await _save(list);
  }

  Future<List<ContactModel>> _load() async {
    final p = await _prefs();
    final raw = p.getString(_kContactsKey);
    if (raw == null || raw.trim().isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    final out = <ContactModel>[];
    for (final v in decoded) {
      if (v is Map) {
        final casted = v.map((k, vv) => MapEntry(k.toString(), vv));
        final c = ContactModel.fromJson(casted);
        if (c != null) out.add(c);
      }
    }
    return out;
  }

  Future<void> _save(List<ContactModel> contacts) async {
    final p = await _prefs();
    await p.setString(_kContactsKey, jsonEncode([for (final c in contacts) c.toJson()]));
  }
}
