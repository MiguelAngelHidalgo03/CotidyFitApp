import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/user_profile.dart';

class HeaderProfile extends StatelessWidget {
  const HeaderProfile({
    super.key,
    required this.profile,
    required this.onOpenProfile,
  });

  final UserProfile? profile;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final p = profile;

    final rawName = (p?.name ?? '').trim();
    final name = rawName.isEmpty || rawName == 'CotidyFit' ? 'Tu panel' : rawName;

    final isPremium = p?.isPremium ?? false;
    final planText = isPremium ? 'Plan Premium' : 'Plan gratuito';
    final planIcon = isPremium ? Icons.star_rounded : Icons.lock_outline;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AvatarCircle(profile: p),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: CFColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(planIcon, size: 14, color: CFColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    planText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: CFColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Perfil',
          onPressed: onOpenProfile,
          icon: const Icon(Icons.settings_outlined, color: CFColors.primary),
        ),
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;

    final bg = p == null
        ? CFColors.primary.withValues(alpha: 0.10)
        : _avatarBg(p.avatar.colorIndex);

    final icon = p == null
        ? Icons.person_outline
        : switch (p.avatar.icon) {
            AvatarIcon.persona => Icons.person_outline,
            AvatarIcon.atleta => Icons.fitness_center_outlined,
            AvatarIcon.rayo => Icons.bolt_outlined,
            AvatarIcon.corona => Icons.workspace_premium_outlined,
          };

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(
          color: CFColors.primary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Icon(icon, color: CFColors.primary, size: 22),
    );
  }

  Color _avatarBg(int index) {
    final palette = <Color>[
      CFColors.primary.withValues(alpha: 0.10),
      CFColors.primary.withValues(alpha: 0.14),
      CFColors.primaryLight.withValues(alpha: 0.18),
      CFColors.primaryLight.withValues(alpha: 0.24),
      CFColors.softGray,
    ];
    return palette[index % palette.length];
  }
}
