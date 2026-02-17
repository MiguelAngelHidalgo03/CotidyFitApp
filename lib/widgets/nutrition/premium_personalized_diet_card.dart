import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../progress/progress_section_card.dart';

class PremiumPersonalizedDietCard extends StatelessWidget {
  const PremiumPersonalizedDietCard({super.key, required this.onCta});

  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return ProgressSectionCard(
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
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(color: CFColors.softGray),
                ),
                child: const Icon(Icons.lock_outline, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dieta personalizada (Premium)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Vista previa (bloqueada):',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const _Feature(text: 'Cálculo automático de calorías'),
          const _Feature(text: 'Macros personalizados'),
          const _Feature(text: 'Preferencias alimenticias'),
          const _Feature(text: 'Sustituciones inteligentes'),
          const _Feature(text: 'Ajuste automático mensual'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCta,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Activar Premium'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.lock, size: 18, color: CFColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
