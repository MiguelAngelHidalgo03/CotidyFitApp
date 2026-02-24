import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../models/nutrition_template_model.dart';
import '../../../services/nutrition_templates_firestore_service.dart';
import '../../../widgets/nutrition/nutrition_template_card.dart';
import '../../../widgets/progress/progress_section_card.dart';
import '../widgets/template_detail_bottom_sheet.dart';

/// Shows templates the current user has liked.
class FavoriteTemplatesTab extends StatefulWidget {
  const FavoriteTemplatesTab({super.key});

  @override
  State<FavoriteTemplatesTab> createState() => _FavoriteTemplatesTabState();
}

class _FavoriteTemplatesTabState extends State<FavoriteTemplatesTab> {
  final _templatesDb = NutritionTemplatesFirestoreService();

  bool _loading = true;
  String? _error;
  List<NutritionTemplateModel> _items = const [];
  Set<String> _likedIds = const {};
  Map<String, int> _ratings = const {};

  bool get _firebaseReady {
    if (Firebase.apps.isEmpty) return false;
    return FirebaseAuth.instance.currentUser != null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_firebaseReady) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final allTemplatesStream = _templatesDb.watchTemplates(limit: 200);
      final allTemplates = await allTemplatesStream.first
          .timeout(const Duration(seconds: 10));

      final ids = [for (final t in allTemplates) t.id];
      final userInteractions = await _templatesDb
          .getUserInteractions(templateIds: ids)
          .timeout(const Duration(seconds: 10));

      final liked = allTemplates
          .where((t) => userInteractions.likedTemplateIds.contains(t.id))
          .toList();

      if (!mounted) return;
      setState(() {
        _items = liked;
        _likedIds = userInteractions.likedTemplateIds;
        _ratings = userInteractions.ratingByTemplateId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error al cargar plantillas favoritas: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_firebaseReady) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ProgressSectionCard(
          child: Text('Inicia sesión para ver tus plantillas favoritas.'),
        ),
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_error!,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plantillas favoritas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Dale like a plantillas para verlas aquí.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final t = _items[index];
          return NutritionTemplateCard(
            template: t,
            liked: _likedIds.contains(t.id),
            myRating: _ratings[t.id],
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => TemplateDetailBottomSheet(
                template: t,
                currentUser: currentUser,
              ),
            ),
            onToggleLike: () async {
              await _templatesDb.toggleLike(templateId: t.id);
              if (!mounted) return;
              await _load();
            },
            onRate: (v) async {
              await _templatesDb.setRating(templateId: t.id, rating: v);
              if (!mounted) return;
              await _load();
            },
          );
        },
      ),
    );
  }
}
