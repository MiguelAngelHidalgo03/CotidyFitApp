import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/subscription_service.dart';
import 'progress_section_card.dart';

class ProgressPremiumCard extends StatelessWidget {
  const ProgressPremiumCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SubscriptionService.hasAccess(),
      builder: (context, snapshot) {
        final hasAccess = snapshot.data ?? false;

        return ProgressSectionCard(
          backgroundColor: CFColors.primary.withValues(alpha: 0.05),
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
                      hasAccess
                          ? Icons.workspace_premium_outlined
                          : Icons.lock_outline,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasAccess
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.amber.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.all(Radius.circular(999)),
                      border: Border.all(
                        color: hasAccess
                            ? Colors.green.withValues(alpha: 0.35)
                            : Colors.amber.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      hasAccess ? 'Activo' : 'Bloqueado',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: hasAccess
                                ? Colors.green.shade800
                                : Colors.amber.shade900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _BenefitRow(text: 'Gráficas avanzadas'),
              const SizedBox(height: 8),
              const _BenefitRow(text: 'Comparativas mensuales'),
              const SizedBox(height: 8),
              const _BenefitRow(text: 'Análisis automático'),
              const SizedBox(height: 8),
              const _BenefitRow(text: 'Recomendaciones personalizadas'),
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
                                'La activación de Premium no está disponible desde la app en esta versión.',
                              ),
                            ),
                          );
                        },
                  child: Text(hasAccess ? 'Premium activo' : 'Desbloquear Premium'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 18, color: CFColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: CFColors.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}
