import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/subscription_service.dart';
import '../progress/progress_section_card.dart';

class TrainingPremiumCard extends StatelessWidget {
  const TrainingPremiumCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SubscriptionService.hasAccess(),
      builder: (context, snapshot) {
        final hasAccess = snapshot.data == true;

        return ProgressSectionCard(
          backgroundColor: CFColors.primary.withValues(alpha: 0.04),
          borderColor: CFColors.primary.withValues(alpha: 0.18),
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
                    child: Icon(
                      hasAccess ? Icons.verified_outlined : Icons.lock_outline,
                      color: CFColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Premium',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Line(text: 'Plan personalizado automático'),
              _Line(text: 'Progresión inteligente'),
              _Line(text: 'Ajuste según rendimiento'),
              _Line(text: 'Estadísticas avanzadas'),
              _Line(text: 'Rutinas desbloqueadas'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: hasAccess
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Premium estará disponible próximamente.',
                              ),
                            ),
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: CFColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    hasAccess ? 'Premium activo' : 'Desbloquear Premium',
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: CFColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
