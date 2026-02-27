import 'package:flutter/material.dart';

import '../../core/theme.dart';

class HomeAchievementsButton extends StatelessWidget {
  const HomeAchievementsButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CFColors.surface,
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(22)),
            border: Border.all(color: CFColors.softGray),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CFColors.primary.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                ),
                child: const Icon(Icons.emoji_events_outlined, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logros',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ver desbloqueados, bloqueados y progreso',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: CFColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: CFColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
