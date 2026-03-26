import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/chat_model.dart';
import '../../../models/message_model.dart';
import '../../../services/chat_repository.dart';
import '../../../services/community_chat_local_service.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../chat_screen.dart';
import '../community_group_chat_screen.dart';

class CommunityNewsTab extends StatefulWidget {
  const CommunityNewsTab({super.key});

  @override
  State<CommunityNewsTab> createState() => _CommunityNewsTabState();
}

class _CommunityNewsTabState extends State<CommunityNewsTab>
    with AutomaticKeepAliveClientMixin {
  final ChatRepository _repo = CommunityChatLocalService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool _loadingLocal = true;
  bool _onlySubscribed = false;
  List<ChatModel> _localCommunities = const <ChatModel>[];

  @override
  void initState() {
    super.initState();
    _loadLocalIfNeeded();
  }

  Future<void> _loadLocalIfNeeded() async {
    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;
    if (firebaseReady && user != null) {
      setState(() => _loadingLocal = false);
      return;
    }

    setState(() => _loadingLocal = true);
    final chats = await _repo.getChats();
    if (!mounted) return;
    setState(() {
      _localCommunities = chats
          .where((c) => c.type == ChatType.comunidad)
          .toList();
      _loadingLocal = false;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  MessageModel? _messageFromLastMessageMap({
    required String groupId,
    required String myUid,
    required Map<String, Object?>? map,
  }) {
    if (map == null) return null;

    final senderUid = (map['senderUid'] as String?)?.trim() ?? '';
    final senderName = (map['senderName'] as String?)?.trim() ?? 'Usuario';
    final typeRaw = (map['type'] as String?)?.trim();
    final text = (map['text'] as String?) ?? '';
    final shareRaw = map['share'];
    final createdAtMs = map['createdAtMs'] is int
        ? map['createdAtMs'] as int
        : DateTime.now().millisecondsSinceEpoch;

    Map<String, Object?>? share;
    if (shareRaw is Map) {
      share = shareRaw.map((k, v) => MapEntry(k.toString(), v));
    }

    MessageType type = MessageType.text;
    for (final value in MessageType.values) {
      if (value.name == typeRaw) {
        type = value;
        break;
      }
    }

    return MessageModel(
      id: 'last',
      chatId: groupId,
      senderId: senderUid,
      senderName: senderName,
      isMine: senderUid == myUid,
      type: type,
      text: text,
      share: share,
      createdAtMs: createdAtMs,
    );
  }

  _NewsItem? _itemFromGroupDoc({
    required String myUid,
    required QueryDocumentSnapshot<Map<String, dynamic>> docSnap,
    required Map<String, Object?> prefData,
    required int? clearedAtMs,
  }) {
    final data = docSnap.data();
    if (data['active'] == false) return null;

    final title = (data['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) return null;

    final description = (data['description'] as String?)?.trim() ?? '';
    final order = (data['order'] as num?)?.toInt() ?? 9999;

    final lastRaw = data['lastMessage'];
    final lastMap = lastRaw is Map
        ? lastRaw.map((k, v) => MapEntry(k.toString(), v))
        : null;
    final lastMessage = _messageFromLastMessageMap(
      groupId: docSnap.id,
      myUid: myUid,
      map: lastMap,
    );

    int updatedAtMs = 0;
    final ts =
        data['lastMessageTimestamp'] ?? data['updatedAt'] ?? data['createdAt'];
    if (ts is Timestamp) updatedAtMs = ts.millisecondsSinceEpoch;
    if (updatedAtMs <= 0) {
      updatedAtMs =
          lastMessage?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch;
    }

    final previewHidden =
        clearedAtMs != null && clearedAtMs > 0 && updatedAtMs <= clearedAtMs;
    final preview = previewHidden
        ? 'Sin novedades recientes.'
        : _previewFromMessage(lastMessage, fallback: description);

    final subscribed = prefData['subscribed'] == true;
    final pinned = subscribed && prefData['pinned'] == true;

    return _NewsItem(
      id: docSnap.id,
      title: title,
      description: description,
      preview: preview,
      order: order,
      updatedAtMs: updatedAtMs,
      subscribed: subscribed,
      pinned: pinned,
    );
  }

  String _previewFromMessage(
    MessageModel? message, {
    required String fallback,
  }) {
    if (message == null) {
      return fallback.trim().isEmpty
          ? 'Sin novedades recientes.'
          : fallback.trim();
    }

    final text = message.text.trim();
    if (text.isEmpty) {
      return fallback.trim().isEmpty
          ? 'Sin novedades recientes.'
          : fallback.trim();
    }

    final lines = text.split('\n');
    final body = lines.length <= 1 ? text : lines.skip(1).join(' ').trim();
    final cleaned = body.isEmpty ? text : body;
    return cleaned;
  }

  Future<void> _setSubscription({
    required String uid,
    required _NewsItem item,
    required bool subscribed,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('communityGroupPrefs')
          .doc(item.id)
          .set({
            'subscribed': subscribed,
            'pinned': subscribed ? item.pinned : false,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      _snack('No se pudo actualizar la suscripción.');
    }
  }

  Future<void> _togglePinned({
    required String uid,
    required _NewsItem item,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('communityGroupPrefs')
          .doc(item.id)
          .set({
            'subscribed': true,
            'pinned': !item.pinned,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      _snack('No se pudo fijar la noticia.');
    }
  }

  Future<void> _openFirestoreGroup(_NewsItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityGroupChatScreen(
          groupId: item.id,
          initialTitle: item.title,
        ),
      ),
    );
  }

  Future<void> _openLocalNews(ChatModel chat) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen.community(chatId: chat.id)),
    );
    await _loadLocalIfNeeded();
  }

  List<_NewsItem> _sortItems(List<_NewsItem> items) {
    final sorted = items.toList();
    sorted.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      if (a.subscribed != b.subscribed) return a.subscribed ? -1 : 1;
      final orderCmp = a.order.compareTo(b.order);
      if (orderCmp != 0) return orderCmp;
      return b.updatedAtMs.compareTo(a.updatedAtMs);
    });
    return sorted;
  }

  Widget _hero() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF173255), Color(0xFF426C8E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: const Text(
              'Noticias y grupos',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sigue solo lo que te interesa y fija primero lo importante.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Las noticias suscritas se quedan arriba y los grupos fijados van primero para que la sección se adapte a ti.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    if (!firebaseReady || user == null) {
      if (_loadingLocal) {
        return const Center(child: CircularProgressIndicator());
      }

      return RefreshIndicator(
        onRefresh: _loadLocalIfNeeded,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _hero(),
            const SizedBox(height: 16),
            for (final chat in _localCommunities) ...[
              _LocalNewsCard(chat: chat, onTap: () => _openLocalNews(chat)),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('users')
          .doc(user.uid)
          .collection('communityGroupPrefs')
          .snapshots(),
      builder: (context, prefsSnap) {
        final prefsByGroupId = <String, Map<String, Object?>>{};
        final clearedByGroupId = <String, int>{};

        for (final doc in prefsSnap.data?.docs ?? const []) {
          final raw = doc.data();
          final prefMap = <String, Object?>{};
          raw.forEach((key, value) => prefMap[key] = value);
          prefsByGroupId[doc.id] = prefMap;

          int? ms;
          final clearedAt = raw['clearedAt'];
          if (clearedAt is Timestamp) ms = clearedAt.millisecondsSinceEpoch;
          final clearedAtMs = raw['clearedAtMs'];
          if (ms == null) {
            if (clearedAtMs is int) ms = clearedAtMs;
            if (clearedAtMs is num) ms = clearedAtMs.toInt();
          }
          if (ms != null && ms > 0) clearedByGroupId[doc.id] = ms;
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db
              .collection('communityGroups')
              .orderBy('order')
              .limit(200)
              .snapshots(),
          builder: (context, groupsSnap) {
            if (groupsSnap.hasError) {
              return const SafeArea(
                child: Center(
                  child: Text('No se pudieron cargar las noticias.'),
                ),
              );
            }
            if (!groupsSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = <_NewsItem>[];
            for (final docSnap in groupsSnap.data!.docs) {
              final item = _itemFromGroupDoc(
                myUid: user.uid,
                docSnap: docSnap,
                prefData:
                    prefsByGroupId[docSnap.id] ?? const <String, Object?>{},
                clearedAtMs: clearedByGroupId[docSnap.id],
              );
              if (item != null) items.add(item);
            }

            final sorted = _sortItems(items);
            final visible = _onlySubscribed
                ? sorted
                      .where((item) => item.subscribed)
                      .toList(growable: false)
                : sorted;
            final subscribedCount = items
                .where((item) => item.subscribed)
                .length;
            final pinnedCount = items.where((item) => item.pinned).length;

            return RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _hero(),
                  const SizedBox(height: 16),
                  ProgressSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tu panel',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _NewsMetric(
                                label: 'Suscritas',
                                value: '$subscribedCount',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _NewsMetric(
                                label: 'Fijadas',
                                value: '$pinnedCount',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Todas'),
                              selected: !_onlySubscribed,
                              onSelected: (_) {
                                setState(() => _onlySubscribed = false);
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Solo suscritas'),
                              selected: _onlySubscribed,
                              onSelected: (_) {
                                setState(() => _onlySubscribed = true);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    ProgressSectionCard(
                      child: Text(
                        _onlySubscribed
                            ? 'Todavía no te has suscrito a ninguna noticia.'
                            : 'Aún no hay noticias disponibles.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    for (final item in visible) ...[
                      _NewsCard(
                        item: item,
                        onOpen: () => _openFirestoreGroup(item),
                        onToggleSubscribe: () => _setSubscription(
                          uid: user.uid,
                          item: item,
                          subscribed: !item.subscribed,
                        ),
                        onTogglePinned: () =>
                            _togglePinned(uid: user.uid, item: item),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _NewsItem {
  const _NewsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.preview,
    required this.order,
    required this.updatedAtMs,
    required this.subscribed,
    required this.pinned,
  });

  final String id;
  final String title;
  final String description;
  final String preview;
  final int order;
  final int updatedAtMs;
  final bool subscribed;
  final bool pinned;
}

class _NewsMetric extends StatelessWidget {
  const _NewsMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cfSoftSurface,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: context.cfBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.cfTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.item,
    required this.onOpen,
    required this.onToggleSubscribe,
    required this.onTogglePinned,
  });

  final _NewsItem item;
  final VoidCallback onOpen;
  final VoidCallback onToggleSubscribe;
  final VoidCallback onTogglePinned;

  String _timeLabel(int ms) {
    if (ms <= 0) return 'Ahora';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _timeLabel(item.updatedAtMs),
                          style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: context.cfTextSecondary),
                        ),
                      ],
                    ),
                    if (item.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: item.pinned ? 'Quitar fijado' : 'Fijar primero',
                onPressed: onTogglePinned,
                icon: Icon(
                  item.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: item.pinned
                      ? CFColors.primary
                      : CFColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cfSoftSurface,
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              border: Border.all(color: context.cfBorder),
            ),
            child: Text(
              item.preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.35),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.subscribed)
                const _NewsPill(
                  label: 'Suscrita',
                  icon: Icons.notifications_active_outlined,
                )
              else
                const _NewsPill(
                  label: 'No suscrita',
                  icon: Icons.notifications_off_outlined,
                ),
              if (item.pinned)
                const _NewsPill(label: 'Fijada', icon: Icons.push_pin),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Abrir noticia'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onToggleSubscribe,
                icon: Icon(
                  item.subscribed
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_active_outlined,
                ),
                label: Text(
                  item.subscribed ? 'Dejar de seguir' : 'Suscribirme',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewsPill extends StatelessWidget {
  const _NewsPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.cfPrimaryTint,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: context.cfPrimaryTintStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.cfPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.cfPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalNewsCard extends StatelessWidget {
  const _LocalNewsCard({required this.chat, required this.onTap});

  final ChatModel chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lastText = chat.lastMessage?.text.trim();
    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chat.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            (lastText == null || lastText.isEmpty)
                ? 'Abre la noticia para ver novedades.'
                : lastText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.open_in_new_outlined),
            label: const Text('Abrir noticia'),
          ),
        ],
      ),
    );
  }
}
