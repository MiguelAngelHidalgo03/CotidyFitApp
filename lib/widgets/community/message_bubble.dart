import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    final bg = isMine ? CFColors.primary : CFColors.softGray;
    final fg = isMine ? Colors.white : CFColors.textPrimary;

    final prefix = switch (message.type) {
      MessageType.text => null,
      MessageType.routine => 'Rutina',
      MessageType.achievement => 'Logro',
      MessageType.daySummary => 'Resumen del día',
      MessageType.diet => 'Dieta',
      MessageType.streaks => 'Rachas',
    };

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
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
                        color: isMine ? Colors.white.withValues(alpha: 0.92) : CFColors.textSecondary,
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
      ),
    );
  }
}
