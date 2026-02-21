import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/theme.dart';
import '../../../models/diet_template_model.dart';
import '../../../models/nutrition_template_model.dart';
import '../../../models/price_tier.dart';
import '../../../services/diet_template_selection_local_service.dart';
import '../../../services/diet_templates_local_service.dart';
import '../../../services/diet_templates_repository.dart';
import '../../../services/nutrition_templates_firestore_service.dart';
import '../../../widgets/nutrition/diet_template_card.dart';
import '../../../widgets/nutrition/nutrition_template_card.dart';
import '../../../widgets/nutrition/premium_personalized_diet_card.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../widgets/template_detail_bottom_sheet.dart';

class DietTemplatesTab extends StatefulWidget {
  const DietTemplatesTab({super.key});

  @override
  State<DietTemplatesTab> createState() => _DietTemplatesTabState();
}

class _DietTemplatesTabState extends State<DietTemplatesTab> {
  final DietTemplatesRepository _repo = DietTemplatesLocalService();
  final _selection = DietTemplateSelectionLocalService();
  final _templatesDb = NutritionTemplatesFirestoreService();

  bool _loading = true;
  List<DietTemplateModel> _templates = const [];
  String? _selectedId;
  Set<PriceTier> _priceTiers = const {};

  Set<String> _dietTypes = const {};
  Set<String> _goalTags = const {};

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

  void _toggleDietType(String v) {
    setState(() {
      _dietTypes = _dietTypes.contains(v)
          ? (_dietTypes.toSet()..remove(v))
          : (_dietTypes.toSet()..add(v));
    });
  }

  void _toggleGoalTag(String v) {
    setState(() {
      _goalTags = _goalTags.contains(v)
          ? (_goalTags.toSet()..remove(v))
          : (_goalTags.toSet()..add(v));
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

    final firebaseReady = Firebase.apps.isNotEmpty;
    final currentUser = firebaseReady ? FirebaseAuth.instance.currentUser : null;

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
                    onPressed: (_priceTiers.isEmpty && _dietTypes.isEmpty && _goalTags.isEmpty)
                        ? null
                        : () => setState(() {
                            _priceTiers = const {};
                            _dietTypes = const {};
                            _goalTags = const {};
                          }),
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

              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.restaurant_menu, color: CFColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tipo de alimentación',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FilterPill(
                    label: 'Vegetariano',
                    selected: _dietTypes.contains('vegetariano'),
                    onTap: () => _toggleDietType('vegetariano'),
                  ),
                  _FilterPill(
                    label: 'Vegano',
                    selected: _dietTypes.contains('vegano'),
                    onTap: () => _toggleDietType('vegano'),
                  ),
                  _FilterPill(
                    label: 'Sin gluten',
                    selected: _dietTypes.contains('sin_gluten'),
                    onTap: () => _toggleDietType('sin_gluten'),
                  ),
                  _FilterPill(
                    label: 'Omnívoro',
                    selected: _dietTypes.contains('omnivoro'),
                    onTap: () => _toggleDietType('omnivoro'),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.flag_outlined, color: CFColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Objetivo',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FilterPill(
                    label: 'Pérdida de peso',
                    selected: _goalTags.contains('perdida_peso'),
                    onTap: () => _toggleGoalTag('perdida_peso'),
                  ),
                  _FilterPill(
                    label: 'Alta proteína',
                    selected: _goalTags.contains('alta_proteina'),
                    onTap: () => _toggleGoalTag('alta_proteina'),
                  ),
                  _FilterPill(
                    label: 'Saciante',
                    selected: _goalTags.contains('saciante'),
                    onTap: () => _toggleGoalTag('saciante'),
                  ),
                  _FilterPill(
                    label: 'Volumen',
                    selected: _goalTags.contains('volumen'),
                    onTap: () => _toggleGoalTag('volumen'),
                  ),
                  _FilterPill(
                    label: 'Saludable',
                    selected: _goalTags.contains('saludable'),
                    onTap: () => _toggleGoalTag('saludable'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (firebaseReady) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Text(
              'Plantillas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          StreamBuilder<List<NutritionTemplateModel>>(
            stream: _templatesDb.watchTemplates(limit: 60),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final raw = snap.data ?? const <NutritionTemplateModel>[];
              final filtered = raw.where((t) {
                if (_priceTiers.isNotEmpty && !_priceTiers.contains(t.priceTier)) {
                  return false;
                }
                if (_dietTypes.isNotEmpty) {
                  final dt = t.dietType.trim().toLowerCase();
                  if (dt.isEmpty || !_dietTypes.contains(dt)) return false;
                }
                if (_goalTags.isNotEmpty) {
                  final tags = {for (final g in t.goalTags) g.trim().toLowerCase()};
                  final ok = _goalTags.any((g) => tags.contains(g));
                  if (!ok) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return const ProgressSectionCard(
                  child: Text('Sin resultados con los filtros actuales.'),
                );
              }

              final ids = [for (final t in filtered) t.id];
              return FutureBuilder<TemplateInteractions>(
                future: _templatesDb.getUserInteractions(templateIds: ids),
                builder: (context, interactionsSnap) {
                  final interactions = interactionsSnap.data ??
                      const TemplateInteractions(
                        likedTemplateIds: <String>{},
                        ratingByTemplateId: <String, int>{},
                      );

                  return Column(
                    children: [
                      for (final t in filtered) ...[
                        NutritionTemplateCard(
                          template: t,
                          liked: interactions.likedTemplateIds.contains(t.id),
                          myRating: interactions.ratingByTemplateId[t.id],
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => TemplateDetailBottomSheet(
                              template: t,
                              currentUser: currentUser,
                            ),
                          ),
                          onToggleLike: currentUser == null
                              ? () => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Inicia sesión para dar like.')),
                                  )
                              : () async {
                                  await _templatesDb.toggleLike(templateId: t.id);
                                  if (!mounted) return;
                                  setState(() {});
                                },
                          onRate: currentUser == null
                              ? (_) => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Inicia sesión para valorar.')),
                                  )
                              : (v) async {
                                  await _templatesDb.setRating(templateId: t.id, rating: v);
                                  if (!mounted) return;
                                  setState(() {});
                                },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 6),
        ],

        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Text(
            'Plantillas rápidas',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});

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
