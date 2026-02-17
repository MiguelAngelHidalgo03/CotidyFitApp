enum MessageType {
  text,
  routine,
  achievement,
  daySummary,
  diet,
  streaks,
}

extension MessageTypeX on MessageType {
  String get label {
    switch (this) {
      case MessageType.text:
        return 'Mensaje';
      case MessageType.routine:
        return 'Rutina';
      case MessageType.achievement:
        return 'Logro';
      case MessageType.daySummary:
        return 'Resumen del día';
      case MessageType.diet:
        return 'Dieta';
      case MessageType.streaks:
        return 'Rachas';
    }
  }
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final bool isMine;

  final MessageType type;
  final String text;
  final int createdAtMs;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.isMine,
    required this.type,
    required this.text,
    required this.createdAtMs,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'isMine': isMine,
        'type': type.name,
        'text': text,
        'createdAtMs': createdAtMs,
      };

  static MessageModel? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final chatId = json['chatId'];
    final senderId = json['senderId'];
    final senderName = json['senderName'];
    final typeRaw = json['type'];
    final text = json['text'];
    final createdAtMs = json['createdAtMs'];

    if (id is! String || id.trim().isEmpty) return null;
    if (chatId is! String || chatId.trim().isEmpty) return null;
    if (senderId is! String || senderId.trim().isEmpty) return null;
    if (senderName is! String || senderName.trim().isEmpty) return null;
    if (text is! String) return null;

    MessageType type = MessageType.text;
    for (final v in MessageType.values) {
      if (v.name == typeRaw) {
        type = v;
        break;
      }
    }

    return MessageModel(
      id: id.trim(),
      chatId: chatId.trim(),
      senderId: senderId.trim(),
      senderName: senderName.trim(),
      isMine: json['isMine'] is bool ? json['isMine'] as bool : false,
      type: type,
      text: text,
      createdAtMs: createdAtMs is int ? createdAtMs : DateTime.now().millisecondsSinceEpoch,
    );
  }
}
