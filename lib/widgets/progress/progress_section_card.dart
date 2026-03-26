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
    final shadow =
        boxShadow ??
        [
          BoxShadow(
            color: context.cfShadow,
            blurRadius: context.cfIsDark ? 22 : 16,
            offset: const Offset(0, 8),
          ),
        ];

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? context.cfSurface,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: borderColor ?? context.cfBorder),
        boxShadow: shadow,
      ),
      padding: padding,
      child: child,
    );
  }
}
