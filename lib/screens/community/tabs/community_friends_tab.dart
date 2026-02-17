import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/friend_model.dart';
import '../../../services/friends_local_service.dart';
import '../../../widgets/community/community_avatar.dart';
import '../../../widgets/progress/progress_section_card.dart';

class CommunityFriendsTab extends StatefulWidget {
  const CommunityFriendsTab({super.key});

  @override
  State<CommunityFriendsTab> createState() => _CommunityFriendsTabState();
}

class _CommunityFriendsTabState extends State<CommunityFriendsTab> {
  final _service = FriendsLocalService();

  List<FriendModel> _friends = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final friends = await _service.getFriends();
    if (!mounted) return;
    setState(() {
      _friends = friends;
      _loading = false;
    });
  }

  Future<void> _addFriend() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir amigo'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nombre (mock)',
              hintText: 'Ej: Carlos',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final v = controller.text.trim();
                if (v.isEmpty) return;
                Navigator.of(context).pop(v);
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (name == null || name.trim().isEmpty) return;
    await _service.addFriendMock(name);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ProgressSectionCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Amigos', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text('Añade amigos para motivaros juntos.', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addFriend,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Añadir'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final f in _friends) ...[
            _FriendRow(
              friend: f,
              onAccept: f.status == FriendStatus.pending
                  ? () async {
                      await _service.markAccepted(f.id);
                      await _load();
                    }
                  : null,
            ),
            const SizedBox(height: 10),
          ],
          if (_friends.isEmpty)
            ProgressSectionCard(
              child: Text('Sin amigos aún.', style: Theme.of(context).textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.onAccept});

  final FriendModel friend;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final isPending = friend.status == FriendStatus.pending;

    return ProgressSectionCard(
      child: Row(
        children: [
          CommunityAvatar(keySeed: friend.avatarKey, label: friend.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPending ? CFColors.primary.withValues(alpha: 0.10) : CFColors.background,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(color: isPending ? CFColors.primary.withValues(alpha: 0.22) : CFColors.softGray),
                  ),
                  child: Text(
                    friend.status.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isPending ? CFColors.primary : CFColors.textSecondary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (onAccept != null)
            FilledButton(
              onPressed: onAccept,
              child: const Text('Aceptar'),
            )
          else
            Icon(Icons.check_circle, color: CFColors.primary.withValues(alpha: 0.55)),
        ],
      ),
    );
  }
}
