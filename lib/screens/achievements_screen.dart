import 'package:flutter/material.dart';

import '../services/achievements_service.dart';
import '../widgets/progress/progress_achievements_card.dart';
import '../widgets/progress/progress_section_card.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _service = AchievementsService();
  bool _loading = true;
  List<AchievementViewItem> _items = const [];

  static const String _all = '__all__';
  static const String _diffEasy = 'easy';
  static const String _diffMedium = 'medium';
  static const String _diffHard = 'hard';

  static const String _statusUnlocked = 'unlocked';
  static const String _statusLocked = 'locked';

  String _difficulty = _all;
  String _category = _all;
  String _status = _all;
  List<String> _categories = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _service.getAchievementsForCurrentUser();
    if (!mounted) return;
    setState(() {
      _items = items;
      _categories = _extractCategories(items);
      if (_category != _all && !_categories.contains(_category)) {
        _category = _all;
      }
      _loading = false;
    });
  }

  List<String> _extractCategories(List<AchievementViewItem> items) {
    final set = <String>{};
    for (final it in items) {
      set.add(_normalizeCategory(it.catalog.category));
    }
    final out = set.toList();
    out.sort((a, b) => _categoryLabel(a).compareTo(_categoryLabel(b)));
    return out;
  }

  String _normalizeCategory(String raw) {
    final c = raw.trim();
    return c.isEmpty ? 'General' : c;
  }

  String _categoryLabel(String category) {
    final c = category.trim();
    switch (c) {
      case 'entrenamiento':
        return 'Entrenamiento';
      case 'racha':
        return 'Racha';
      case 'hidratacion':
        return 'Hidratación';
      case 'meditacion':
        return 'Meditación';
      case 'programas':
        return 'Programas';
      case 'pasos':
        return 'Pasos';
      case 'actividad':
        return 'Actividad';
      case 'nutricion':
        return 'Nutrición';
      case 'bienestar':
        return 'Bienestar';
      case 'cotidyfit':
        return 'CotidyFit';
      case 'peso':
        return 'Peso';
      case 'General':
        return 'General';
      default:
        if (c.isEmpty) return 'General';
        return c[0].toUpperCase() + c.substring(1);
    }
  }

  String _difficultyFor(AchievementViewItem item) {
    final explicit = item.catalog.difficulty.trim().toLowerCase();
    if (explicit == _diffEasy || explicit == _diffMedium || explicit == _diffHard) {
      return explicit;
    }

    final t = item.catalog.conditionType.trim();
    final v = item.catalog.conditionValue;

    if (v <= 0) return _diffEasy;

    switch (t) {
      case 'workouts_completed':
        return v <= 5
            ? _diffEasy
            : (v <= 25 ? _diffMedium : _diffHard);
      case 'streak_days':
        return v <= 7
            ? _diffEasy
            : (v <= 30 ? _diffMedium : _diffHard);
      case 'water_ml':
        return v <= 2000
            ? _diffEasy
            : (v <= 2500 ? _diffMedium : _diffHard);
      case 'water_days_2000ml':
        return v <= 7
            ? _diffEasy
            : (v <= 14 ? _diffMedium : _diffHard);
      case 'meditation_days':
        return v <= 5
            ? _diffEasy
            : (v <= 25 ? _diffMedium : _diffHard);
      case 'weekly_program_completed':
        return v <= 1
            ? _diffEasy
            : (v <= 4 ? _diffMedium : _diffHard);
      case 'steps_total':
        return v <= 50000
            ? _diffEasy
            : (v <= 300000 ? _diffMedium : _diffHard);
      case 'steps_best_day':
        return v <= 8000
            ? _diffEasy
            : (v <= 16000 ? _diffMedium : _diffHard);
      case 'steps_days_8000':
        return v <= 7
            ? _diffEasy
            : (v <= 30 ? _diffMedium : _diffHard);
      case 'active_minutes_total':
        return v <= 300
            ? _diffEasy
            : (v <= 1200 ? _diffMedium : _diffHard);
      case 'active_minutes_days_30':
        return v <= 7
            ? _diffEasy
            : (v <= 30 ? _diffMedium : _diffHard);
      case 'meals_complete_days':
        return v <= 7
            ? _diffEasy
            : (v <= 30 ? _diffMedium : _diffHard);
      case 'checkins_days':
        return v <= 7
            ? _diffEasy
            : (v <= 30 ? _diffMedium : _diffHard);
      case 'cf_best_day':
        return v <= 70
            ? _diffEasy
            : (v <= 80 ? _diffMedium : _diffHard);
      case 'weight_entries':
        return v <= 7
            ? _diffEasy
            : (v <= 30 ? _diffMedium : _diffHard);
      default:
        return v <= 10
            ? _diffEasy
            : (v <= 50 ? _diffMedium : _diffHard);
    }
  }

  List<AchievementViewItem> _applyFilters(List<AchievementViewItem> items) {
    final filtered = <AchievementViewItem>[];

    for (final it in items) {
      if (_status == _statusUnlocked && !it.user.unlocked) continue;
      if (_status == _statusLocked && it.user.unlocked) continue;
      if (_difficulty != _all && _difficultyFor(it) != _difficulty) continue;

      final category = _normalizeCategory(it.catalog.category);
      if (_category != _all && category != _category) continue;

      filtered.add(it);
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logros')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    ProgressSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtrar',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _difficulty,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Dificultad',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: _all,
                                      child: Text('Todas'),
                                    ),
                                    DropdownMenuItem(
                                      value: _diffEasy,
                                      child: Text('Fácil'),
                                    ),
                                    DropdownMenuItem(
                                      value: _diffMedium,
                                      child: Text('Media'),
                                    ),
                                    DropdownMenuItem(
                                      value: _diffHard,
                                      child: Text('Difícil'),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() => _difficulty = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _category,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: _all,
                                      child: Text('Todos'),
                                    ),
                                    for (final c in _categories)
                                      DropdownMenuItem(
                                        value: c,
                                        child: Text(_categoryLabel(c)),
                                      ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() => _category = v);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _status,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Estado',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: _all,
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem(
                                value: _statusUnlocked,
                                child: Text('Desbloqueado'),
                              ),
                              DropdownMenuItem(
                                value: _statusLocked,
                                child: Text('Bloqueado'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _status = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ProgressAchievementsCard(
                      items: _applyFilters(_items),
                      emptyMessage: _items.isEmpty
                          ? 'No hay logros configurados todavía.'
                          : 'No hay logros que coincidan con estos filtros.',
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
