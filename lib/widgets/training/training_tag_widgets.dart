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
        color: context.cfSoftSurface,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: context.cfBorder),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.cfTextSecondary,
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
        color: context.cfPrimaryTint,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: context.cfPrimaryTintStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.cfPrimary),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.cfPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
