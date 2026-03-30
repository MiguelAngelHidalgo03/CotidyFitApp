import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/message_model.dart';
import '../../services/community_group_mute_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/community/message_bubble.dart';
import '../../widgets/progress/progress_section_card.dart';

class CommunityGroupChatScreen extends StatefulWidget {
  const CommunityGroupChatScreen({
    super.key,
    required this.groupId,
    this.initialTitle,
  });

  final String groupId;
  final String? initialTitle;

  @override
  State<CommunityGroupChatScreen> createState() =>
      _CommunityGroupChatScreenState();
}

class _CommunityGroupChatScreenState extends State<CommunityGroupChatScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CommunityGroupMuteService _muteService = CommunityGroupMuteService();

  final TextEditingController _textCtrl = TextEditingController();

  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _searchActive = false;
  String _searchQuery = '';
  List<String> _searchMatchIds = const <String>[];
  int _searchMatchIndex = 0;
  String? _highlightMessageId;

  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  List<MessageModel> _latestMessages = const <MessageModel>[];

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _startSearch() {
    if (_searchActive) {
      _searchFocus.requestFocus();
      return;
    }

    setState(() {
      _searchActive = true;
      _searchCtrl.text = _searchQuery;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
      _updateSearch(_searchCtrl.text);
    });
  }

  void _stopSearch() {
    setState(() {
      _searchActive = false;
      _searchQuery = '';
      _searchMatchIds = const <String>[];
      _searchMatchIndex = 0;
      _highlightMessageId = null;
    });
  }

  void _updateSearch(String raw) {
    final q = raw.trim();
    final qq = q.toLowerCase();
    if (qq.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchMatchIds = const <String>[];
        _searchMatchIndex = 0;
      });
      return;
    }

    final ids = <String>[];
    for (final m in _latestMessages) {
      if (m.text.toLowerCase().contains(qq)) ids.add(m.id);
    }

    setState(() {
      _searchQuery = q;
      _searchMatchIds = ids;
      _searchMatchIndex = 0;
    });
  }

  Future<void> _jumpMatch(int delta) async {
    if (_searchMatchIds.isEmpty) {
      _snack('Sin resultados.');
      return;
    }

    final len = _searchMatchIds.length;
    final next = (_searchMatchIndex + delta) % len;
    final nextIndex = next < 0 ? next + len : next;

    setState(() => _searchMatchIndex = nextIndex);

    final id = _searchMatchIds[nextIndex];
    await _scrollToMessage(messages: _latestMessages, messageId: id);
  }

  Future<void> _scrollToMessage({
    required List<MessageModel> messages,
    required String messageId,
  }) async {
    final id = messageId.trim();
    if (id.isEmpty) return;

    final idx = messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;

    setState(() => _highlightMessageId = id);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (!mounted) return;

    if (_scrollCtrl.hasClients && messages.length > 1) {
      final fraction = idx / (messages.length - 1);
      final target = _scrollCtrl.position.maxScrollExtent * fraction;
      _scrollCtrl.jumpTo(
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _messageKeys[id];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 0.25,
        );
      }
    });

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    if (_highlightMessageId == id) {
      setState(() => _highlightMessageId = null);
    }
  }

  String _dateChipLabel(DateTime day) {
    final now = DateTime.now();
    if (DateUtilsCF.isSameDay(day, now)) return 'Hoy';
    if (DateUtilsCF.isYesterdayOf(day, now)) return 'Ayer';
    final dd = day.day.toString().padLeft(2, '0');
    final mm = day.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _watchGroup() {
    return _db.collection('communityGroups').doc(widget.groupId).snapshots();
  }

  Stream<bool> _watchCanPost(String uid) {
    return _db
        .collection('communityGroups')
        .doc(widget.groupId)
        .collection('members')
        .doc(uid)
        .snapshots()
        .map((snap) {
          final status = (snap.data()?['status'] as String?)?.trim() ?? '';
          return status == 'approved';
        });
  }

  Stream<DateTime?> _watchMuteUntil(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('mutedCommunityGroups')
        .doc(widget.groupId)
        .snapshots()
        .map(
          (snap) => CommunityGroupMuteService.muteUntilFromDocData(snap.data()),
        );
  }

  Stream<DateTime?> _watchClearedAt(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('communityGroupPrefs')
        .doc(widget.groupId)
        .snapshots()
        .map((snap) {
          final data = snap.data();
          final ts = data?['clearedAt'];
          if (ts is Timestamp) return ts.toDate();
          final ms = data?['clearedAtMs'];
          if (ms is int) {
            return DateTime.fromMillisecondsSinceEpoch(ms);
          }
          return null;
        });
  }

  Future<void> _clearConversation({required String uid}) async {
    final groupId = widget.groupId.trim();
    if (groupId.isEmpty) return;

    _stopSearch();
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('communityGroupPrefs')
          .doc(groupId)
          .set({
            'clearedAt': FieldValue.serverTimestamp(),
            'clearedAtMs': DateTime.now().millisecondsSinceEpoch,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      _snack('Conversación borrada.');
    } catch (_) {
      _snack('No se pudo borrar la conversación.');
    }
  }

  Future<void> _leaveGroup({required String uid}) async {
    final groupId = widget.groupId.trim();
    if (groupId.isEmpty) return;

    _stopSearch();
    try {
      await _db
          .collection('communityGroups')
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .delete();
      if (!mounted) return;
      _snack('Has salido del grupo.');
      Navigator.of(context).pop();
    } catch (_) {
      _snack('No se pudo salir del grupo.');
    }
  }

  Stream<List<MessageModel>> _watchMessages(String uid) {
    return _db
        .collection('communityGroups')
        .doc(widget.groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(120)
        .snapshots()
        .map((qs) {
          final out = <MessageModel>[];
          for (final doc in qs.docs) {
            final data = doc.data();
            final senderUid = (data['senderUid'] as String?)?.trim() ?? '';
            final senderName =
                (data['senderName'] as String?)?.trim() ?? 'Usuario';
            final text = (data['text'] as String?) ?? '';
            final typeRaw = (data['type'] as String?)?.trim();
            final shareRaw = data['share'];

            Map<String, Object?>? share;
            if (shareRaw is Map) {
              share = shareRaw.map((k, v) => MapEntry(k.toString(), v));
            }

            MessageType type = MessageType.text;
            for (final v in MessageType.values) {
              if (v.name == typeRaw) {
                type = v;
                break;
              }
            }

            final createdAt = data['createdAt'];
            final createdAtMs = createdAt is Timestamp
                ? createdAt.millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch;

            out.add(
              MessageModel(
                id: doc.id,
                chatId: widget.groupId,
                senderId: senderUid,
                senderName: senderName,
                isMine: senderUid == uid,
                type: type,
                text: text,
                share: share,
                createdAtMs: createdAtMs,
              ),
            );
          }
          return out;
        });
  }

  Future<void> _sendText({required String uid}) async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final senderName = (user.displayName ?? '').trim().isEmpty
        ? ((user.email ?? '').split('@').first)
        : (user.displayName ?? '');

    _textCtrl.clear();

    final msgRef = _db
        .collection('communityGroups')
        .doc(widget.groupId)
        .collection('messages')
        .doc();

    try {
      await msgRef.set({
        'senderUid': uid,
        'senderName': senderName.trim().isEmpty ? 'Usuario' : senderName.trim(),
        'type': MessageType.text.name,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      _snack('No tienes permisos para escribir en esta comunidad.');
    }
  }

  Future<_MutePick?> _openMuteSheet() async {
    return showModalBottomSheet<_MutePick>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ProgressSectionCard(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('1 día'),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(const _MutePick(days: 1, label: '1 día')),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('1 semana'),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(const _MutePick(days: 7, label: '1 semana')),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Siempre'),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(const _MutePick(always: true, label: 'Siempre')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final groupId = widget.groupId.trim();

    if (user == null || groupId.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('Inicia sesión para ver la comunidad.')),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _watchGroup(),
      builder: (context, groupSnap) {
        final groupData = groupSnap.data?.data();
        final title =
            (groupData?['title'] as String?)?.trim().isNotEmpty == true
            ? (groupData?['title'] as String).trim()
            : (widget.initialTitle?.trim().isNotEmpty == true
                  ? widget.initialTitle!.trim()
                  : 'Comunidad');
        final introMessage =
            (groupData?['introMessage'] as String?)?.trim().isNotEmpty == true
            ? (groupData?['introMessage'] as String).trim()
            : ((groupData?['description'] as String?)?.trim() ?? '');

        return StreamBuilder<bool>(
          stream: _watchCanPost(user.uid),
          builder: (context, canPostSnap) {
            final canPost = canPostSnap.data ?? false;

            return StreamBuilder<DateTime?>(
              stream: _watchMuteUntil(user.uid),
              builder: (context, muteSnap) {
                final muteUntil = muteSnap.data;
                final muted = CommunityGroupMuteService.isMuted(muteUntil);

                return Scaffold(
                  appBar: AppBar(
                    title: _searchActive
                        ? SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              textInputAction: TextInputAction.search,
                              onChanged: _updateSearch,
                              onSubmitted: (_) => _jumpMatch(1),
                              decoration: const InputDecoration(
                                hintText: 'Buscar…',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          )
                        : Text(title),
                    actions: [
                      if (_searchActive) ...[
                        IconButton(
                          tooltip: 'Anterior',
                          onPressed: () => _jumpMatch(-1),
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                        IconButton(
                          tooltip: 'Siguiente',
                          onPressed: () => _jumpMatch(1),
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              _searchMatchIds.isEmpty
                                  ? '0/0'
                                  : '${_searchMatchIndex + 1}/${_searchMatchIds.length}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: CFColors.textSecondary),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar búsqueda',
                          onPressed: _stopSearch,
                          icon: const Icon(Icons.close),
                        ),
                      ] else
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'search') {
                              _startSearch();
                              return;
                            }

                            if (value == 'mute') {
                              final picked = await _openMuteSheet();
                              if (picked == null) return;

                              final until = picked.always
                                  ? DateTime.now().add(
                                      const Duration(days: 3650),
                                    )
                                  : DateTime.now().add(
                                      Duration(days: picked.days),
                                    );

                              await _muteService.setMuteUntil(
                                groupId: groupId,
                                until: until,
                              );
                              if (!mounted) return;
                              _snack(
                                'Notificaciones silenciadas durante ${picked.label}',
                              );
                              return;
                            }

                            if (value == 'unmute') {
                              await _muteService.setMuteUntil(
                                groupId: groupId,
                                until: null,
                              );
                              if (!mounted) return;
                              _snack('Notificaciones activadas');
                              return;
                            }

                            if (value == 'view') {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CommunityGroupInfoScreen(
                                    groupId: groupId,
                                    initialTitle: title,
                                  ),
                                ),
                              );
                              return;
                            }

                            if (value == 'clear') {
                              await _clearConversation(uid: user.uid);
                              return;
                            }

                            if (value == 'leave') {
                              await _leaveGroup(uid: user.uid);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'search',
                              child: Text('Buscar en el chat'),
                            ),
                            PopupMenuItem(
                              value: muted ? 'unmute' : 'mute',
                              child: Text(
                                muted
                                    ? 'Activar notificaciones'
                                    : 'Silenciar notificaciones',
                              ),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'view',
                              child: Text('Ver grupo'),
                            ),
                            const PopupMenuItem(
                              value: 'clear',
                              child: Text('Borrar conversación'),
                            ),
                            const PopupMenuItem(
                              value: 'leave',
                              child: Text('Salir del grupo'),
                            ),
                          ],
                        ),
                    ],
                  ),
                  body: SafeArea(
                    child: Column(
                      children: [
                        if (!canPost)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: ProgressSectionCard(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lock_outline,
                                    color: CFColors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Solo usuarios admitidos pueden escribir.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Expanded(
                          child: StreamBuilder<DateTime?>(
                            stream: _watchClearedAt(user.uid),
                            builder: (context, clearedSnap) {
                              final clearedAt = clearedSnap.data;
                              final clearedAtMs =
                                  clearedAt?.millisecondsSinceEpoch;

                              return StreamBuilder<List<MessageModel>>(
                                stream: _watchMessages(user.uid),
                                builder: (context, snap) {
                                  if (snap.hasError) {
                                    return const Center(
                                      child: Text(
                                        'No se pudieron cargar mensajes.',
                                      ),
                                    );
                                  }
                                  if (!snap.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  var messages =
                                      snap.data ?? const <MessageModel>[];
                                  if (clearedAtMs != null) {
                                    messages = messages
                                        .where(
                                          (m) => m.createdAtMs >= clearedAtMs,
                                        )
                                        .toList(growable: false);
                                  }
                                  _latestMessages = messages;

                                  if (messages.isEmpty &&
                                      introMessage.trim().isNotEmpty) {
                                    return ListView(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        14,
                                        16,
                                        14,
                                      ),
                                      children: [
                                        _CommunityIntroCard(
                                          title: title,
                                          message: introMessage,
                                        ),
                                      ],
                                    );
                                  }

                                  return ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      14,
                                    ),
                                    reverse: true,
                                    controller: _scrollCtrl,
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final m = messages[index];
                                      final dt =
                                          DateTime.fromMillisecondsSinceEpoch(
                                            m.createdAtMs,
                                          );
                                      final day = DateUtilsCF.dateOnly(dt);

                                      bool showHeader() {
                                        if (index == messages.length - 1) {
                                          return true;
                                        }
                                        final next = messages[index + 1];
                                        final nextDay = DateUtilsCF.dateOnly(
                                          DateTime.fromMillisecondsSinceEpoch(
                                            next.createdAtMs,
                                          ),
                                        );
                                        return !DateUtilsCF.isSameDay(
                                          day,
                                          nextDay,
                                        );
                                      }

                                      final key = _messageKeys.putIfAbsent(
                                        m.id,
                                        () => GlobalKey(),
                                      );
                                      final highlighted =
                                          _highlightMessageId == m.id;

                                      return Container(
                                        key: key,
                                        decoration: highlighted
                                            ? BoxDecoration(
                                                borderRadius:
                                                    const BorderRadius.all(
                                                      Radius.circular(14),
                                                    ),
                                                color: CFColors.primary
                                                    .withValues(alpha: 0.05),
                                                border: Border.all(
                                                  color: CFColors.primary
                                                      .withValues(alpha: 0.55),
                                                  width: 1.2,
                                                ),
                                              )
                                            : null,
                                        padding: highlighted
                                            ? const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6,
                                              )
                                            : EdgeInsets.zero,
                                        margin: highlighted
                                            ? const EdgeInsets.symmetric(
                                                vertical: 6,
                                              )
                                            : EdgeInsets.zero,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (showHeader()) ...[
                                              Center(
                                                child: Container(
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                      ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: CFColors.softGray,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    _dateChipLabel(day),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            MessageBubble(
                                              message: m,
                                              showAvatar: true,
                                              avatarKeySeed: m.senderId,
                                              avatarLabel: m.senderName,
                                              showTimestamp: true,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: AnimatedPadding(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.viewInsetsOf(context).bottom,
                            ),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                12,
                              ),
                              decoration: BoxDecoration(
                                color: context.cfBackground,
                                border: Border(
                                  top: BorderSide(
                                    color: context.cfBorder.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _textCtrl,
                                      enabled: canPost,
                                      minLines: 1,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: context.cfTextPrimary,
                                      ),
                                      cursorColor: context.cfPrimary,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => canPost
                                          ? _sendText(uid: user.uid)
                                          : null,
                                      decoration: InputDecoration(
                                        hintText: canPost
                                            ? 'Escribe un mensaje…'
                                            : 'Solo lectura',
                                        filled: true,
                                        fillColor: context.cfSurface,
                                        hintStyle: TextStyle(
                                          color: context.cfTextSecondary,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(18),
                                          ),
                                          borderSide: BorderSide(
                                            color: context.cfBorder,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(18),
                                          ),
                                          borderSide: BorderSide(
                                            color: context.cfBorder,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(18),
                                          ),
                                          borderSide: BorderSide(
                                            color: context.cfPrimary,
                                          ),
                                        ),
                                        disabledBorder: OutlineInputBorder(
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(18),
                                          ),
                                          borderSide: BorderSide(
                                            color: context.cfBorder,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Enviar',
                                    onPressed: canPost
                                        ? () => _sendText(uid: user.uid)
                                        : null,
                                    icon: const Icon(
                                      Icons.send,
                                      color: CFColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MutePick {
  final int days;
  final bool always;
  final String label;

  const _MutePick({this.days = 0, this.always = false, required this.label});
}

class CommunityGroupInfoScreen extends StatelessWidget {
  const CommunityGroupInfoScreen({
    super.key,
    required this.groupId,
    this.initialTitle,
  });

  final String groupId;
  final String? initialTitle;

  @override
  Widget build(BuildContext context) {
    final gid = groupId.trim();
    if (gid.isEmpty) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text('Grupo inválido.'))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ver grupo')),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('communityGroups')
              .doc(gid)
              .snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();
            final title = (data?['title'] as String?)?.trim().isNotEmpty == true
                ? (data?['title'] as String).trim()
                : (initialTitle?.trim().isNotEmpty == true
                      ? initialTitle!.trim()
                      : gid);
            final description = (data?['description'] as String?)?.trim() ?? '';
            final introMessage =
                (data?['introMessage'] as String?)?.trim() ?? '';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ProgressSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description.isEmpty ? 'Sin descripción.' : description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: CFColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (introMessage.isNotEmpty) ...[
                  _CommunityIntroCard(title: title, message: introMessage),
                  const SizedBox(height: 12),
                ],
                ProgressSectionCard(
                  child: Text(
                    'Solo usuarios admitidos pueden escribir.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CommunityIntroCard extends StatelessWidget {
  const _CommunityIntroCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: context.cfPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Antes de empezar en $title',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CFColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
