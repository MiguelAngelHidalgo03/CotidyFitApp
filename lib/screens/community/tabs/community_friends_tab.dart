import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/theme.dart';
import '../../../services/social_firestore_service.dart';
import '../../../widgets/community/community_avatar.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../chat_screen.dart';

class CommunityFriendsTab extends StatefulWidget {
  const CommunityFriendsTab({super.key});

  @override
  State<CommunityFriendsTab> createState() => _CommunityFriendsTabState();
}

class _CommunityFriendsTabState extends State<CommunityFriendsTab>
    with AutomaticKeepAliveClientMixin {
  final _social = SocialFirestoreService();

  String? _uid;
  Stream<List<FriendRequestModel>>? _reqsStream;
  Stream<List<PublicUser>>? _friendsStream;

  Future<void> _openDmWithUser({
    required String myUid,
    required String peerUid,
  }) async {
    final chatId = SocialFirestoreService.pairIdFor(myUid, peerUid);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatScreen.dm(chatId: chatId)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    if (!firebaseReady || user == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ProgressSectionCard(
          child: Text(
            'Inicia sesión para ver amigos y solicitudes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    if (_uid != user.uid || _reqsStream == null || _friendsStream == null) {
      _uid = user.uid;
      _reqsStream = _social.watchPendingFriendRequests();
      _friendsStream = _social.watchFriends();
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Solicitudes',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<FriendRequestModel>>(
          stream: _reqsStream,
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
                      borderRadius: const BorderRadius.all(Radius.circular(18)),
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
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
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
      ],
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
