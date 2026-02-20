import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/theme.dart';
import '../../../models/contact_model.dart';
import '../../../models/user_profile.dart';
import '../../../services/contacts_local_service.dart';
import '../../../services/block_service.dart';
import '../../../services/friend_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/social_firestore_service.dart';
import '../../../widgets/community/community_avatar.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../chat_screen.dart';

class CommunityContactsTab extends StatefulWidget {
  const CommunityContactsTab({super.key});

  @override
  State<CommunityContactsTab> createState() => _CommunityContactsTabState();
}

class _CommunityContactsTabState extends State<CommunityContactsTab>
    with AutomaticKeepAliveClientMixin {
  final _contacts = ContactsLocalService();
  final _profileService = ProfileService();
  final _social = SocialFirestoreService();
  final _friends = FriendService();
  final _blockService = BlockService();

  String? _socialUid;
  Stream<List<FriendRequestModel>>? _pendingReqsStream;
  Stream<List<PublicUser>>? _friendsStream;

  final _searchCtrl = TextEditingController();
  bool _busy = false;

  PublicUser? _searchResult;
  String? _searchResultUid;
  String? _searchError;
  String? _searchExactMatch;

  UserProfile? _profile;
  List<ContactModel> _all = const [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();

    _searchCtrl.addListener(_onSearchTextChanged);

    if (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
      _social.pingPresence();
    }
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchTextChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetSearchResult({bool clearError = true}) {
    if (!mounted) return;
    setState(() {
      _searchResult = null;
      _searchResultUid = null;
      _searchExactMatch = null;
      if (clearError) _searchError = null;
    });
  }

  void _clearSearchUiState() {
    _searchCtrl.clear();
    _resetSearchResult(clearError: true);
  }

  void _onSearchTextChanged() {
    final expected = _searchExactMatch;
    if (expected == null) return;

    final current = _searchCtrl.text.trim();
    if (current != expected) {
      // Spec: if text no longer matches exactly username#tag, hide immediately.
      _resetSearchResult(clearError: true);
    }
  }

  Future<void> _runSearch() async {
    if (_busy) return;
    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;
    if (!firebaseReady || user == null) return;

    final input = _searchCtrl.text.trim();
    if (input.isEmpty) return;

    if (!input.contains('#')) {
      setState(() {
        _searchResult = null;
        _searchResultUid = null;
        _searchError =
            'Para añadir a un amigo necesitas su nombre completo y tag único. Ejemplo: miguel#482913';
      });
      return;
    }

    setState(() {
      _busy = true;
      _searchResult = null;
      _searchResultUid = null;
      _searchError = null;
      _searchExactMatch = null;
    });

    try {
      final found = await _friends.findPublicUserByFullTag(input);
      final targetUid = found?.uid;

      if (!mounted) return;

      if (targetUid == null || found == null || found.visible == false) {
        setState(() => _searchError = 'No se encontraron resultados');
        return;
      }

      if (targetUid == user.uid) {
        setState(() => _searchError = 'Ese es tu propio usuario');
        return;
      }

      setState(() {
        _searchResult = found;
        _searchResultUid = targetUid;
        _searchExactMatch = input;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = switch (e) {
        FormatException(:final message) => message,
        FirebaseException(:final code) when code == 'permission-denied' =>
          'No se pudo buscar: permisos insuficientes (permission-denied)',
        FirebaseException(:final code) when code == 'failed-precondition' =>
          'No se pudo buscar: falta un índice en Firestore (failed-precondition)',
        FirebaseException(:final code) => 'No se pudo buscar: $code',
        _ => 'No se pudo buscar',
      };
      setState(() => _searchError = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendFriendRequestToSearchResult() async {
    if (_busy) return;
    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;
    if (!firebaseReady || user == null) return;

    final targetUid = _searchResultUid;
    if (targetUid == null || targetUid.trim().isEmpty) return;

    // If I blocked this user, Firestore rules will reject creating friend_requests.
    // Show a clear message instead of a generic failure.
    try {
      final blocked = await _blockService.getBlockedUserIdsOnce();
      if (blocked.contains(targetUid)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Has bloqueado a este usuario. Desbloquéalo para enviar solicitud.',
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // ignore
    }

    setState(() => _busy = true);
    try {
      final res = await _friends.sendFriendRequestSafely(
        myUid: user.uid,
        targetUid: targetUid,
      );
      if (!mounted) return;

      final msg = switch (res) {
        SendFriendRequestResult.created => 'Solicitud enviada',
        SendFriendRequestResult.alreadyFriends => 'Ya sois amigos',
        SendFriendRequestResult.alreadyPendingSent =>
          'Ya enviaste una solicitud',
        SendFriendRequestResult.alreadyPendingReceived =>
          'Ya tienes una solicitud de esa persona',
        SendFriendRequestResult.alreadyExists =>
          'Ya existe una solicitud o relación previa',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      // Spec: when detecting “Ya sois amigos” or “Solicitud enviada”, auto-clean UI.
      if (res == SendFriendRequestResult.created ||
          res == SendFriendRequestResult.alreadyFriends) {
        _clearSearchUiState();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = switch (e) {
        FirebaseException(code: final code) =>
          'No se pudo enviar la solicitud. ($code)',
        _ => 'No se pudo enviar la solicitud',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDmWithUser({
    required String myUid,
    required String peerUid,
  }) async {
    final chatId = SocialFirestoreService.pairIdFor(myUid, peerUid);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatScreen.dm(chatId: chatId)));
  }

  Widget _coachSection({required bool isPremium}) {
    return ProgressSectionCard(
      backgroundColor: CFColors.primary.withValues(alpha: 0.06),
      borderColor: CFColors.primary.withValues(alpha: 0.18),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: CFColors.primary.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              border: Border.all(
                color: CFColors.primary.withValues(alpha: 0.20),
              ),
            ),
            child: Icon(
              isPremium ? Icons.support_agent_outlined : Icons.lock_outline,
              color: CFColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach CotidyFit',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Habla con un profesional',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isPremium)
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen.privateContact(
                      contactId: ContactsLocalService.coach.id,
                    ),
                  ),
                );
              },
              child: const Text('Enviar mensaje'),
            )
          else
            FilledButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Premium: próximamente')),
              ),
              child: const Text('Desbloquear Premium'),
            ),
        ],
      ),
    );
  }

  Widget _searchSection() {
    final result = _searchResult;

    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Añadir amigo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Busca por nombre completo y tag único (username#123456).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'miguel#482913',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _runSearch(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _busy ? null : _runSearch,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Buscar'),
              ),
            ],
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 10),
            Text(
              _searchError!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            ProgressSectionCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CommunityAvatar(
                      keySeed: result.uid,
                      label: result.displayName,
                      size: 50,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.displayName,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.uniqueTag.isEmpty ? '—' : result.uniqueTag,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: CFColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : _sendFriendRequestToSearchResult,
                      child: const Text('Añadir'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await _profileService.getOrCreateProfile();
    final contacts = await _contacts.getContacts();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _all = contacts;
      _loading = false;
    });
  }

  List<ContactModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.tag.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _addFriend() async {
    final nameCtrl = TextEditingController();
    final tagCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir amigo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tagCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tag único',
                  hintText: '@usuario123',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || tagCtrl.text.trim().isEmpty)
                  return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    try {
      await _contacts.addFriendMock(name: nameCtrl.text, tag: tagCtrl.text);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada (mock).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo añadir: $e')));
    }
  }

  Future<void> _openContact(ContactModel c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen.privateContact(contactId: c.id),
      ),
    );
  }

  void _unlockPremium() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Premium: próximamente')));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    if (firebaseReady && user != null) {
      if (_socialUid != user.uid ||
          _pendingReqsStream == null ||
          _friendsStream == null) {
        _socialUid = user.uid;
        _pendingReqsStream = _social.watchPendingFriendRequests();
        _friendsStream = _social.watchFriends();
      }

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _coachSection(isPremium: _profile?.isPremium ?? false),
          const SizedBox(height: 14),
          _searchSection(),
          const SizedBox(height: 18),
          Text(
            'Solicitudes',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<FriendRequestModel>>(
            stream: _pendingReqsStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                final e = snap.error;
                if (e is FirebaseException) {
                  final msg = (e.message ?? '').trim();
                  return ProgressSectionCard(
                    child: Text(
                      msg.isEmpty
                          ? 'Error cargando solicitudes: ${e.code}'
                          : 'Error cargando solicitudes: ${e.code}\n$msg',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return ProgressSectionCard(
                  child: Text(
                    'Error cargando solicitudes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              final reqs = snap.data ?? const <FriendRequestModel>[];
              if (reqs.isEmpty) {
                return ProgressSectionCard(
                  child: Text(
                    'No tienes solicitudes pendientes.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              return Column(
                children: [
                  for (final r in reqs) ...[
                    _FriendRequestRow(req: r, myUid: user.uid, social: _social),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Amigos',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<PublicUser>>(
            stream: _friendsStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                final e = snap.error;
                if (e is FirebaseException) {
                  final msg = (e.message ?? '').trim();
                  return ProgressSectionCard(
                    child: Text(
                      msg.isEmpty
                          ? 'Error cargando amigos: ${e.code}'
                          : 'Error cargando amigos: ${e.code}\n$msg',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return ProgressSectionCard(
                  child: Text(
                    'Error cargando amigos.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              final friends = snap.data ?? const <PublicUser>[];
              if (friends.isEmpty) {
                return ProgressSectionCard(
                  child: Text(
                    'Aún no has añadido amigos.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              return Column(
                children: [
                  for (final f in friends) ...[
                    ProgressSectionCard(
                      child: InkWell(
                        onTap: () =>
                            _openDmWithUser(myUid: user.uid, peerUid: f.uid),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CommunityAvatar(
                                keySeed: f.uid,
                                label: f.displayName,
                                size: 50,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      f.uniqueTag.isEmpty ? '—' : f.uniqueTag,
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
                              const Icon(
                                Icons.chevron_right,
                                color: CFColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 18),
          Text(
            'Usuarios bloqueados',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<String>>(
            stream: _blockService.watchBlockedUserIds(),
            builder: (context, blockedSnap) {
              if (blockedSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final blocked = blockedSnap.data ?? const <String>[];
              if (blocked.isEmpty) {
                return ProgressSectionCard(
                  child: Text(
                    'No has bloqueado a nadie.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              return Column(
                children: [
                  for (final uid in blocked) ...[
                    FutureBuilder<PublicUser?>(
                      future: _social.getPublicUser(uid),
                      builder: (context, userSnap) {
                        final u = userSnap.data;
                        final name = u?.displayName.trim().isNotEmpty == true
                            ? u!.displayName
                            : 'Usuario';
                        final tag = (u?.uniqueTag ?? '').trim();
                        return ProgressSectionCard(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CommunityAvatar(
                                  keySeed: uid,
                                  label: name,
                                  size: 46,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        tag.isEmpty ? '—' : tag,
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
                                const SizedBox(width: 10),
                                FilledButton(
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    try {
                                      await _blockService.unblockUser(
                                        blockedUid: uid,
                                      );
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Usuario desbloqueado'),
                                        ),
                                      );
                                    } catch (_) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'No se pudo desbloquear',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Desbloquear'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      );
    }

    final profile = _profile;

    if (_loading || profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _CoachCard(
            isPremium: profile.isPremium,
            onOpen: () => _openContact(ContactsLocalService.coach),
            onUnlockPremium: _unlockPremium,
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o tag…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Amigos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                onPressed: _addFriend,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Añadir'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final c in _filtered) ...[
            _ContactRow(contact: c, onTap: () => _openContact(c)),
            const SizedBox(height: 10),
          ],
          if (_filtered.isEmpty)
            ProgressSectionCard(
              child: Text(
                'Sin resultados.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _FriendRequestRow extends StatefulWidget {
  const _FriendRequestRow({
    required this.req,
    required this.myUid,
    required this.social,
  });

  final FriendRequestModel req;
  final String myUid;
  final SocialFirestoreService social;

  @override
  State<_FriendRequestRow> createState() => _FriendRequestRowState();
}

class _FriendRequestRowState extends State<_FriendRequestRow> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.social.acceptFriendRequest(widget.req);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitud aceptada')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo aceptar')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.social.rejectFriendRequest(widget.req);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitud rechazada')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No se pudo rechazar')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    final incoming = req.addresseeUid == widget.myUid;
    final peerUid = incoming ? req.requesterUid : req.addresseeUid;

    return FutureBuilder<PublicUser?>(
      future: widget.social.getPublicUser(peerUid),
      builder: (context, snap) {
        final user = snap.data;
        final name = user?.displayName ?? 'Usuario';
        final tag = user?.uniqueTag ?? '';

        return ProgressSectionCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CommunityAvatar(keySeed: peerUid, label: name, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tag.isEmpty
                            ? (incoming
                                  ? 'Solicitud recibida'
                                  : 'Solicitud enviada')
                            : tag,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: CFColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (incoming) ...[
                  TextButton(
                    onPressed: _busy ? null : _reject,
                    child: const Text('Rechazar'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: _busy ? null : _accept,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Aceptar'),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CFColors.primary.withValues(alpha: 0.10),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(999),
                      ),
                      border: Border.all(
                        color: CFColors.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      'Pendiente',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CFColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.isPremium,
    required this.onOpen,
    required this.onUnlockPremium,
  });

  final bool isPremium;
  final VoidCallback onOpen;
  final VoidCallback onUnlockPremium;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      backgroundColor: CFColors.primary.withValues(alpha: 0.06),
      borderColor: CFColors.primary.withValues(alpha: 0.18),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: CFColors.primary.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              border: Border.all(
                color: CFColors.primary.withValues(alpha: 0.20),
              ),
            ),
            child: Icon(
              isPremium ? Icons.support_agent_outlined : Icons.lock_outline,
              color: CFColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach CotidyFit',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Habla con un profesional',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isPremium)
            FilledButton(onPressed: onOpen, child: const Text('Abrir'))
          else
            FilledButton(
              onPressed: onUnlockPremium,
              child: const Text('Desbloquear Premium'),
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onTap});

  final ContactModel contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pending = contact.status == ContactStatus.pending;

    return ProgressSectionCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CommunityAvatar(
                keySeed: contact.avatarKey,
                label: contact.name,
                size: 50,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.tag,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (pending)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: CFColors.primary.withValues(alpha: 0.10),
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(
                      color: CFColors.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    'Pendiente',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CFColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
