import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'chat_repository.dart';

class CommunityChatLocalService implements ChatRepository {
  static const _kChatsKey = 'cf_community_chats_json_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<void> seedIfEmpty() async {
    final p = await _prefs();
    final raw = p.getString(_kChatsKey);
    if (raw != null && raw.trim().isNotEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    final chats = <ChatModel>[
      ChatModel(
        id: 'community_updates',
        type: ChatType.comunidad,
        title: 'Actualizaciones CotidyFit',
        avatarKey: 'cotidyfit',
        readOnly: true,
        unreadCount: 1,
        updatedAtMs: now - 1000 * 60 * 90,
        messages: [
          MessageModel(
            id: 'cu_1',
            chatId: 'community_updates',
            senderId: 'cotidyfit',
            senderName: 'CotidyFit',
            isMine: false,
            type: MessageType.achievement,
            text: 'Actualización: nuevo módulo Comunidad.',
            createdAtMs: now - 1000 * 60 * 90,
          ),
        ],
      ),
      ChatModel(
        id: 'community_fitness',
        type: ChatType.comunidad,
        title: 'Comunidad Fitness',
        avatarKey: 'fitness',
        readOnly: false,
        unreadCount: 0,
        updatedAtMs: now - 1000 * 60 * 25,
        messages: [
          MessageModel(
            id: 'cf_1',
            chatId: 'community_fitness',
            senderId: 'mod',
            senderName: 'Mod',
            isMine: false,
            type: MessageType.text,
            text: 'Bienvenido/a. Comparte tu objetivo de hoy.',
            createdAtMs: now - 1000 * 60 * 25,
          ),
        ],
      ),
    ];

    await _saveChats(chats);
  }

  @override
  Future<List<ChatModel>> getChats() async {
    await seedIfEmpty();
    final chats = await _loadChats();
    chats.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return chats;
  }

  @override
  Future<ChatModel?> getChatById(String id) async {
    await seedIfEmpty();
    final chats = await _loadChats();
    for (final c in chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<void> markChatRead(String chatId) async {
    final chats = await _loadChats();
    final idx = chats.indexWhere((c) => c.id == chatId);
    if (idx < 0) return;
    final current = chats[idx];
    if (current.unreadCount == 0) return;
    chats[idx] = current.copyWith(unreadCount: 0);
    await _saveChats(chats);
  }

  @override
  Future<MessageModel> sendMessage({
    required String chatId,
    required MessageType type,
    required String text,
  }) async {
    final cleaned = text.trim();
    final chats = await _loadChats();
    final idx = chats.indexWhere((c) => c.id == chatId);
    if (idx < 0) throw StateError('Chat not found: $chatId');

    final chat = chats[idx];
    if (chat.readOnly) throw StateError('Chat is read-only');

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

    chats[idx] = chat.copyWith(
      messages: [...chat.messages, msg],
      updatedAtMs: now,
    );

    await _saveChats(chats);
    return msg;
  }

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
