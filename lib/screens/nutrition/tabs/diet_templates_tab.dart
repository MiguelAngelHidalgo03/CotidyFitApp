import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/diet_template_model.dart';
import '../../../models/price_tier.dart';
import '../../../services/diet_template_selection_local_service.dart';
import '../../../services/diet_templates_local_service.dart';
import '../../../services/diet_templates_repository.dart';
import '../../../widgets/nutrition/diet_template_card.dart';
import '../../../widgets/nutrition/premium_personalized_diet_card.dart';
import '../../../widgets/progress/progress_section_card.dart';

class DietTemplatesTab extends StatefulWidget {
  const DietTemplatesTab({super.key});

  @override
  State<DietTemplatesTab> createState() => _DietTemplatesTabState();
}

class _DietTemplatesTabState extends State<DietTemplatesTab> {
  final DietTemplatesRepository _repo = DietTemplatesLocalService();
  final _selection = DietTemplateSelectionLocalService();

  bool _loading = true;
  List<DietTemplateModel> _templates = const [];
  String? _selectedId;
  Set<PriceTier> _priceTiers = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final templates = await _repo.getTemplates();
    final selected = await _selection.getSelectedTemplateId();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _selectedId = selected;
      _loading = false;
    });
  }

  Future<void> _useTemplate(DietTemplateModel template) async {
    await _selection.setSelectedTemplateId(template.id);
    if (!mounted) return;
    setState(() => _selectedId = template.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Plantilla seleccionada: ${template.kind.label}')),
    );
  }

  void _togglePriceTier(PriceTier v) {
    setState(() {
      _priceTiers = _priceTiers.contains(v)
          ? (_priceTiers.toSet()..remove(v))
          : (_priceTiers.toSet()..add(v));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final list = _priceTiers.isEmpty
        ? _templates
        : _templates.where((t) => _priceTiers.contains(t.priceTier)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        ProgressSectionCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sell_outlined, color: CFColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Precio',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  TextButton(
                    onPressed: _priceTiers.isEmpty ? null : () => setState(() => _priceTiers = const {}),
                    child: const Text('Limpiar'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final v in PriceTier.values)
                    _PricePill(
                      label: v.label,
                      selected: _priceTiers.contains(v),
                      onTap: () => _togglePriceTier(v),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final t in list) ...[
          DietTemplateCard(
            template: t,
            onUseTemplate: () => _useTemplate(t),
          ),
          const SizedBox(height: 12),
        ],
        PremiumPersonalizedDietCard(
          onCta: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Premium: próximamente')),
            );
          },
        ),
        if (_selectedId != null) const SizedBox(height: 4),
      ],
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? CFColors.primary.withValues(alpha: 0.12) : CFColors.background,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(color: selected ? CFColors.primary : CFColors.softGray),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16, color: CFColors.primary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? CFColors.primary : CFColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
