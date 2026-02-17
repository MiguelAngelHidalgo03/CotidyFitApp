import 'package:flutter/material.dart';

import '../../../models/chat_model.dart';
import '../../../services/community_chat_local_service.dart';
import '../../../services/chat_repository.dart';
import '../../../widgets/community/chat_list_tile.dart';
import '../chat_screen.dart';

class CommunityCommunitiesTab extends StatefulWidget {
  const CommunityCommunitiesTab({super.key});

  @override
  State<CommunityCommunitiesTab> createState() => _CommunityCommunitiesTabState();
}

class _CommunityCommunitiesTabState extends State<CommunityCommunitiesTab> {
  final ChatRepository _repo = CommunityChatLocalService();

  List<ChatModel> _communities = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final chats = await _repo.getChats();
    if (!mounted) return;
    setState(() {
      _communities = chats.where((c) => c.type == ChatType.comunidad).toList();
      _loading = false;
    });
  }

  Future<void> _open(ChatModel chat) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen.community(chatId: chat.id)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _communities.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final chat = _communities[index];
          return ChatListTile(
            chat: chat,
            isProfessionalLocked: false,
            onTap: () => _open(chat),
          );
        },
      ),
    );
  }
}
