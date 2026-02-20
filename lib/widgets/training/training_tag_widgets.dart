import 'package:flutter/material.dart';

import '../../core/theme.dart';

class TrainingTagChip extends StatelessWidget {
  const TrainingTagChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: CFColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class TrainingMiniTag extends StatelessWidget {
  const TrainingMiniTag({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CFColors.surface.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: CFColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CFColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
