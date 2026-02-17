import 'package:flutter/material.dart';

import '../../core/theme.dart';

class DailyActionsSection extends StatelessWidget {
  const DailyActionsSection({
    super.key,
    required this.actions,
    required this.selected,
    required this.completedToday,
    required this.onToggle,
    required this.onConfirm,
  });

  final List<String> actions;
  final Set<String> selected;
  final bool completedToday;
  final ValueChanged<String> onToggle;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final total = actions.isEmpty ? 1 : actions.length;
    final done = selected.length.clamp(0, total);
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
            '¿Qué has hecho hoy por tu salud?'
            ,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final a in actions)
                FilterChip(
                  label: Text(a),
                  selected: selected.contains(a),
                  onSelected: completedToday ? null : (_) => onToggle(a),
                  selectedColor: CFColors.primary.withValues(alpha: 0.12),
                  checkmarkColor: CFColors.primary,
                  side: const BorderSide(color: CFColors.softGray),
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: CFColors.textPrimary,
                      ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: const StadiumBorder(),
                ),
            ],
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
}
