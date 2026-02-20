import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/message_model.dart';
import 'community_avatar.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = false,
    this.avatarKeySeed,
    this.avatarLabel,
    this.showTimestamp = true,
  });

  final MessageModel message;
  final bool showAvatar;
  final String? avatarKeySeed;
  final String? avatarLabel;
  final bool showTimestamp;

  String _timeLabel(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    final bg = isMine ? CFColors.primary : CFColors.softGray;
    final fg = isMine ? Colors.white : CFColors.textPrimary;

    final ts = _timeLabel(message.createdAtMs);
    final showIncomingAvatar = showAvatar && !isMine;

    final prefix = switch (message.type) {
      MessageType.text => null,
      MessageType.routine => 'Rutina',
      MessageType.achievement => 'Logro',
      MessageType.daySummary => 'Resumen del día',
      MessageType.diet => 'Dieta',
      MessageType.streaks => 'Rachas',
    };

    Widget bubble() {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 6),
              bottomRight: Radius.circular(isMine ? 6 : 16),
            ),
            border: isMine ? null : Border.all(color: CFColors.softGray),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prefix != null) ...[
                Text(
                  prefix,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.92)
                        : CFColors.textSecondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                message.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: fg,
                  height: 1.25,
                  fontWeight: isMine ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget timestamp() {
      if (!showTimestamp) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(
          left: showIncomingAvatar ? 44 : 0,
          right: isMine ? 6 : 0,
          top: 0,
          bottom: 2,
        ),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            ts,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isMine ? CFColors.textSecondary : CFColors.textSecondary,
            ),
          ),
        ),
      );
    }

    Widget content() {
      final bubbleColumn = Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [bubble(), timestamp()],
      );

      if (!showIncomingAvatar) return bubbleColumn;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CommunityAvatar(
            keySeed: (avatarKeySeed ?? message.senderId).trim().isEmpty
                ? message.senderId
                : avatarKeySeed!,
            label: (avatarLabel ?? message.senderName).trim().isEmpty
                ? message.senderName
                : avatarLabel!,
            size: 34,
          ),
          const SizedBox(width: 10),
          Flexible(child: bubbleColumn),
        ],
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: content(),
    );
  }
}
