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
    this.avatarSize = 52,
  });

  final ChatModel chat;
  final VoidCallback onTap;
  final bool isProfessionalLocked;
  final double avatarSize;

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
    final now = DateTime.now();

    final sameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) {
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
    final last = chat.lastMessage;

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CommunityAvatar(
              keySeed: chat.avatarKey,
              label: chat.title,
              isLocked: isProfessionalLocked,
              size: avatarSize,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _preview(last),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
                        ),
                      ),
                      if (!chat.hiddenForMe && chat.unreadCount > 0) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: const BoxDecoration(
                            color: CFColors.primary,
                            borderRadius: BorderRadius.all(Radius.circular(999)),
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
