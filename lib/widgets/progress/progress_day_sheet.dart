import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'progress_section_card.dart';

class ProgressDayDetails {
  final DateTime day;
  final int cf;
  final String? workoutName;

  const ProgressDayDetails({
    required this.day,
    required this.cf,
    required this.workoutName,
  });
}

class ProgressDaySheet extends StatelessWidget {
  const ProgressDaySheet({super.key, required this.details});

  final ProgressDayDetails details;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _format(details.day);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ProgressSectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: CFColors.primary.withValues(alpha: 0.10),
                      borderRadius: const BorderRadius.all(Radius.circular(999)),
                      border: Border.all(color: CFColors.primary.withValues(alpha: 0.16)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'CF ${details.cf}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: CFColors.primary,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Row(
                title: 'Entrenamientos',
                value: details.workoutName == null ? '—' : details.workoutName!,
                icon: Icons.fitness_center,
              ),
              const SizedBox(height: 10),
              const _Row(
                title: 'Energía registrada',
                value: '—',
                icon: Icons.bolt,
              ),
              const SizedBox(height: 10),
              const _Row(
                title: 'Nutrición cumplida',
                value: '—',
                icon: Icons.restaurant,
              ),
              const SizedBox(height: 10),
              const _Row(
                title: 'Notas',
                value: 'Próximamente',
                icon: Icons.notes,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(DateTime d) {
    const months = <String>[
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${d.day} de ${months[d.month - 1]} de ${d.year}';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: CFColors.background,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: CFColors.softGray),
          ),
          child: Icon(icon, color: CFColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: CFColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
