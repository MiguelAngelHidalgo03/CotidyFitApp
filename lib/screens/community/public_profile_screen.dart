import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/block_service.dart';
import '../../services/friend_service.dart';
import '../../services/social_firestore_service.dart';
import '../profile_screen.dart';
import '../../widgets/progress/progress_section_card.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _friends = FriendService();
  final _block = BlockService();

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm({required String title, required String message, required String confirmLabel}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return res ?? false;
  }

  int? _readInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  double? _readDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ProgressSectionCard(
              child: Text(
                'No disponible sin Firebase.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      );
    }

    final uid = widget.uid;
    final ref = FirebaseFirestore.instance.collection('user_public').doc(uid);
    final me = FirebaseAuth.instance.currentUser?.uid;
    final isMe = me != null && me == uid;
    final pairId = me == null ? null : SocialFirestoreService.pairIdFor(me, uid);

    final friendshipRef = pairId == null ? null : FirebaseFirestore.instance.collection('friendships').doc(pairId);
    final requestRef = pairId == null ? null : FirebaseFirestore.instance.collection('friend_requests').doc(pairId);

    Widget privateCard() {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ProgressSectionCard(
          child: Text(
            'Este perfil es privado.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    Widget errorCard(String msg) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ProgressSectionCard(
          child: Text(msg, style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ref.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              final e = snap.error;
              if (e is FirebaseException && e.code == 'permission-denied') {
                return privateCard();
              }
              return errorCard('No se pudo cargar el perfil.');
            }

            final data = snap.data?.data();
            if (data == null) {
              return errorCard('No se pudo cargar el perfil.');
            }

            final visible = (data['visible'] as bool?) ?? true;
            if (visible == false && !isMe) {
              return privateCard();
            }

            final displayName =
                (data['displayName'] as String?)?.trim() ??
                (data['username'] as String?)?.trim() ??
                '';
            final uniqueTag =
                (data['uniqueTag'] as String?)?.trim() ??
                (data['searchableTag'] as String?)?.trim() ??
                '';

            // Optional stats (best-effort, avoid crashes if fields don't exist).
            final maxStreak = _readInt(data['maxStreak'] ?? data['maxStreakDays']);
            final activeDays = _readInt(data['activeDays'] ?? data['daysActive']);
            final workouts = _readInt(data['workouts'] ?? data['workoutsCount']);
            final nutritionPct = _readDouble(data['nutritionCompliancePct'] ?? data['nutritionCompletedPct']);

            Widget statItem(String label, String value) {
              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CFColors.textSecondary),
                    ),
                  ],
                ),
              );
            }

            Widget header() {
              final name = displayName.isEmpty ? 'Usuario' : displayName;
              final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

              return ProgressSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: CFColors.primary.withValues(alpha: 0.14),
                          child: Text(
                            initial,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: CFColors.primary,
                                ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                uniqueTag.isEmpty ? '—' : uniqueTag,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (isMe)
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                                );
                              },
                              child: const Text('Editar perfil'),
                            ),
                          )
                        else ...[
                          if (me == null)
                            const Expanded(child: SizedBox.shrink())
                          else
                            Expanded(
                              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                stream: friendshipRef?.snapshots(),
                                builder: (context, friendshipSnap) {
                                  final isFriend = friendshipSnap.data?.exists ?? false;
                                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                    stream: requestRef?.snapshots(),
                                    builder: (context, reqSnap) {
                                      final reqExists = reqSnap.data?.exists ?? false;
                                      final status = (reqSnap.data?.data()?['status'] as String?)?.trim() ?? 'pending';
                                      final pending = reqExists && status == 'pending';

                                      if (isFriend) {
                                        return FilledButton(
                                          onPressed: () async {
                                            final ok = await _confirm(
                                              title: 'Quitar amigo',
                                              message: '¿Quieres quitar a "$name" de tus amigos? También se eliminará el chat.',
                                              confirmLabel: 'Quitar',
                                            );
                                            if (!ok) return;
                                            try {
                                              await _friends.removeFriendshipAndChat(myUid: me, friendUid: uid);
                                              if (!mounted) return;
                                              _snack('Amigo eliminado');
                                            } catch (_) {
                                              if (!mounted) return;
                                              _snack('No se pudo quitar al amigo');
                                            }
                                          },
                                          child: const Text('Quitar amigo'),
                                        );
                                      }

                                      if (pending) {
                                        return FilledButton(
                                          onPressed: null,
                                          child: const Text('Solicitud enviada'),
                                        );
                                      }

                                      return FilledButton(
                                        onPressed: () async {
                                          // If I blocked this user, rules will reject creating friend_requests.
                                          try {
                                            final blocked = await _block.getBlockedUserIdsOnce();
                                            if (blocked.contains(uid)) {
                                              if (!mounted) return;
                                              _snack('Has bloqueado a este usuario. Desbloquéalo para enviar solicitud.');
                                              return;
                                            }
                                          } catch (_) {
                                            // ignore
                                          }

                                          try {
                                            final res = await _friends.sendFriendRequestSafely(myUid: me, targetUid: uid);
                                            if (!mounted) return;
                                            final msg = switch (res) {
                                              SendFriendRequestResult.created => 'Solicitud enviada',
                                              SendFriendRequestResult.alreadyFriends => 'Ya sois amigos',
                                              SendFriendRequestResult.alreadyPendingSent => 'Solicitud enviada',
                                              SendFriendRequestResult.alreadyPendingReceived => 'Tienes una solicitud de esa persona',
                                              SendFriendRequestResult.alreadyExists => 'Ya existe una relación previa',
                                            };
                                            _snack(msg);
                                          } catch (e) {
                                            if (!mounted) return;
                                            final msg = switch (e) {
                                              FirebaseException(code: final code) => 'No se pudo enviar la solicitud. ($code)',
                                              _ => 'No se pudo enviar la solicitud',
                                            };
                                            _snack(msg);
                                          }
                                        },
                                        child: const Text('Añadir amigo'),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          const SizedBox(width: 10),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: CFColors.surface,
                              foregroundColor: CFColors.textPrimary,
                            ),
                            onPressed: () async {
                              if (me == null) return;
                              final navigator = Navigator.of(context);
                              final ok = await _confirm(
                                title: 'Bloquear usuario',
                                message: '¿Bloquear a "$name"? No podrás escribirle ni recibir solicitudes.',
                                confirmLabel: 'Bloquear',
                              );
                              if (!ok) return;
                              try {
                                await _block.blockUser(blockedUid: uid);
                                if (!mounted) return;
                                _snack('Usuario bloqueado correctamente');
                                navigator.maybePop();
                              } catch (_) {
                                if (!mounted) return;
                                _snack('No se pudo bloquear');
                              }
                            },
                            child: const Text('Bloquear'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }

            Widget stats() {
              String fmtNum(int? v) => v == null ? '—' : v.toString();
              String fmtPct(double? v) {
                if (v == null) return '—';
                final pct = (v <= 1.0) ? (v * 100.0) : v;
                return '${pct.clamp(0, 100).round()}%';
              }

              return ProgressSectionCard(
                child: Row(
                  children: [
                    statItem('Racha máx', fmtNum(maxStreak)),
                    statItem('Días activos', fmtNum(activeDays)),
                    statItem('Entrenos', fmtNum(workouts)),
                    statItem('Nutrición', fmtPct(nutritionPct)),
                  ],
                ),
              );
            }

            Widget section({required String title, required String body}) {
              return ProgressSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary)),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                header(),
                const SizedBox(height: 14),
                stats(),
                const SizedBox(height: 14),
                section(
                  title: 'Logros',
                  body: 'Próximamente: lista de logros del usuario.',
                ),
                const SizedBox(height: 10),
                section(
                  title: 'Comidas favoritas',
                  body: 'Próximamente: comidas marcadas como favoritas.',
                ),
                const SizedBox(height: 10),
                section(
                  title: 'Tiempo en la app',
                  body: 'Próximamente: tiempo total y sesiones.',
                ),
                const SizedBox(height: 10),
                section(
                  title: 'Constancia promedio',
                  body: 'Próximamente: promedio semanal y tendencias.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
