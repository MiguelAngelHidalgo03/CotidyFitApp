import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/user_profile.dart';

class StreakPreferencesEditor extends StatelessWidget {
  const StreakPreferencesEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.title,
    this.subtitle,
  });

  final UserStreakPreferences value;
  final ValueChanged<UserStreakPreferences> onChanged;
  final bool enabled;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((title ?? '').trim().isNotEmpty) ...[
          Text(
            title!,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if ((subtitle ?? '').trim().isNotEmpty) ...[
          Text(subtitle!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
        ],
        for (final area in UserStreakFocusArea.values) ...[
          _FocusAreaTile(
            area: area,
            selected: value.focusAreas.contains(area),
            enabled: enabled,
            onTap: () => _toggleArea(area),
          ),
          if (area != UserStreakFocusArea.values.last) const SizedBox(height: 10),
        ],
        if (value.isMultiFocus) ...[
          const SizedBox(height: 18),
          Text(
            'Como quieres contar el mix',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Si eliges varios focos, define si el dia cuenta con uno solo o con todos.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final mode in UserStreakMixMode.values) ...[
            _MixModeTile(
              mode: mode,
              selected: value.mixMode == mode,
              enabled: enabled,
              onTap: () => _setMixMode(mode),
            ),
            if (mode != UserStreakMixMode.values.last) const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CFColors.primary.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            border: Border.all(color: CFColors.primary.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: CFColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(value.summary, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleArea(UserStreakFocusArea area) {
    if (!enabled) return;
    final nextAreas = value.focusAreas.toList();
    if (nextAreas.contains(area)) {
      nextAreas.remove(area);
    } else {
      nextAreas.add(area);
    }

    onChanged(
      UserStreakPreferences(
        focusAreas: nextAreas,
        mixMode: nextAreas.length <= 1 ? UserStreakMixMode.any : value.mixMode,
      ),
    );
  }

  void _setMixMode(UserStreakMixMode mode) {
    if (!enabled) return;
    onChanged(value.copyWith(mixMode: mode));
  }
}

class _FocusAreaTile extends StatelessWidget {
  const _FocusAreaTile({
    required this.area,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final UserStreakFocusArea area;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = selected ? CFColors.primary : CFColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? CFColors.primary.withValues(alpha: 0.08)
                : CFColors.surface,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            border: Border.all(
              color: selected ? CFColors.primary : CFColors.softGray,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? CFColors.primary.withValues(alpha: 0.14)
                      : CFColors.softGray.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(_iconFor(area), color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(area.subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: selected ? CFColors.primary : CFColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(UserStreakFocusArea area) {
    switch (area) {
      case UserStreakFocusArea.nutrition:
        return Icons.restaurant_outlined;
      case UserStreakFocusArea.training:
        return Icons.fitness_center;
      case UserStreakFocusArea.water:
        return Icons.water_drop_outlined;
      case UserStreakFocusArea.steps:
        return Icons.directions_walk_outlined;
      case UserStreakFocusArea.dailyChallenge:
        return Icons.emoji_events_outlined;
    }
  }
}

class _MixModeTile extends StatelessWidget {
  const _MixModeTile({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final UserStreakMixMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? CFColors.primary.withValues(alpha: 0.08)
                : CFColors.surface,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            border: Border.all(
              color: selected ? CFColors.primary : CFColors.softGray,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(mode.subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: selected ? CFColors.primary : CFColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
