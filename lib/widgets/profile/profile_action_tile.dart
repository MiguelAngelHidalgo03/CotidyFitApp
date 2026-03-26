import 'package:flutter/material.dart';

import '../../core/theme.dart';

class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? context.cfPrimary;
    final titleColor = enabled
        ? (accentColor == null ? context.cfTextPrimary : accent)
        : context.cfTextSecondary;
    final trailingColor = enabled ? context.cfTextSecondary : context.cfBorder;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: enabled ? 0.14 : 0.08),
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: context.cfBorder),
              ),
              child: Icon(
                icon,
                color: enabled ? accent : context.cfTextSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.cfTextSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: trailingColor),
          ],
        ),
      ),
    );
  }
}
