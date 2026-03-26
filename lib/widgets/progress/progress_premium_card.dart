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
        final statusBackground = hasAccess
            ? Colors.green.withValues(alpha: context.cfIsDark ? 0.16 : 0.12)
            : const Color(0xFFF59E0B).withValues(
                alpha: context.cfIsDark ? 0.18 : 0.12,
              );
        final statusBorder = hasAccess
            ? Colors.green.withValues(alpha: context.cfIsDark ? 0.32 : 0.35)
            : const Color(0xFFF59E0B).withValues(
                alpha: context.cfIsDark ? 0.40 : 0.45,
              );
        final statusText = hasAccess
            ? (context.cfIsDark ? const Color(0xFF86EFAC) : Colors.green.shade800)
            : (context.cfIsDark ? const Color(0xFFFCD34D) : Colors.amber.shade900);

        return ProgressSectionCard(
          backgroundColor: context.cfSoftSurface,
          borderColor: context.cfPrimaryTintStrong,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.cfPrimaryTint,
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      border: Border.all(color: context.cfPrimaryTintStrong),
                    ),
                    child: Icon(
                      hasAccess
                          ? Icons.workspace_premium_outlined
                          : Icons.lock_outline,
                      color: context.cfPrimary,
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
                      color: statusBackground,
                      borderRadius: const BorderRadius.all(Radius.circular(999)),
                      border: Border.all(color: statusBorder),
                    ),
                    child: Text(
                      hasAccess ? 'Activo' : 'Bloqueado',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: statusText,
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
        Icon(Icons.check_circle_outline, size: 18, color: context.cfPrimary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.cfTextPrimary,
                ),
          ),
        ),
      ],
    );
  }
}
