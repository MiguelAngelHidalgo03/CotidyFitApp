import 'package:flutter/material.dart';

import '../../../models/diet_template_model.dart';
import '../../../services/diet_template_selection_local_service.dart';
import '../../../services/diet_templates_local_service.dart';
import '../../../services/diet_templates_repository.dart';
import '../../../widgets/nutrition/diet_template_card.dart';
import '../../../widgets/nutrition/premium_personalized_diet_card.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        for (final t in _templates) ...[
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
