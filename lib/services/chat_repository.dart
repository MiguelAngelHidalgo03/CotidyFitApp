import '../models/chat_model.dart';
import '../models/message_model.dart';

abstract class ChatRepository {
  Future<List<ChatModel>> getChats();
  Future<ChatModel?> getChatById(String id);

  Future<void> markChatRead(String chatId);
  Future<MessageModel> sendMessage({
    required String chatId,
    required MessageType type,
    required String text,
  });

  Future<void> seedIfEmpty();
}
