import 'package:flutter/material.dart';

import '../../core/theme.dart';

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    super.key,
    required this.keySeed,
    required this.label,
    this.size = 44,
    this.isLocked = false,
  });

  final String keySeed;
  final String label;
  final double size;
  final bool isLocked;

  Color _bgColor() {
    final seed = keySeed.codeUnits.fold<int>(0, (a, b) => a + b);
    final palette = <Color>[
      CFColors.primary.withValues(alpha: 0.12),
      CFColors.primaryLight.withValues(alpha: 0.18),
      CFColors.softGray,
      CFColors.primary.withValues(alpha: 0.08),
    ];
    return palette[seed % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColor();
    final initial = label.trim().isEmpty ? '?' : label.trim().characters.first.toUpperCase();

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: CFColors.primary.withValues(alpha: 0.18)),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CFColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: size >= 44 ? 18 : 16,
                ),
          ),
        ),
        if (isLocked)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.38,
              height: size * 0.38,
              decoration: BoxDecoration(
                color: CFColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: CFColors.background, width: 2),
              ),
              child: const Icon(Icons.lock_outline, size: 14, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
