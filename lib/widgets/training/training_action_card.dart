import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../progress/progress_section_card.dart';

class TrainingActionCard extends StatelessWidget {
  const TrainingActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.footer,
    this.backgroundColor,
    this.borderColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final Widget? footer;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      padding: EdgeInsets.zero,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: CFColors.primary.withValues(alpha: 0.10),
                      borderRadius: const BorderRadius.all(Radius.circular(18)),
                    ),
                    child: Icon(icon, color: CFColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  trailing ??
                      const Icon(
                        Icons.chevron_right,
                        color: CFColors.textSecondary,
                      ),
                ],
              ),
              if (footer != null) ...[const SizedBox(height: 12), footer!],
            ],
          ),
        ),
      ),
    );
  }
}
