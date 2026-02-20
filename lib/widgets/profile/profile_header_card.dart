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
    this.identityTag,
    this.onCopyIdentityTag,
  });

  final UserProfile profile;
  final VoidCallback onEditAvatar;
  final VoidCallback onEditName;
  final VoidCallback onEditPressed;
  final String? identityTag;
  final VoidCallback? onCopyIdentityTag;

  @override
  Widget build(BuildContext context) {
    final tag = (identityTag ?? '').trim();

    return ProgressSectionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
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
                      color: CFColors.primary,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      border: Border.all(color: CFColors.background, width: 2),
                    ),
                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
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
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onEditName,
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ),
                    ),
                    _PremiumBadge(isPremium: profile.isPremium),
                  ],
                ),
                if (tag.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: CFColors.textSecondary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: onCopyIdentityTag,
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        color: CFColors.textSecondary,
                        tooltip: 'Copiar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  profile.isPremium ? 'Suscripción: Premium activo' : 'Suscripción: Gratuito',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CFColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: onEditPressed,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final palette = <Color>[
      CFColors.primary.withValues(alpha: 0.12),
      CFColors.primary.withValues(alpha: 0.18),
      CFColors.primaryLight.withValues(alpha: 0.28),
      CFColors.softGray,
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
        border: Border.all(color: CFColors.softGray),
      ),
      child: Icon(icon, color: CFColors.primary, size: 34),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPremium ? CFColors.primary.withValues(alpha: 0.12) : CFColors.softGray,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: isPremium ? CFColors.primary : CFColors.softGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium ? Icons.workspace_premium_outlined : Icons.lock_outline,
            size: 16,
            color: isPremium ? CFColors.primary : CFColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            'Premium',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isPremium ? CFColors.primary : CFColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
