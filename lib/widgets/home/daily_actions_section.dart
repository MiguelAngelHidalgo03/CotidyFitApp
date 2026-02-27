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
    required this.onSetWaterLiters,
    required this.onAddWater250ml,
    required this.onSetMeditationMinutes,
    required this.onAddMeditation,
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
  final ValueChanged<double> onSetWaterLiters;
  final Future<void> Function() onAddWater250ml;
  final ValueChanged<int> onSetMeditationMinutes;
  final Future<void> Function() onAddMeditation;
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
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22),
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
            title: 'Agua',
            subtitle:
                '${_fmtLiters(data.waterLiters)} / ${DailyDataService.waterLitersTarget.toStringAsFixed(1)} L',
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
            trailing: _WaterTrailing(
              liters: data.waterLiters,
              disabled: completedToday,
              onAdd250ml: onAddWater250ml,
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
            title: 'Meditación',
            subtitle:
                '${data.meditationMinutes} / ${DailyDataService.meditationMinutesTarget} min',
            icon: Icons.self_improvement_outlined,
            completed: data.meditationMinutes >= DailyDataService.meditationMinutesTarget,
            disabled: completedToday,
            onTap: () => _editInt(
              context: context,
              title: 'Meditación (minutos)',
              hint: 'Ej: 10',
              initial: data.meditationMinutes,
              onSave: onSetMeditationMinutes,
            ),
            trailing: _QuickSmallButton(
              label: '+5 min',
              onTap: completedToday ? null : () async => onAddMeditation(),
            ),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
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
                    decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(int.tryParse(controller.text.trim()) ?? 0),
                      child: const Text('Guardar'),
                    ),
                  ),
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

    final controller = TextEditingController(text: initial <= 0 ? '' : initial.toStringAsFixed(2));
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
                    decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final raw = controller.text.trim().replaceAll(',', '.');
                        Navigator.of(ctx).pop(double.tryParse(raw) ?? 0.0);
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
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
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;
  final bool disabled;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
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
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              const SizedBox(width: 8),
              Icon(
                completed ? Icons.check_circle : Icons.chevron_right,
                color: completed ? CFColors.primary : CFColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickSmallButton extends StatelessWidget {
  const _QuickSmallButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: CFColors.primary.withValues(alpha: 0.12),
        foregroundColor: CFColors.primary,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _WaterTrailing extends StatelessWidget {
  const _WaterTrailing({
    required this.liters,
    required this.disabled,
    required this.onAdd250ml,
  });

  final double liters;
  final bool disabled;
  final Future<void> Function() onAdd250ml;

  @override
  Widget build(BuildContext context) {
    final ratio = (liters / DailyDataService.waterLitersTarget).clamp(0, 1).toDouble();
    final pct = (ratio * 100).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: ratio,
                strokeWidth: 4,
                backgroundColor: CFColors.softGray,
                valueColor: const AlwaysStoppedAnimation(CFColors.primary),
              ),
              Text(
                '$pct%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _QuickSmallButton(
          label: '+250ml',
          onTap: disabled ? null : () async => onAdd250ml(),
        ),
      ],
    );
  }
}
