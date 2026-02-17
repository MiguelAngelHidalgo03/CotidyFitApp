import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/chat_model.dart';
import '../../../widgets/community/chat_list_tile.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../chat_screen.dart';
import '../../../services/private_chat_local_service.dart';

class CommunityChatsTab extends StatefulWidget {
  const CommunityChatsTab({super.key});

  @override
  State<CommunityChatsTab> createState() => _CommunityChatsTabState();
}

class _CommunityChatsTabState extends State<CommunityChatsTab> {
  final _repo = PrivateChatLocalService();

  List<ChatModel> _chats = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final chats = await _repo.getStartedChats();
    if (!mounted) return;
    setState(() {
      _chats = chats;
      _loading = false;
    });
  }

  Future<void> _openChat(ChatModel chat) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen.private(chatId: chat.id),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ProgressSectionCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chats', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Escribe a un contacto para iniciar un chat.', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _chats.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: CFColors.softGray),
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return ChatListTile(
            chat: chat,
            isProfessionalLocked: false,
            onTap: () => _openChat(chat),
          );
        },
      ),
    );
  }
}
