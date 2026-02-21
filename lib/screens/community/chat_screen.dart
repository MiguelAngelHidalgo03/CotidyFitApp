import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/theme.dart';
import '../../models/chat_model.dart';
import '../../models/contact_model.dart';
import '../../models/message_model.dart';
import '../../models/user_profile.dart';
import '../../services/community_chat_local_service.dart';
import '../../services/chat_repository.dart';
import '../../services/chat_service.dart';
import '../../services/contacts_local_service.dart';
import '../../services/block_service.dart';
import '../../services/friend_service.dart';
import '../../services/private_chat_local_service.dart';
import '../../services/profile_service.dart';
import '../../services/social_firestore_service.dart';
import '../../services/mute_service.dart';
import 'public_profile_screen.dart';
import '../../widgets/community/message_bubble.dart';
import '../../widgets/progress/progress_section_card.dart';
import '../../utils/date_utils.dart';

enum ChatScope { privateChat, privateContact, community, dmFirestore }

class ChatScreen extends StatefulWidget {
  const ChatScreen._({required this.scope, this.chatId, this.contactId});

  factory ChatScreen.private({required String chatId}) {
    return ChatScreen._(scope: ChatScope.privateChat, chatId: chatId);
  }

  factory ChatScreen.privateContact({required String contactId}) {
    return ChatScreen._(scope: ChatScope.privateContact, contactId: contactId);
  }

  factory ChatScreen.community({required String chatId}) {
    return ChatScreen._(scope: ChatScope.community, chatId: chatId);
  }

  factory ChatScreen.dm({required String chatId}) {
    return ChatScreen._(scope: ChatScope.dmFirestore, chatId: chatId);
  }

  final ChatScope scope;
  final String? chatId;
  final String? contactId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatRepository _communityRepo = CommunityChatLocalService();
  final _privateRepo = PrivateChatLocalService();
  final _profileService = ProfileService();
  final _contacts = ContactsLocalService();
  final _social = SocialFirestoreService();
  final _blockService = BlockService();
  final _chatService = ChatService();
  final _friendService = FriendService();
  final _muteService = MuteService();

  final _dmScrollCtrl = ScrollController();
  final Map<String, GlobalKey> _dmMessageKeys = <String, GlobalKey>{};
  String? _highlightDmMessageId;
  List<MessageModel> _latestDmMessages = const <MessageModel>[];

  bool _dmSearchActive = false;
  final _dmSearchCtrl = TextEditingController();
  final _dmSearchFocus = FocusNode();
  String _dmSearchQuery = '';
  List<String> _dmSearchMatchIds = const <String>[];
  int _dmSearchMatchIndex = 0;

  final _textCtrl = TextEditingController();

  String? _dmPeerUid;
  String? _dmChatEnsuredId;
  bool _dmEnsuringChat = false;

  bool _dmDidResetUnreadOnOpen = false;

  String? _dmMissingChatCheckedId;
  Future<bool>? _dmMissingChatHasFriendshipFuture;

  bool _presencePinged = false;

