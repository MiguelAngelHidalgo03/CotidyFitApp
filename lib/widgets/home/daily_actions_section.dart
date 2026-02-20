import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/daily_data_model.dart';
import '../../services/daily_data_service.dart';

class DailyActionsSection extends StatelessWidget {
  const DailyActionsSection({
    super.key,
    required this.data,
    required this.workoutCompleted,
    required this.mealsLoggedCount,
    required this.completedCount,
    required this.totalCount,
    required this.completedToday,
    required this.onGoToNutrition,
    required this.onGoToTraining,
    required this.onSetSteps,
    required this.onSetActiveMinutes,
    required this.onSetWaterLiters,
    required this.onToggleStretches,
    required this.onConfirm,
  });

  final DailyDataModel data;
  final bool workoutCompleted;
  final int mealsLoggedCount;
  final int completedCount;
  final int totalCount;
  final bool completedToday;
  final VoidCallback onGoToNutrition;
  final VoidCallback onGoToTraining;
  final ValueChanged<int> onSetSteps;
  final ValueChanged<int> onSetActiveMinutes;
  final ValueChanged<double> onSetWaterLiters;
  final Future<void> Function() onToggleStretches;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final total = totalCount <= 0 ? 1 : totalCount;
    final done = completedCount.clamp(0, total);
    final progress = done / total;

    return Container(
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.all(color: CFColors.softGray),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Qué has hecho hoy?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'Entrenamiento',
            subtitle: workoutCompleted ? 'Completado' : 'Ir a Entrenamiento',
            icon: Icons.fitness_center_outlined,
            completed: workoutCompleted,
            disabled: false,
            onTap: onGoToTraining,
          ),
          const SizedBox(height: 10),
          _ActionCard(
            title: 'Pasos',
            subtitle: '${data.steps} / ${DailyDataService.stepsTarget}',
            icon: Icons.directions_walk_outlined,
            completed: data.steps >= DailyDataService.stepsTarget,
            disabled: completedToday,
            onTap: () => _editInt(
              context: context,
              title: 'Pasos',
              hint: 'Ej: 8200',
              initial: data.steps,
              onSave: onSetSteps,
            ),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            title: 'Min activos',
            subtitle: '${data.activeMinutes} / ${DailyDataService.activeMinutesTarget}',
            icon: Icons.timer_outlined,
            completed: data.activeMinutes >= DailyDataService.activeMinutesTarget,
            disabled: completedToday,
            onTap: () => _editInt(
              context: context,
              title: 'Min activos',
              hint: 'Ej: 30',
              initial: data.activeMinutes,
              onSave: onSetActiveMinutes,
            ),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            title: 'Agua',
            subtitle: '${_fmtLiters(data.waterLiters)} / ${DailyDataService.waterLitersTarget.toStringAsFixed(1)} L',
            icon: Icons.water_drop_outlined,
            completed: data.waterLiters >= DailyDataService.waterLitersTarget,
            disabled: completedToday,
            onTap: () => _editDouble(
              context: context,
              title: 'Agua (litros)',
              hint: 'Ej: 2.5',
              initial: data.waterLiters,
              onSave: onSetWaterLiters,
            ),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            title: 'Comidas',
            subtitle: '$mealsLoggedCount / ${DailyDataService.mealsTarget} (desde Nutrición)',
            icon: Icons.restaurant_outlined,
            completed: mealsLoggedCount >= DailyDataService.mealsTarget,
            disabled: false,
            onTap: onGoToNutrition,
          ),
          const SizedBox(height: 10),
          _ActionCard(
            title: 'Estiramientos',
            subtitle: data.stretchesDone ? 'Hecho' : 'Marcar como hecho',
            icon: Icons.self_improvement_outlined,
            completed: data.stretchesDone,
            disabled: completedToday,
            onTap: () async {
              await onToggleStretches();
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: CFColors.softGray,
                    valueColor: const AlwaysStoppedAnimation(CFColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$done/$total',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: completedToday
                  ? null
                  : () async {
                      await onConfirm();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Día registrado. Cada día cuenta.')),
                      );
                    },
              child: Text(completedToday ? 'Hoy ya está completado' : 'Confirmar día'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editInt({
    required BuildContext context,
    required String title,
    required String hint,
    required int initial,
    required ValueChanged<int> onSave,
  }) async {
    if (completedToday) return;

    final controller = TextEditingController(text: initial <= 0 ? '' : '$initial');

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                    decoration: InputDecoration(
                      hintText: hint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final v = int.tryParse(controller.text.trim());
                        Navigator.of(ctx).pop(v ?? 0);
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;
    onSave(result);
  }

  Future<void> _editDouble({
    required BuildContext context,
    required String title,
    required String hint,
    required double initial,
    required ValueChanged<double> onSave,
  }) async {
    if (completedToday) return;

    final controller = TextEditingController(
      text: initial <= 0 ? '' : initial.toStringAsFixed(2),
    );

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                    decoration: InputDecoration(
                      hintText: hint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final raw = controller.text.trim().replaceAll(',', '.');
                        final v = double.tryParse(raw);
                        Navigator.of(ctx).pop(v ?? 0.0);
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;
    onSave(result);
  }
}

String _fmtLiters(double liters) {
  final l = liters < 0 ? 0 : liters;
  final s = l.toStringAsFixed((l * 100).round() % 10 == 0 ? 1 : 2);
  return '$s L';
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.completed,
    required this.disabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = disabled ? CFColors.textSecondary : CFColors.textPrimary;

    return Material(
      color: CFColors.surface,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            border: Border.all(color: CFColors.softGray),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CFColors.primary.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(color: CFColors.softGray),
                ),
                child: Icon(icon, color: CFColors.primary),
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
                            color: fg,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: CFColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: completed ? CFColors.primary.withValues(alpha: 0.12) : CFColors.softGray,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                    color: completed
                        ? CFColors.primary.withValues(alpha: 0.26)
                        : CFColors.softGray,
                  ),
                ),
                child: Icon(
                  completed ? Icons.check : Icons.add,
                  color: completed ? CFColors.primary : CFColors.textSecondary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
