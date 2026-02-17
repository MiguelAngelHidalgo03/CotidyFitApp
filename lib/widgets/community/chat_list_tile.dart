import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import 'community_avatar.dart';

class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.chat,
    required this.onTap,
    required this.isProfessionalLocked,
  });

  final ChatModel chat;
  final VoidCallback onTap;
  final bool isProfessionalLocked;

  String _preview(MessageModel? m) {
    if (m == null) return 'Sin mensajes';
    final prefix = switch (m.type) {
      MessageType.text => '',
      MessageType.routine => 'Rutina: ',
      MessageType.achievement => 'Logro: ',
      MessageType.daySummary => 'Resumen: ',
      MessageType.diet => 'Dieta: ',
      MessageType.streaks => 'Rachas: ',
    };
    return (prefix + m.text).trim();
  }

  String _timeLabel(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final last = chat.lastMessage;

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            CommunityAvatar(
              keySeed: chat.avatarKey,
              label: chat.title,
              isLocked: isProfessionalLocked,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _timeLabel(chat.updatedAtMs),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CFColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _preview(last),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (chat.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: CFColors.primary,
                            borderRadius: const BorderRadius.all(Radius.circular(999)),
                          ),
                          child: Text(
                            chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
