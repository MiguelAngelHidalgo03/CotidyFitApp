import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/exercise.dart';

Future<void> showExerciseGuidanceBottomSheet(
  BuildContext context, {
  required Exercise exercise,
}) {
  final steps = exercise.howToSteps;
  final mistakes = exercise.commonMistakes;
  final tips = exercise.tips;
  final hasAnyContent =
      steps.isNotEmpty ||
      mistakes.isNotEmpty ||
      tips.isNotEmpty ||
      exercise.variants.isNotEmpty;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: context.cfSurface,
              borderRadius: const BorderRadius.all(Radius.circular(28)),
              border: Border.all(color: context.cfBorder),
              boxShadow: [
                BoxShadow(
                  color: context.cfShadow,
                  blurRadius: context.cfIsDark ? 28 : 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.78,
              minChildSize: 0.52,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.cfBorder,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.cfSoftSurface,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(20),
                        ),
                        border: Border.all(color: context.cfBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: context.cfPrimaryTint,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(16),
                              ),
                            ),
                            child: Icon(
                              exercise.muscleGroup.icon,
                              color: context.cfPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${exercise.repsOrTime} · ${exercise.muscleGroup.label}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: context.cfTextSecondary,
                                      ),
                                ),
                                if (exercise.description.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    exercise.description.trim(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: context.cfTextSecondary,
                                          height: 1.4,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!hasAnyContent)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cfSoftSurface,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(20),
                          ),
                          border: Border.all(color: context.cfBorder),
                        ),
                        child: Text(
                          'Este ejercicio todavía no tiene guía cargada en la base de datos.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.cfTextSecondary,
                                height: 1.4,
                              ),
                        ),
                      ),
                    if (steps.isNotEmpty) ...[
                      _GuidanceSection(
                        title: 'Paso a paso',
                        icon: Icons.format_list_numbered_rounded,
                        child: Column(
                          children: [
                            for (var index = 0; index < steps.length; index++) ...[
                              _GuidanceStepTile(
                                stepNumber: index + 1,
                                text: steps[index],
                              ),
                              if (index != steps.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (mistakes.isNotEmpty) ...[
                      if (steps.isNotEmpty) const SizedBox(height: 14),
                      _GuidanceSection(
                        title: 'Errores comunes',
                        icon: Icons.error_outline_rounded,
                        child: Column(
                          children: [
                            for (var index = 0; index < mistakes.length; index++) ...[
                              _GuidanceBulletTile(text: mistakes[index]),
                              if (index != mistakes.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (tips.isNotEmpty) ...[
                      if (steps.isNotEmpty || mistakes.isNotEmpty)
                        const SizedBox(height: 14),
                      _GuidanceSection(
                        title: 'Consejos',
                        icon: Icons.tips_and_updates_outlined,
                        child: Column(
                          children: [
                            for (var index = 0; index < tips.length; index++) ...[
                              _GuidanceBulletTile(text: tips[index]),
                              if (index != tips.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (exercise.variants.isNotEmpty) ...[
                      if (steps.isNotEmpty ||
                          mistakes.isNotEmpty ||
                          tips.isNotEmpty)
                        const SizedBox(height: 14),
                      _GuidanceSection(
                        title: 'Variantes',
                        icon: Icons.alt_route_rounded,
                        child: Column(
                          children: [
                            for (var index = 0;
                                index < exercise.variants.length;
                                index++) ...[
                              _GuidanceBulletTile(
                                text: exercise.variants[index].description
                                        .trim()
                                        .isNotEmpty
                                    ? '${exercise.variants[index].name}: ${exercise.variants[index].description.trim()}'
                                    : exercise.variants[index].name,
                              ),
                              if (index != exercise.variants.length - 1)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class _GuidanceSection extends StatelessWidget {
  const _GuidanceSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cfSoftSurface,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(color: context.cfBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: context.cfPrimary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _GuidanceStepTile extends StatelessWidget {
  const _GuidanceStepTile({required this.stepNumber, required this.text});

  final int stepNumber;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.cfPrimaryTint,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
          ),
          child: Text(
            '$stepNumber',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: context.cfPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.cfTextPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _GuidanceBulletTile extends StatelessWidget {
  const _GuidanceBulletTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: context.cfPrimary,
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.cfTextPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}