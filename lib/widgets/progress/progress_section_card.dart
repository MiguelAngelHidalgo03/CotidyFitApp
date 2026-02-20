import 'package:flutter/material.dart';

import '../../core/theme.dart';

class ProgressSectionCard extends StatelessWidget {
  const ProgressSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: borderColor ?? CFColors.softGray),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
      ),
      padding: padding,
      child: child,
    );
  }
}
