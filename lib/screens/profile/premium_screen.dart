import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/subscription_service.dart';
import '../../widgets/progress/progress_section_card.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SubscriptionService.hasAccess(),
      builder: (context, snapshot) {
        final hasAccess = snapshot.data ?? false;

        return Scaffold(
          appBar: AppBar(title: const Text('Premium')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Premium',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ProgressSectionCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: context.cfSurface,
                  borderColor: context.cfBorder,
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
                              borderRadius: const BorderRadius.all(
                                Radius.circular(16),
                              ),
                              border: Border.all(
                                color: context.cfPrimaryTintStrong,
                              ),
                            ),
                            child: Icon(
                              Icons.workspace_premium_outlined,
                              color: context.cfPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              hasAccess ? 'Plan Premium' : 'Plan gratuito',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: context.cfTextPrimary,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: hasAccess
                                  ? context.cfPrimaryTint
                                  : context.cfSoftSurface,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(999),
                              ),
                              border: Border.all(
                                color: hasAccess
                                    ? context.cfPrimaryTintStrong
                                    : context.cfBorder,
                              ),
                            ),
                            child: Text(
                              hasAccess ? 'Activo' : 'Bloqueado',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: hasAccess
                                        ? context.cfPrimary
                                        : context.cfTextSecondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Beneficios',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const _BenefitRow(text: 'Gráficas avanzadas'),
                      const SizedBox(height: 8),
                      const _BenefitRow(text: 'Comparativas mensuales'),
                      const SizedBox(height: 8),
                      const _BenefitRow(text: 'Análisis automático'),
                      const SizedBox(height: 8),
                      const _BenefitRow(text: 'Recomendaciones personalizadas'),
                      const SizedBox(height: 14),
                      Text(
                        'Precios',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Próximamente',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.cfTextSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                          child: Text(
                            hasAccess ? 'Premium activo' : 'Activar Premium',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        const Icon(
          Icons.check_circle_outline,
          size: 18,
          color: CFColors.primary,
        ),
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
