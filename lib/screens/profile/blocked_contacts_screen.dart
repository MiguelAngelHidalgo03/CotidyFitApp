import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/block_service.dart';
import '../../widgets/progress/progress_section_card.dart';

class BlockedContactsScreen extends StatelessWidget {
  const BlockedContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseReady = Firebase.apps.isNotEmpty;
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;
    final uid = user?.uid;

    if (!firebaseReady || uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contactos bloqueados')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ProgressSectionCard(
              child: Text(
                'Inicia sesión para ver tus bloqueos.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      );
    }

    final blockService = BlockService();

    return Scaffold(
      appBar: AppBar(title: const Text('Contactos bloqueados')),
      body: SafeArea(
        child: StreamBuilder<List<String>>(
          stream: blockService.watchBlockedUserIds(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final ids = snap.data ?? const <String>[];
            if (ids.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: ProgressSectionCard(
                  child: Text(
                    'No tienes contactos bloqueados.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ProgressSectionCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < ids.length; i++) ...[
                        _BlockedUserTile(
                          uid: ids[i],
                          onUnblock: () async {
                            await blockService.unblockUser(blockedUid: ids[i]);
                          },
                        ),
                        if (i != ids.length - 1) const Divider(height: 1),
                      ],
                    ],
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

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({required this.uid, required this.onUnblock});

  final String uid;
  final Future<void> Function() onUnblock;

  @override
  Widget build(BuildContext context) {
    final publicRef = FirebaseFirestore.instance
        .collection('user_public')
        .doc(uid);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      title: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: publicRef.get(),
        builder: (context, snap) {
          final data = snap.data?.data();
          final name = (data?['username'] as String?)?.trim();
          final tag = (data?['uniqueTag'] as String?)?.trim();
          final title = [
            if (name != null && name.isNotEmpty) name,
            if (tag != null && tag.isNotEmpty) tag,
          ].join(' ');

          return Text(
            title.isNotEmpty ? title : 'Usuario',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
      subtitle: Text(
        uid,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: CFColors.textSecondary),
      ),
      trailing: TextButton(
        onPressed: () async {
          await onUnblock();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contacto desbloqueado.')),
            );
          }
        },
        child: const Text('Desbloquear'),
      ),
    );
  }
}
