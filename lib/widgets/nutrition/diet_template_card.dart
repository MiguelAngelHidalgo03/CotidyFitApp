import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/diet_template_model.dart';
import '../progress/progress_section_card.dart';

class DietTemplateCard extends StatelessWidget {
  const DietTemplateCard({
    super.key,
    required this.template,
    required this.onUseTemplate,
  });

  final DietTemplateModel template;
  final VoidCallback onUseTemplate;

  IconData get _icon => switch (template.kind) {
        DietTemplateKind.fatLoss => Icons.local_fire_department_outlined,
        DietTemplateKind.maintenance => Icons.balance_outlined,
        DietTemplateKind.bulk => Icons.fitness_center_outlined,
      };

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
                child: Icon(_icon, color: CFColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  template.kind.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Calorías estimadas: ${template.estimatedCalories} kcal/día',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: CFColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MacroChip(label: 'Proteína', value: '${template.macros.proteinPct}%'),
              _MacroChip(label: 'Carbohidratos', value: '${template.macros.carbsPct}%'),
              _MacroChip(label: 'Grasas', value: '${template.macros.fatPct}%'),
            ],
          ),
          const SizedBox(height: 14),
          Text('Ejemplo de día', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...template.exampleDay.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• ${e.meal}: ${e.example}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Lista de compra automática', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: template.shoppingList.map((i) => _ItemChip(text: i)).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onUseTemplate,
              child: const Text('Usar plantilla'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CFColors.background,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: CFColors.textPrimary)),
          const SizedBox(width: 6),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textPrimary)),
    );
  }
}