  Future<void> _resetDmUnreadOnOpenOnce() async {
    if (_dmDidResetUnreadOnOpen) return;
    _dmDidResetUnreadOnOpen = true;

    if (widget.scope != ChatScope.dmFirestore) return;
    final chatId = (widget.chatId ?? '').trim();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (chatId.isEmpty || currentUser == null) return;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    try {
      await chatRef.update({
        'unreadCountByUser.${currentUser.uid}': 0,
      });
    } catch (_) {
      // Best-effort; don't break streams/UI.
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirmBlock({required String peerName}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bloquear usuario'),
          content: Text(
            '¿Bloquear a "$peerName"? No podrás escribirle ni recibir solicitudes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Bloquear'),
            ),
          ],
        );
      },
    );
    return res ?? false;
  }

  Future<bool> _confirmRemoveFriendStep1() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar amigo'),
          content: const Text('¿Seguro que quieres eliminar a este amigo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    return res ?? false;
  }

  Future<bool> _confirmRemoveFriendStep2DeleteConversation() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Borrar conversación'),
          content: const Text('¿Quieres borrar también la conversación?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );
    return res ?? false;
  }

  void _startDmSearch() {
    if (_dmSearchActive) {
      _dmSearchFocus.requestFocus();
      return;
    }

    setState(() {
      _dmSearchActive = true;
      _dmSearchCtrl.text = _dmSearchQuery;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dmSearchFocus.requestFocus();
      _updateDmSearch(_dmSearchCtrl.text);
    });
  }

  void _stopDmSearch() {
    setState(() {
      _dmSearchActive = false;
      _dmSearchQuery = '';
      _dmSearchMatchIds = const <String>[];
      _dmSearchMatchIndex = 0;
      _highlightDmMessageId = null;
    });
  }

  void _updateDmSearch(String raw) {
    final q = raw.trim();
    final qq = q.toLowerCase();
    if (qq.isEmpty) {
      setState(() {
        _dmSearchQuery = '';
        _dmSearchMatchIds = const <String>[];
        _dmSearchMatchIndex = 0;
      });
      return;
    }

    final ids = <String>[];
    for (final m in _latestDmMessages) {
      if (m.text.toLowerCase().contains(qq)) ids.add(m.id);
    }

    setState(() {
      _dmSearchQuery = q;
      _dmSearchMatchIds = ids;
      _dmSearchMatchIndex = 0;
    });
  }

  Future<void> _jumpDmMatch(int delta) async {
    if (_dmSearchMatchIds.isEmpty) {
      _snack('Sin resultados.');
      return;
    }

    final len = _dmSearchMatchIds.length;
    final next = (_dmSearchMatchIndex + delta) % len;
    final nextIndex = next < 0 ? next + len : next;

    setState(() => _dmSearchMatchIndex = nextIndex);

    final id = _dmSearchMatchIds[nextIndex];
    await _scrollToDmMessage(messages: _latestDmMessages, messageId: id);
  }

  String _dateChipLabel(DateTime day) {
    final now = DateTime.now();
    if (DateUtilsCF.isSameDay(day, now)) return 'Hoy';
    if (DateUtilsCF.isYesterdayOf(day, now)) return 'Ayer';
    final dd = day.day.toString().padLeft(2, '0');
    final mm = day.month.toString().padLeft(2, '0');
    return '$dd/$mm/${day.year}';
  }

  Future<void> _scrollToDmMessage({
    required List<MessageModel> messages,
    required String messageId,
  }) async {
    final id = messageId.trim();
    if (id.isEmpty) return;

    final idx = messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;

    setState(() => _highlightDmMessageId = id);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (!mounted) return;

    if (_dmScrollCtrl.hasClients && messages.length > 1) {
      final fraction = idx / (messages.length - 1);
      final target = _dmScrollCtrl.position.maxScrollExtent * fraction;
      _dmScrollCtrl.jumpTo(
        target.clamp(0.0, _dmScrollCtrl.position.maxScrollExtent),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _dmMessageKeys[id];
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
    if (_highlightDmMessageId == id) {
      setState(() => _highlightDmMessageId = null);
    }
  }

  String? _dmChatIdForStreams;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _dmChatDocStream;
  String? _peerUidForStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _peerPublicStream;
  Stream<List<MessageModel>>? _dmMessagesStream;

  ChatModel? _chat;
  ContactModel? _contact;
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.scope == ChatScope.dmFirestore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resetDmUnreadOnOpenOnce();
      });
    }
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _dmScrollCtrl.dispose();
    _dmSearchCtrl.dispose();
    _dmSearchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final profile = await _profileService.getOrCreateProfile();

    ChatModel? chat;
    ContactModel? contact;

    if (widget.scope == ChatScope.dmFirestore) {
      chat = null;
    } else if (widget.scope == ChatScope.community) {
      await _communityRepo.seedIfEmpty();
      chat = await _communityRepo.getChatById(widget.chatId!);
    } else if (widget.scope == ChatScope.privateChat) {
      chat = await _privateRepo.getChatById(widget.chatId!);
    } else {
      contact = await _contacts.getContactById(widget.contactId!);
      if (contact != null) {
        chat = await _privateRepo.getChatForContact(contact.id);
      }
    }

    if (!mounted) return;

    setState(() {
      _chat = chat;
      _contact = contact;
      _profile = profile;
      _loading = false;
    });

    if (chat != null) {
      if (widget.scope == ChatScope.community) {
        await _communityRepo.markChatRead(chat.id);
        chat = await _communityRepo.getChatById(chat.id);
      } else {
        await _privateRepo.markChatRead(chat.id);
        chat = await _privateRepo.getChatById(chat.id);
      }
      if (!mounted) return;
      setState(() => _chat = chat);
    }
  }

  bool get _isProfessionalLocked {
    final profile = _profile;
    final contact = _contact;
    if (profile == null) return false;

    if (widget.scope == ChatScope.privateContact && contact != null) {
      return contact.requiresPremium && !profile.isPremium;
    }

    if (widget.scope == ChatScope.privateChat) {
      final chat = _chat;
      if (chat == null) return false;
      return chat.type == ChatType.profesional && !profile.isPremium;
    }
    return false;
  }

  String _presenceLabel(int? lastActiveAtMs) {
    if (lastActiveAtMs == null) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(lastActiveAtMs);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes <= 2) return 'En línea';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Activo';
  }

  Future<void> _send(MessageType type, String text) async {
    if (text.trim().isEmpty) return;

    if (_isProfessionalLocked) return;

    final chat = _chat;

    if (widget.scope == ChatScope.dmFirestore) {
      final chatId = widget.chatId;
      if (chatId == null || chatId.trim().isEmpty) return;

      // Ensure chat doc exists before sending (prevents orphan message writes / rules failures).
      try {
        await _chatService.ensureDmChatFromFriendship(chatId: chatId);
      } catch (_) {
        // ignore
      }

      final peerUid = _dmPeerUid;
      if (peerUid != null && peerUid.trim().isNotEmpty) {
        final blocked = await _blockService.getBlockedUserIdsOnce();
        if (blocked.contains(peerUid)) {
          if (!mounted) return;
          _snack('Has bloqueado a este usuario.');
          return;
        }
      }

      await _social.sendMessage(chatId: chatId, type: type, text: text);
      _textCtrl.clear();
      return;
    }

    if (widget.scope == ChatScope.community) {
      if (chat == null) return;
      if (chat.readOnly) return;
      await _communityRepo.sendMessage(chatId: chat.id, type: type, text: text);
    } else if (widget.scope == ChatScope.privateChat) {
      if (chat == null) return;
      await _privateRepo.sendMessageToChat(
        chatId: chat.id,
        type: type,
        text: text,
      );
    } else {
      final contact = _contact;
      if (contact == null) return;
      await _privateRepo.sendMessageToContact(
        contact: contact,
        type: type,
        text: text,
      );
    }

    _textCtrl.clear();
    await _load();
  }

  Future<void> _openPlusMenu() async {
    final picked = await showModalBottomSheet<MessageType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.70;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ProgressSectionCard(
                padding: const EdgeInsets.all(6),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    _PlusItem(
                      icon: Icons.fitness_center_outlined,
                      title: 'Rutina',
                      subtitle: 'Comparte una rutina',
                      onTap: () =>
                          Navigator.of(context).pop(MessageType.routine),
                    ),
                    const Divider(height: 1),
                    _PlusItem(
                      icon: Icons.emoji_events_outlined,
                      title: 'Logro',
                      subtitle: 'Comparte un logro',
                      onTap: () =>
                          Navigator.of(context).pop(MessageType.achievement),
                    ),
                    const Divider(height: 1),
                    _PlusItem(
                      icon: Icons.today_outlined,
                      title: 'Resumen del día',
                      subtitle: 'Comparte tu día',
                      onTap: () =>
                          Navigator.of(context).pop(MessageType.daySummary),
                    ),
                    const Divider(height: 1),
                    _PlusItem(
                      icon: Icons.restaurant_outlined,
                      title: 'Dieta',
                      subtitle: 'Comparte tu dieta',
                      onTap: () => Navigator.of(context).pop(MessageType.diet),
                    ),
                    const Divider(height: 1),
                    _PlusItem(
                      icon: Icons.local_fire_department_outlined,
                      title: 'Rachas',
                      subtitle: 'Comparte tus rachas',
                      onTap: () =>
                          Navigator.of(context).pop(MessageType.streaks),
                    ),
                    const Divider(height: 1),
                    _PlusItem(
                      icon: Icons.chat_bubble_outline,
                      title: 'Mensaje normal',
                      subtitle: 'Escribir',
                      onTap: () => Navigator.of(context).pop(MessageType.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (picked == null) return;

    final payload = switch (picked) {
      MessageType.text => null,
      MessageType.routine => 'Full body 20 min · Casa',
      MessageType.achievement => 'Racha 7 días · CF +20',
      MessageType.daySummary => 'CF 78 · Entreno completado · Agua 2L',
      MessageType.diet => 'Hoy: proteína alta · 2L agua · sin ultraprocesados',
      MessageType.streaks => 'Racha actual: 3 días · Racha máx: 7 días',
    };

    if (picked == MessageType.text) {
      if (mounted) FocusScope.of(context).requestFocus();
      return;
    }

    await _send(picked, payload ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final firebaseReady = Firebase.apps.isNotEmpty;
    final currentUser = firebaseReady
        ? FirebaseAuth.instance.currentUser
        : null;

    if (widget.scope == ChatScope.dmFirestore &&
        firebaseReady &&
        currentUser != null) {
      // Best-effort presence ping (once).
      if (!_presencePinged) {
        _presencePinged = true;
        _social.pingPresence();
      }

      final chatId = widget.chatId!;
      final myUid = currentUser.uid;

      if (_dmChatIdForStreams != chatId ||
          _dmChatDocStream == null ||
          _dmMessagesStream == null) {
        _dmChatIdForStreams = chatId;
        _dmChatDocStream = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .snapshots();
        _dmMessagesStream = _social.watchMessages(chatId: chatId);
        _peerUidForStream = null;
        _peerPublicStream = null;
      }

      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _dmChatDocStream,
        builder: (context, chatSnap) {
          if (chatSnap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: SafeArea(child: Center(child: CircularProgressIndicator())),
            );
          }

          if (chatSnap.hasError) {
            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ProgressSectionCard(
                    child: Text(
                      'No se pudo cargar el chat.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            );
          }

          // If the chat doc was deleted (block/delete conversation), recreate it only if friendship exists.
          final chatDoc = chatSnap.data;
          if (chatDoc == null || chatDoc.exists == false) {
            if (_dmMissingChatCheckedId != chatId ||
                _dmMissingChatHasFriendshipFuture == null) {
              _dmMissingChatCheckedId = chatId;
              _dmMissingChatHasFriendshipFuture = FirebaseFirestore.instance
                  .collection('friendships')
                  .doc(chatId)
                  .get()
                  .then((s) => s.exists)
                  .catchError((_) => false);
            }

            return FutureBuilder<bool>(
              future: _dmMissingChatHasFriendshipFuture,
              builder: (context, f) {
                if (f.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: SafeArea(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final hasFriendship = f.data ?? false;
                if (!hasFriendship) {
                  return Scaffold(
                    body: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: ProgressSectionCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Este chat ya no está disponible.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                child: const Text('Volver'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (_dmChatEnsuredId != chatId && !_dmEnsuringChat) {
                  _dmEnsuringChat = true;
                  _dmChatEnsuredId = chatId;
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    try {
                      await _chatService.ensureDmChatFromFriendship(
                        chatId: chatId,
                      );
                    } finally {
                      _dmEnsuringChat = false;
                    }
                  });
                }

                return const Scaffold(
                  body: SafeArea(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              },
            );
          }

          final data = chatDoc.data();
          final membersRaw = data?['members'];
          final members = membersRaw is List
              ? membersRaw.map((e) => e.toString()).toList()
              : const <String>[];
          final peerUid = members.firstWhere(
            (m) => m != myUid,
            orElse: () => '',
          );
          _dmPeerUid = peerUid.isEmpty ? null : peerUid;

          final namesRaw = data?['names'];
          final names = namesRaw is Map
              ? namesRaw.map((k, v) => MapEntry(k.toString(), v))
              : const <String, Object?>{};
          final peerName = (names[peerUid] as String?)?.trim() ?? 'Chat';

          if (peerUid.isNotEmpty &&
              (_peerUidForStream != peerUid || _peerPublicStream == null)) {
            _peerUidForStream = peerUid;
            _peerPublicStream = FirebaseFirestore.instance
                .collection('user_public')
                .doc(peerUid)
                .snapshots();
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: peerUid.isEmpty ? const Stream.empty() : _peerPublicStream,
            builder: (context, publicSnap) {
              if (publicSnap.hasError) {
                // Presence is best-effort; don't fail the whole screen.
              }
              final publicData = publicSnap.data?.data();
              final lastActive = publicData?['lastActiveAt'];
              final lastActiveMs = lastActive is Timestamp
                  ? lastActive.millisecondsSinceEpoch
                  : null;

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('friendships')
                    .doc(chatId)
                    .snapshots(),
                builder: (context, friendshipSnap) {
                  final isFriend = friendshipSnap.data?.exists ?? false;

                  return Scaffold(
                    appBar: AppBar(
                      centerTitle: true,
                      title: _dmSearchActive
                          ? SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _dmSearchCtrl,
                                focusNode: _dmSearchFocus,
                                textInputAction: TextInputAction.search,
                                onChanged: _updateDmSearch,
                                onSubmitted: (_) => _jumpDmMatch(1),
                                decoration: const InputDecoration(
                                  hintText: 'Buscar…',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                            )
                          : InkWell(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                              onTap: peerUid.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PublicProfileScreen(uid: peerUid),
                                        ),
                                      );
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      peerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _presenceLabel(lastActiveMs),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: CFColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      actions: [
                        if (_dmSearchActive) ...[
                          IconButton(
                            tooltip: 'Anterior',
                            onPressed: () => _jumpDmMatch(-1),
                            icon: const Icon(Icons.keyboard_arrow_up),
                          ),
                          IconButton(
                            tooltip: 'Siguiente',
                            onPressed: () => _jumpDmMatch(1),
                            icon: const Icon(Icons.keyboard_arrow_down),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                _dmSearchMatchIds.isEmpty
                                    ? '0/0'
                                    : '${_dmSearchMatchIndex + 1}/${_dmSearchMatchIds.length}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: CFColors.textSecondary),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar búsqueda',
                            onPressed: _stopDmSearch,
                            icon: const Icon(Icons.close),
                          ),
                        ] else
                          Builder(
                            builder: (context) {
                              final muteUntil =
                                  MuteService.muteUntilFromChatData(
                                    data: data,
                                    uid: myUid,
                                  );
                              final muted = MuteService.isMuted(muteUntil);

                              Future<void> openMuteSheet() async {
                                final picked =
                                    await showModalBottomSheet<_MutePick>(
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
                                                    onTap: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(
                                                          _MutePick(
                                                            days: 1,
                                                            label: '1 día',
                                                          ),
                                                        ),
                                                  ),
                                                  const Divider(height: 1),
                                                  ListTile(
                                                    title: const Text(
                                                      '1 semana',
                                                    ),
                                                    onTap: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(
                                                          _MutePick(
                                                            days: 7,
                                                            label: '1 semana',
                                                          ),
                                                        ),
                                                  ),
                                                  const Divider(height: 1),
                                                  ListTile(
                                                    title: const Text(
                                                      'Siempre',
                                                    ),
                                                    onTap: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(
                                                          _MutePick(
                                                            always: true,
                                                            label: 'Siempre',
                                                          ),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );

                                if (picked == null) return;

                                final until = picked.always
                                    ? DateTime.now().add(
                                        const Duration(days: 3650),
                                      )
                                    : DateTime.now().add(
                                        Duration(days: picked.days),
                                      );

                                await _muteService.setMuteUntil(
                                  chatId: chatId,
                                  until: until,
                                );
                                if (!mounted) return;
                                _snack(
                                  'Notificaciones silenciadas durante ${picked.label}',
                                );
                              }

                              return PopupMenuButton<String>(
                                onSelected: (value) async {
                                  final navigator = Navigator.of(context);
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  void snack(String msg) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  }

                                  if (value == 'search') {
                                    _startDmSearch();
                                    return;
                                  }

                                  if (value == 'mute') {
                                    await openMuteSheet();
                                    return;
                                  }

                                  if (value == 'unmute') {
                                    await _muteService.setMuteUntil(
                                      chatId: chatId,
                                      until: null,
                                    );
                                    if (!mounted) return;
                                    snack('Notificaciones activadas');
                                    return;
                                  }

                                  if (value == 'view') {
                                    if (peerUid.isEmpty) return;
                                    navigator.push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PublicProfileScreen(uid: peerUid),
                                      ),
                                    );
                                    return;
                                  }

                                  if (value == 'delete_conversation') {
                                    try {
                                      // WhatsApp-style (local): hide only for me and leave the chat list immediately.
                                      await _social.hideChatForMe(
                                        chatId: chatId,
                                      );
                                      if (!mounted) return;
                                      _stopDmSearch();
                                      _textCtrl.clear();
                                      navigator.pop('go_chats_tab');
                                    } catch (e) {
                                      if (!mounted) return;
                                      snack(
                                        'No se pudo borrar la conversación',
                                      );
                                    }
                                    return;
                                  }

                                  if (peerUid.isEmpty) return;

                                  if (value == 'remove_friend') {
                                    final ok =
                                        await _confirmRemoveFriendStep1();
                                    if (!ok) return;
                                    final deleteConversation =
                                        await _confirmRemoveFriendStep2DeleteConversation();
                                    try {
                                      await _friendService.removeFriend(
                                        myUid: myUid,
                                        friendUid: peerUid,
                                        deleteConversation: deleteConversation,
                                      );
                                      if (!mounted) return;
                                      _stopDmSearch();
                                      _textCtrl.clear();
                                      navigator.pop('go_chats_tab');
                                    } catch (_) {
                                      if (!mounted) return;
                                      snack('No se pudo eliminar al amigo');
                                    }
                                    return;
                                  }

                                  if (value == 'block') {
                                    final ok = await _confirmBlock(
                                      peerName: peerName,
                                    );
                                    if (!ok) return;
                                    try {
                                      await _blockService.blockUser(
                                        blockedUid: peerUid,
                                      );
                                      if (!mounted) return;
                                      snack('Usuario bloqueado correctamente');
                                      navigator.maybePop();
                                    } catch (_) {
                                      if (!mounted) return;
                                      snack('No se pudo bloquear');
                                    }
                                  }

                                  if (value == 'report') {
                                    snack(
                                      'Esta función estará disponible próximamente.',
                                    );
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
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Text('Ver contacto'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete_conversation',
                                    child: Text('Borrar conversación'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove_friend',
                                    child: Text('Eliminar amigo'),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'block',
                                    child: Text('Bloquear'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'report',
                                    child: Text('Reportar'),
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                    body: SafeArea(
                      child: Column(
                        children: [
                          if (!isFriend)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
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
                                        'Chat solo lectura',
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
                            child: StreamBuilder<List<MessageModel>>(
                              stream: _dmMessagesStream,
                              builder: (context, snap) {
                                if (snap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (snap.hasError) {
                                  return Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: ProgressSectionCard(
                                      child: Text(
                                        'No se pudieron cargar los mensajes.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ),
                                  );
                                }
                                final messages =
                                    snap.data ?? const <MessageModel>[];
                                _latestDmMessages = messages;
                                if (messages.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            size: 28,
                                            color: CFColors.textSecondary,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Aún no hay mensajes.',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: CFColors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                                  controller: _dmScrollCtrl,
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final m = messages[index];
                                    final dt =
                                        DateTime.fromMillisecondsSinceEpoch(
                                          m.createdAtMs,
                                        );
                                    final day = DateUtilsCF.dateOnly(dt);
                                    // reverse: true + messages are newest-first.
                                    // Show the separator for the first message of a day in *visual order*
                                    // (i.e., compare with the next/older message at index + 1).
                                    final showHeader =
                                        index == messages.length - 1 ||
                                        !DateUtilsCF.isSameDay(
                                          day,
                                          DateUtilsCF.dateOnly(
                                            DateTime.fromMillisecondsSinceEpoch(
                                              messages[index + 1].createdAtMs,
                                            ),
                                          ),
                                        );

                                    final key = _dmMessageKeys.putIfAbsent(
                                      m.id,
                                      () => GlobalKey(),
                                    );
                                    final highlighted =
                                        _highlightDmMessageId == m.id;

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
                                          if (showHeader) ...[
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
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  _dateChipLabel(day),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
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
                              child: _Composer(
                                enabled: isFriend,
                                controller: _textCtrl,
                                onPlus: _openPlusMenu,
                                onSend: () =>
                                    _send(MessageType.text, _textCtrl.text),
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

    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final chat = _chat;
    final contact = _contact;

    final title = chat?.title ?? contact?.name ?? 'Chat';
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (chat != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: Text(
                  chat.type.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: CFColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isProfessionalLocked
            ? _PremiumLockedChat(title: title)
            : Column(
                children: [
                  if (chat != null && chat.readOnly)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
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
                                'Chat solo lectura',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      reverse: true,
                      itemCount: chat?.messages.length ?? 0,
                      itemBuilder: (context, index) {
                        final messages =
                            chat?.messages ?? const <MessageModel>[];
                        final m = messages[messages.length - 1 - index];
                        final dt = DateTime.fromMillisecondsSinceEpoch(
                          m.createdAtMs,
                        );
                        final day = DateUtilsCF.dateOnly(dt);

                        bool showHeader() {
                          // reverse: true (newest at bottom). Show separator when the day changes
                          // compared to the next/older message in visual order.
                          if (index == messages.length - 1) return true;
                          final next =
                              messages[messages.length - 1 - (index + 1)];
                          final nextDay = DateUtilsCF.dateOnly(
                            DateTime.fromMillisecondsSinceEpoch(
                              next.createdAtMs,
                            ),
                          );
                          return !DateUtilsCF.isSameDay(day, nextDay);
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showHeader()) ...[
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CFColors.softGray,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _dateChipLabel(day),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            MessageBubble(message: m),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _isProfessionalLocked
          ? null
          : SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: viewInsetsBottom),
                child: _Composer(
                  enabled: chat == null ? true : !chat.readOnly,
                  controller: _textCtrl,
                  onPlus: _openPlusMenu,
                  onSend: () => _send(MessageType.text, _textCtrl.text),
                ),
              ),
            ),
    );
  }
}

class _MutePick {
  final int days;
  final bool always;
  final String label;

  const _MutePick({this.days = 0, this.always = false, required this.label});
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.enabled,
    required this.controller,
    required this.onPlus,
    required this.onSend,
  });

  final bool enabled;
  final TextEditingController controller;
  final VoidCallback onPlus;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: CFColors.background,
        border: Border(
          top: BorderSide(color: CFColors.softGray.withValues(alpha: 0.9)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Más',
            onPressed: enabled ? onPlus : null,
            icon: const Icon(Icons.add_circle_outline, color: CFColors.primary),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => enabled ? onSend() : null,
              decoration: InputDecoration(
                hintText: enabled ? 'Escribe un mensaje…' : 'Solo lectura',
                filled: true,
                fillColor: CFColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  borderSide: BorderSide(color: CFColors.softGray),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                  borderSide: BorderSide(color: CFColors.softGray),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Enviar',
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send, color: CFColors.primary),
          ),
        ],
      ),
    );
  }
}

class _PlusItem extends StatelessWidget {
  const _PlusItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: CFColors.primary.withValues(alpha: 0.10),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: CFColors.softGray),
        ),
        child: Icon(icon, color: CFColors.primary),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _PremiumLockedChat extends StatelessWidget {
  const _PremiumLockedChat({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ProgressSectionCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: CFColors.primary.withValues(alpha: 0.10),
                      borderRadius: const BorderRadius.all(Radius.circular(18)),
                      border: Border.all(color: CFColors.softGray),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      color: CFColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chat profesional',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Este chat con $title está bloqueado. Activa Premium para hablar con profesionales.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Premium: próximamente')),
                    );
                  },
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Desbloquear Premium'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
