import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../models/chat_model.dart';
import '../../../services/community_chat_local_service.dart';
import '../../../services/chat_repository.dart';
import '../../../widgets/community/chat_list_tile.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../chat_screen.dart';

class CommunityCommunitiesTab extends StatefulWidget {
  const CommunityCommunitiesTab({super.key});

  @override
  State<CommunityCommunitiesTab> createState() => _CommunityCommunitiesTabState();
}

class _CommunityCommunitiesTabState extends State<CommunityCommunitiesTab> with AutomaticKeepAliveClientMixin {
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
    super.build(context);
    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    if (firebaseReady && user != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Comunidades', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Próximamente', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          for (final chat in _communities) ...[
            ProgressSectionCard(
              padding: EdgeInsets.zero,
              child: ChatListTile(
                chat: chat,
                isProfessionalLocked: false,
                onTap: () => _open(chat),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
