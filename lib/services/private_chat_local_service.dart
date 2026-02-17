import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_model.dart';
import '../models/contact_model.dart';
import '../models/message_model.dart';

class PrivateChatLocalService {
  static const _kChatsKey = 'cf_private_chats_json_v2';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<ChatModel>> getStartedChats() async {
    final chats = await _loadChats();

    final started = chats.where((c) => c.messages.any((m) => m.isMine)).toList();
    started.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return started;
  }

  Future<ChatModel?> getChatById(String chatId) async {
    final chats = await _loadChats();
    for (final c in chats) {
      if (c.id == chatId) return c;
    }
    return null;
  }

  Future<ChatModel?> getChatForContact(String contactId) async {
    final chats = await _loadChats();
    for (final c in chats) {
      if (c.id == _chatIdForContact(contactId)) return c;
    }
    return null;
  }

  Future<void> markChatRead(String chatId) async {
    final chats = await _loadChats();
    final idx = chats.indexWhere((c) => c.id == chatId);
    if (idx < 0) return;
    final current = chats[idx];
    if (current.unreadCount == 0) return;
    chats[idx] = current.copyWith(unreadCount: 0);
    await _saveChats(chats);
  }

  Future<MessageModel> sendMessageToContact({
    required ContactModel contact,
    required MessageType type,
    required String text,
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) throw StateError('Empty message');

    final chats = await _loadChats();
    final chatId = _chatIdForContact(contact.id);
    final idx = chats.indexWhere((c) => c.id == chatId);

    final now = DateTime.now().millisecondsSinceEpoch;
    final msg = MessageModel(
      id: 'm_${now}_me',
      chatId: chatId,
      senderId: 'me',
      senderName: 'Tú',
      isMine: true,
      type: type,
      text: cleaned,
      createdAtMs: now,
    );

    if (idx < 0) {
      final created = ChatModel(
        id: chatId,
        type: contact.requiresPremium ? ChatType.profesional : ChatType.amigo,
        title: contact.name,
        avatarKey: contact.avatarKey,
        readOnly: false,
        unreadCount: 0,
        updatedAtMs: now,
        messages: [msg],
      );
      chats.add(created);
    } else {
      final current = chats[idx];
      chats[idx] = current.copyWith(
        messages: [...current.messages, msg],
        updatedAtMs: now,
      );
    }

    await _saveChats(chats);
    return msg;
  }

  Future<MessageModel> sendMessageToChat({
    required String chatId,
    required MessageType type,
    required String text,
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) throw StateError('Empty message');

    final chats = await _loadChats();
    final idx = chats.indexWhere((c) => c.id == chatId);
    if (idx < 0) throw StateError('Chat not found: $chatId');

    final now = DateTime.now().millisecondsSinceEpoch;
    final msg = MessageModel(
      id: 'm_${now}_me',
      chatId: chatId,
      senderId: 'me',
      senderName: 'Tú',
      isMine: true,
      type: type,
      text: cleaned,
      createdAtMs: now,
    );

    final current = chats[idx];
    chats[idx] = current.copyWith(
      messages: [...current.messages, msg],
      updatedAtMs: now,
    );

    await _saveChats(chats);
    return msg;
  }

  String _chatIdForContact(String contactId) => 'chat_$contactId';

  Future<List<ChatModel>> _loadChats() async {
    final p = await _prefs();
    final raw = p.getString(_kChatsKey);
    if (raw == null || raw.trim().isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    final chats = <ChatModel>[];
    for (final v in decoded) {
      if (v is Map) {
        final casted = v.map((k, vv) => MapEntry(k.toString(), vv));
        final c = ChatModel.fromJson(casted);
        if (c != null) chats.add(c);
      }
    }
    return chats;
  }

  Future<void> _saveChats(List<ChatModel> chats) async {
    final p = await _prefs();
    await p.setString(_kChatsKey, jsonEncode([for (final c in chats) c.toJson()]));
  }
}
