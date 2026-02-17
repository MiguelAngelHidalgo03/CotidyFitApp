import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'chat_repository.dart';

class ChatLocalService implements ChatRepository {
  static const _kChatsKey = 'cf_chats_json_v1';

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<void> seedIfEmpty() async {
    final p = await _prefs();
    final raw = p.getString(_kChatsKey);
    if (raw != null && raw.trim().isNotEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    final chats = <ChatModel>[
      ChatModel(
        id: 'chat_professional',
        type: ChatType.profesional,
        title: 'Coach CotidyFit',
        avatarKey: 'coach',
        readOnly: false,
        unreadCount: 1,
        updatedAtMs: now - 1000 * 60 * 12,
        messages: [
          MessageModel(
            id: 'm1',
            chatId: 'chat_professional',
            senderId: 'coach',
            senderName: 'Coach',
            isMine: false,
            type: MessageType.text,
            text: 'Hola 👋 Cuando quieras, revisamos tu semana.',
            createdAtMs: now - 1000 * 60 * 12,
          ),
        ],
      ),
      ChatModel(
        id: 'chat_friend_ana',
        type: ChatType.amigo,
        title: 'Ana',
        avatarKey: 'ana',
        readOnly: false,
        unreadCount: 0,
        updatedAtMs: now - 1000 * 60 * 40,
        messages: [
          MessageModel(
            id: 'm2',
            chatId: 'chat_friend_ana',
            senderId: 'ana',
            senderName: 'Ana',
            isMine: false,
            type: MessageType.text,
            text: '¿Entrenas hoy?',
            createdAtMs: now - 1000 * 60 * 40,
          ),
        ],
      ),
      ChatModel(
        id: 'chat_group_week',
        type: ChatType.grupo,
        title: 'Grupo: Semana 1',
        avatarKey: 'grupo_semana',
        readOnly: false,
        unreadCount: 2,
        updatedAtMs: now - 1000 * 60 * 6,
        messages: [
          MessageModel(
            id: 'm3',
            chatId: 'chat_group_week',
            senderId: 'luis',
            senderName: 'Luis',
            isMine: false,
            type: MessageType.text,
            text: 'Buen ritmo equipo 💪',
            createdAtMs: now - 1000 * 60 * 6,
          ),
        ],
      ),
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
            id: 'm4',
            chatId: 'community_updates',
            senderId: 'cotidyfit',
            senderName: 'CotidyFit',
            isMine: false,
            type: MessageType.achievement,
            text: 'Nueva versión: Perfil y Progreso mejorados.',
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
            id: 'm5',
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
    if (idx < 0) {
      throw StateError('Chat not found: $chatId');
    }

    final chat = chats[idx];
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

    final nextMessages = [...chat.messages, msg];
    chats[idx] = chat.copyWith(
      messages: nextMessages,
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
