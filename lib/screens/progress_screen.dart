import 'package:flutter/material.dart';

import '../models/progress_week_summary.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import '../services/local_storage_service.dart';
import '../services/profile_service.dart';
import '../services/progress_service.dart';
import '../services/progress_week_summary_service.dart';
import '../services/weight_service.dart';
import '../utils/date_utils.dart';
import '../widgets/progress/header_profile.dart';
import '../widgets/progress/progress_constancy_card.dart';
import '../widgets/progress/progress_health_summary_card.dart';
import '../widgets/progress/progress_insights_section.dart';
import '../widgets/progress/progress_nutrition_compliance_card.dart';
import '../widgets/progress/progress_premium_card.dart';
import '../widgets/progress/progress_smart_tracking_card.dart';
import '../widgets/progress/progress_weight_summary_card.dart';
import 'profile_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final LocalStorageService _storage;
  late final ProgressService _service;
  late final WeightService _weightService;
  late final ProfileService _profiles;
  late final ProgressWeekSummaryService _weekSummaryService;

  ProgressData? _data;
  WeightSummary? _weight;
  Map<String, int> _cfHistory = const {};
  UserProfile? _profile;
  ProgressWeekSummary? _weekSummary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _storage = LocalStorageService();
    _service = ProgressService(storage: _storage);
    _weightService = WeightService();
    _profiles = ProfileService();
    _weekSummaryService = ProgressWeekSummaryService(storage: _storage);

    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _service.loadProgress(days: 7);
    final weight = await _weightService.getSummary(maxPoints: 30);
    final history = await _storage.getCfHistory();
    final profile = await _profiles.getOrCreateProfile();
    final weekSummary = await _weekSummaryService.getCurrentWeekSummary();
    if (!mounted) return;
    setState(() {
      _data = data;
      _weight = weight;
      _cfHistory = history;
      _profile = profile;
      _weekSummary = weekSummary;
      _loading = false;
    });
  }

  Future<void> _addWeightFlow() async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir peso'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: false,
            ),
            decoration: const InputDecoration(
              hintText: 'Ej: 72.5',
              suffixText: 'kg',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final raw = controller.text.trim().replaceAll(',', '.');
                final value = double.tryParse(raw);
                if (value == null || value <= 0) return;
                Navigator.of(context).pop(value);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    await _weightService.upsertToday(result);
    final weight = await _weightService.getSummary(maxPoints: 30);
    if (!mounted) return;
    setState(() => _weight = weight);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final weekSummary = _weekSummary;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : data == null || weekSummary == null
                ? Center(
                    child: Text(
                      'No hay datos aún.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: _buildBody(context, data, weekSummary),
                    ),
                  ),
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    ProgressData data,
    ProgressWeekSummary weekSummary,
  ) {
    final monthAverage = _monthAverageCf(DateTime.now(), _cfHistory);
    final maxStreak = _maxStreakFromHistory(_cfHistory);

    final weight = _weight;
    final latest = weight?.latest;
    final last30 = (weight?.history ?? const <WeightEntry>[]).toList();
    final weekDiff = weight?.diffFromWeekBefore;
    final monthDiff = _diffFromDaysBefore(last30, days: 30);

    final insights = _buildWeeklyAnalysis(data: data, weekSummary: weekSummary);

    return [
      HeaderProfile(
        profile: _profile,
        onOpenProfile: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
      ),
      const SizedBox(height: 14),
      ProgressConstancyCard(
        weekPoints: data.last7Days,
        monthCf: monthAverage,
        maxStreak: maxStreak,
      ),
      const SizedBox(height: 14),
      ProgressHealthSummaryCard(summary: weekSummary),
      const SizedBox(height: 14),
      ProgressWeightSummaryCard(
        latest: latest,
        weekDiffKg: weekDiff,
        monthDiffKg: monthDiff,
        last30Days: last30,
        onAdd: _addWeightFlow,
      ),
      const SizedBox(height: 14),
      ProgressNutritionComplianceCard(summary: weekSummary),
      const SizedBox(height: 14),
      ProgressSmartTrackingCard(summary: weekSummary),
      const SizedBox(height: 14),
      ProgressInsightsSection(insights: insights),
      const SizedBox(height: 14),
      const ProgressPremiumCard(),
      const SizedBox(height: 10),
    ];
  }

  int _monthAverageCf(DateTime focusedMonth, Map<String, int> history) {
    final values = <int>[];
    for (final e in history.entries) {
      final d = DateUtilsCF.fromKey(e.key);
      if (d == null) continue;
      if (d.year != focusedMonth.year || d.month != focusedMonth.month) continue;
      if (e.value <= 0) continue;
      values.add(e.value);
    }
    if (values.isEmpty) return 0;
    final sum = values.fold<int>(0, (a, b) => a + b);
    return (sum / values.length).round().clamp(0, 100);
  }

  int _maxStreakFromHistory(Map<String, int> history) {
    final days = <DateTime>[];
    for (final e in history.entries) {
      if (e.value <= 0) continue;
      final d = DateUtilsCF.fromKey(e.key);
      if (d != null) days.add(DateUtilsCF.dateOnly(d));
    }
    if (days.isEmpty) return 0;
    days.sort((a, b) => a.compareTo(b));

    var best = 1;
    var current = 1;
    for (var i = 1; i < days.length; i++) {
      final diff = days[i].difference(days[i - 1]).inDays;
      if (diff == 1) {
        current += 1;
      } else if (diff == 0) {
        continue;
      } else {
        best = best > current ? best : current;
        current = 1;
      }
    }
    best = best > current ? best : current;
    return best;
  }

  List<ProgressInsight> _buildWeeklyAnalysis({
    required ProgressData data,
    required ProgressWeekSummary weekSummary,
  }) {
    final insights = <ProgressInsight>[];

    final today = DateUtilsCF.dateOnly(DateTime.now());
    final weekday = today.weekday; // Mon=1..Sun=7

    final activeDays = weekSummary.activeDays;
    final trainedMinutes = weekSummary.trainedMinutes;
    final hydrationPct = weekSummary.hydrationAveragePercent;
    final energyAvg = weekSummary.energyAverage;

    if (weekday <= DateTime.tuesday && activeDays == 0) {
      insights.add(const ProgressInsight(
        icon: Icons.rocket_launch_outlined,
        title: 'La semana acaba de empezar',
        description: 'Aún estás a tiempo: un entreno ligero hoy te pone en marcha.',
      ));
    } else if (activeDays >= 3 && data.average7Days >= 60) {
      insights.add(const ProgressInsight(
        icon: Icons.star_outline,
        title: 'Gran comienzo de semana',
        description: 'Buen ritmo. Mantén consistencia y tu CF lo reflejará.',
      ));
    } else if (activeDays <= 1 && weekday >= DateTime.thursday) {
      insights.add(const ProgressInsight(
        icon: Icons.fitness_center_outlined,
        title: 'Añade un entrenamiento ligero',
        description: 'Una sesión corta puede mejorar tu semana sin agotarte.',
      ));
    }

    if (hydrationPct < 60) {
      insights.add(const ProgressInsight(
        icon: Icons.water_drop_outlined,
        title: 'Hidratación baja',
        description: 'Prueba 2–3 recordatorios al día o añade 250 ml tras cada comida.',
      ));
    } else if (hydrationPct >= 85) {
      insights.add(const ProgressInsight(
        icon: Icons.water_drop_outlined,
        title: 'Hidratación sólida',
        description: 'Muy buen hábito esta semana. Eso ayuda a energía y recuperación.',
      ));
    }

    if (energyAvg != null && energyAvg <= 2.6) {
      insights.add(const ProgressInsight(
        icon: Icons.bedtime_outlined,
        title: 'Revisa tu descanso',
        description: 'Tu energía está baja. Prioriza sueño y un día más suave de entreno.',
      ));
    }

    final points = data.last7Days;
    if (points.length >= 6) {
      final a1 = ((points[0].value + points[1].value + points[2].value) / 3).round();
      final a2 = ((points[points.length - 3].value + points[points.length - 2].value + points[points.length - 1].value) / 3).round();
      if (a2 >= a1 + 8) {
        insights.add(const ProgressInsight(
          icon: Icons.trending_up,
          title: 'Tendencia al alza',
          description: 'Tu CF está subiendo. Repite lo que funcionó estos días.',
        ));
      } else if (a1 >= a2 + 8) {
        insights.add(const ProgressInsight(
          icon: Icons.trending_down,
          title: 'Bajada reciente',
          description: 'Vuelve a lo básico: agua, movimiento y una comida completa.',
        ));
      } else {
        insights.add(const ProgressInsight(
          icon: Icons.insights_outlined,
          title: 'Semana estable',
          description: 'Estás consistente. Un pequeño hábito puede empujarte hacia arriba.',
        ));
      }
    }

    if (trainedMinutes >= 120) {
      insights.add(const ProgressInsight(
        icon: Icons.timer_outlined,
        title: 'Volumen semanal alto',
        description: 'Buen total de minutos. Recuerda alternar intensidad y recuperación.',
      ));
    }

    if (insights.isEmpty) {
      insights.add(const ProgressInsight(
        icon: Icons.insights_outlined,
        title: 'Sigue registrando',
        description: 'Con 2–3 días más de datos, tu análisis semanal será más preciso.',
      ));
    }

    if (insights.length > 4) return insights.sublist(0, 4);
    return insights;
  }

  double? _diffFromDaysBefore(List<WeightEntry> history, {required int days}) {
    if (history.isEmpty) return null;

    final latest = history.last;
    final target = latest.date.subtract(Duration(days: days));

    WeightEntry? candidate;
    for (var i = history.length - 1; i >= 0; i--) {
      final e = history[i];
      if (!e.date.isAfter(target)) {
        candidate = e;
        break;
      }
    }
    if (candidate == null) return null;
    return latest.weight - candidate.weight;
  }
}

