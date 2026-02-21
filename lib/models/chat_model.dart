import 'message_model.dart';

enum ChatType { profesional, amigo, grupo, comunidad }

extension ChatTypeX on ChatType {
  String get label {
    switch (this) {
      case ChatType.profesional:
        return 'Profesional';
      case ChatType.amigo:
        return 'Amigo';
      case ChatType.grupo:
        return 'Grupo';
      case ChatType.comunidad:
        return 'Comunidad';
    }
  }
}

class ChatModel {
  final String id;
  final ChatType type;
  final String title;
  final String avatarKey;

  /// True when this conversation is hidden for the current user.
  ///
  /// Used for WhatsApp-style "delete conversation locally".
  final bool hiddenForMe;

  final bool readOnly;

  final int unreadCount;
  final int updatedAtMs;

  final List<MessageModel> messages;

  const ChatModel({
    required this.id,
    required this.type,
    required this.title,
    required this.avatarKey,
    this.hiddenForMe = false,
    required this.readOnly,
    required this.unreadCount,
    required this.updatedAtMs,
    required this.messages,
  });

  MessageModel? get lastMessage => messages.isEmpty ? null : messages.last;

  ChatModel copyWith({
    ChatType? type,
    String? title,
    String? avatarKey,
    bool? hiddenForMe,
    bool? readOnly,
    int? unreadCount,
    int? updatedAtMs,
    List<MessageModel>? messages,
  }) {
    return ChatModel(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      avatarKey: avatarKey ?? this.avatarKey,
      hiddenForMe: hiddenForMe ?? this.hiddenForMe,
      readOnly: readOnly ?? this.readOnly,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      messages: messages ?? this.messages,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'avatarKey': avatarKey,
    'hiddenForMe': hiddenForMe,
    'readOnly': readOnly,
    'unreadCount': unreadCount,
    'updatedAtMs': updatedAtMs,
    'messages': [for (final m in messages) m.toJson()],
  };

  static ChatModel? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final typeRaw = json['type'];
    final title = json['title'];
    final avatarKey = json['avatarKey'];

    if (id is! String || id.trim().isEmpty) return null;
    if (title is! String || title.trim().isEmpty) return null;

    ChatType type = ChatType.amigo;
    for (final v in ChatType.values) {
      if (v.name == typeRaw) {
        type = v;
        break;
      }
    }

    final messagesRaw = json['messages'];
    final messages = <MessageModel>[];
    if (messagesRaw is List) {
      for (final v in messagesRaw) {
        if (v is Map) {
          final casted = v.map((k, vv) => MapEntry(k.toString(), vv));
          final m = MessageModel.fromJson(casted);
          if (m != null) messages.add(m);
        }
      }
    }

    final updatedAtMs = json['updatedAtMs'] is int
        ? json['updatedAtMs'] as int
        : (messages.isEmpty
              ? DateTime.now().millisecondsSinceEpoch
              : messages.last.createdAtMs);

    return ChatModel(
      id: id.trim(),
      type: type,
      title: title.trim(),
      avatarKey: avatarKey is String && avatarKey.trim().isNotEmpty
          ? avatarKey.trim()
          : title.trim(),
      hiddenForMe: json['hiddenForMe'] is bool
          ? json['hiddenForMe'] as bool
          : false,
      readOnly: json['readOnly'] is bool ? json['readOnly'] as bool : false,
      unreadCount: json['unreadCount'] is int
          ? (json['unreadCount'] as int).clamp(0, 999)
          : 0,
      updatedAtMs: updatedAtMs,
      messages: messages,
    );
  }
}
