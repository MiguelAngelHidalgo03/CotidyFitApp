import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/user_profile.dart';
import '../progress/progress_section_card.dart';

class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.profile,
    required this.onEditAvatar,
    required this.onEditName,
    required this.onEditPressed,
    this.achievementsLevel,
    this.identityTag,
    this.onCopyIdentityTag,
    this.onPremiumPressed,
  });

  final UserProfile profile;
  final VoidCallback onEditAvatar;
  final VoidCallback onEditName;
  final VoidCallback onEditPressed;
  final int? achievementsLevel;
  final String? identityTag;
  final VoidCallback? onCopyIdentityTag;
  final VoidCallback? onPremiumPressed;

  @override
  Widget build(BuildContext context) {
    final primary = context.cfPrimary;
    final tag = (identityTag ?? '').trim();
    final levelNumber = achievementsLevel ?? _levelToNumber(profile.level);
    final statusLine = 'Nivel $levelNumber · Constante 🔥';
    final planLabel = profile.isPremium ? 'Premium' : 'Gratuito';

    return ProgressSectionCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: context.cfPrimaryTint.withValues(
        alpha: context.cfIsDark ? 0.14 : 0.05,
      ),
      borderColor: context.cfPrimaryTintStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _AvatarCircle(profile: profile),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: InkWell(
                      onTap: onEditAvatar,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(14),
                          ),
                          border: Border.all(
                            color: context.cfSurface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 16,
                          color: context.cfOnPrimaryStrong,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onEditName,
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusLine,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.cfTextSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProfileInfoRow(
            label: 'Identificador',
            value: tag.isNotEmpty ? tag : '—',
            trailing: (tag.isNotEmpty && onCopyIdentityTag != null)
                ? InkWell(
                    onTap: onCopyIdentityTag,
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.copy_outlined,
                        size: 18,
                        color: context.cfTextSecondary,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          _ProfileInfoRow(
            label: 'Plan de suscripción',
            value: planLabel,
            onTap: onPremiumPressed,
            trailing: onPremiumPressed == null
                ? null
                : Icon(Icons.chevron_right, color: context.cfTextSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: onEditPressed,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar perfil'),
            ),
          ),
        ],
      ),
    );
  }
}

int _levelToNumber(UserLevel level) {
  return switch (level) {
    UserLevel.principiante => 1,
    UserLevel.intermedio => 2,
    UserLevel.avanzado => 3,
  };
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.cfSurface,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: context.cfBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.cfTextSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: context.cfTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    final cb = onTap;
    if (cb == null) return child;

    return InkWell(
      onTap: cb,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: child,
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final primary = context.cfPrimary;
    final palette = <Color>[
      primary.withValues(alpha: context.cfIsDark ? 0.22 : 0.12),
      primary.withValues(alpha: context.cfIsDark ? 0.28 : 0.18),
      primary.withValues(alpha: context.cfIsDark ? 0.34 : 0.24),
      context.cfMutedSurface,
    ];
    final bg = palette[profile.avatar.colorIndex % palette.length];
    final icon = switch (profile.avatar.icon) {
      AvatarIcon.persona => Icons.person_outline,
      AvatarIcon.atleta => Icons.fitness_center_outlined,
      AvatarIcon.rayo => Icons.bolt_outlined,
      AvatarIcon.corona => Icons.workspace_premium_outlined,
    };

    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(26)),
        border: Border.all(color: context.cfBorder),
      ),
      child: Icon(icon, color: primary, size: 34),
    );
  }
}
