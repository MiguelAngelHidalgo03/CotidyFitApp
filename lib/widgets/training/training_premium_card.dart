import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../progress/progress_section_card.dart';

class TrainingPremiumCard extends StatelessWidget {
  const TrainingPremiumCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CFColors.primary.withValues(alpha: 0.10),
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                    ),
                    child: const Icon(Icons.lock_outline, color: CFColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Entrenamiento Premium',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Line(text: 'Plan personalizado semanal'),
              _Line(text: 'Progresión automática'),
              _Line(text: 'Ajuste según rendimiento'),
              _Line(text: 'Estadísticas avanzadas'),
              _Line(text: 'Rutinas desbloqueadas'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: null,
                  child: const Text('Desbloquear (próximamente)'),
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: CFColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
