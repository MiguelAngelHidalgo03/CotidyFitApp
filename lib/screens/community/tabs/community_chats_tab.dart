import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../models/chat_model.dart';
import '../../../widgets/community/chat_list_tile.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../chat_screen.dart';
import '../../../services/private_chat_local_service.dart';
import '../../../services/social_firestore_service.dart';

class CommunityChatsTab extends StatefulWidget {
  const CommunityChatsTab({super.key});

  @override
  State<CommunityChatsTab> createState() => _CommunityChatsTabState();
}

class _CommunityChatsTabState extends State<CommunityChatsTab>
    with AutomaticKeepAliveClientMixin {
  final _repo = PrivateChatLocalService();
  final _social = SocialFirestoreService();

  String? _dmChatsUid;
  Stream<List<ChatModel>>? _dmChatsStream;

  List<ChatModel> _chats = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Only load local chats when Firebase mode is not active.
    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;
    if (!firebaseReady || user == null) {
      _load();
    }
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
      MaterialPageRoute(builder: (_) => ChatScreen.private(chatId: chat.id)),
    );
    await _load();
  }

  Future<void> _openDmChat(String chatId) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatScreen.dm(chatId: chatId)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    if (firebaseReady && user != null) {
      if (_dmChatsStream == null || _dmChatsUid != user.uid) {
        _dmChatsUid = user.uid;
        _dmChatsStream = _social.watchDmChats();
      }

      return StreamBuilder<List<ChatModel>>(
        stream: _dmChatsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final e = snapshot.error;
            if (e is FirebaseException) {
              final msg = (e.message ?? '').trim();
              return Padding(
                padding: const EdgeInsets.all(20),
                child: ProgressSectionCard(
                  child: Text(
                    msg.isEmpty
                        ? 'Error cargando chats: ${e.code}'
                        : 'Error cargando chats: ${e.code}\n$msg',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ProgressSectionCard(
                child: Text(
                  'Aún no tienes conversaciones.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          final chats = snapshot.data ?? const <ChatModel>[];
          if (chats.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ProgressSectionCard(
                child: Text(
                  'Aún no tienes conversaciones.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: Text(
                  'Privados',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              for (final chat in chats) ...[
                ProgressSectionCard(
                  padding: EdgeInsets.zero,
                  child: ChatListTile(
                    chat: chat,
                    isProfessionalLocked: false,
                    onTap: () => _openDmChat(chat.id),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final privateChats = _chats.where((c) => c.type != ChatType.grupo).toList();
    final groupChats = _chats.where((c) => c.type == ChatType.grupo).toList();

    if (_chats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ProgressSectionCard(
          child: Text(
            'Aún no tienes conversaciones.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          if (privateChats.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Text(
                'Privados',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            for (final chat in privateChats) ...[
              ProgressSectionCard(
                padding: EdgeInsets.zero,
                child: ChatListTile(
                  chat: chat,
                  isProfessionalLocked: false,
                  onTap: () => _openChat(chat),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
          if (groupChats.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Text(
                'Grupos',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            for (final chat in groupChats) ...[
              ProgressSectionCard(
                padding: EdgeInsets.zero,
                child: ChatListTile(
                  chat: chat,
                  isProfessionalLocked: false,
                  onTap: () => _openChat(chat),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
