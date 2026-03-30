import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';
import '../core/home_navigation.dart';
import '../models/cf_history_point.dart';
import '../models/progress_advanced_analytics.dart';
import '../models/user_profile.dart';
import '../screens/achievements_screen.dart';
import '../services/health_service.dart';
import '../services/local_storage_service.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../services/progress_service.dart';
import '../services/progress_advanced_analytics_service.dart';
import '../services/progress_week_summary_service.dart';
import '../services/weight_service.dart';
import '../widgets/common/inline_status_banner.dart';
import '../widgets/progress/header_profile.dart';
import '../widgets/progress/progress_advanced_dashboard.dart';
import '../widgets/progress/progress_premium_card.dart';
import '../widgets/progress/progress_section_card.dart';
import 'profile_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with AutomaticKeepAliveClientMixin<ProgressScreen> {
  late final LocalStorageService _storage;
  late final ProgressService _service;
  late final WeightService _weightService;
  late final ProfileService _profiles;
  late final ProgressWeekSummaryService _weekSummaryService;
  late final ProgressAdvancedAnalyticsService _advancedService;

  static const _kProgressCacheVersion = 1;

  int? _lastHomeTabIndex;
  bool _refreshingLight = false;

  ProgressData? _data;
  UserProfile? _profile;
  ProgressAdvancedAnalytics? _advancedAnalytics;
  bool _loading = true;
  bool _savingWeight = false;
  bool _sendingSuggestion = false;
  String? _statusMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _storage = LocalStorageService();
    _service = ProgressService(storage: _storage);
    _weightService = WeightService();
    _profiles = ProfileService();
    _weekSummaryService = ProgressWeekSummaryService(storage: _storage);
    _advancedService = ProgressAdvancedAnalyticsService(
      progress: _service,
      weekSummary: _weekSummaryService,
      storage: _storage,
    );

    _bootstrap();
  }

  void _bootstrap() {
    unawaited(() async {
      final restored = await _restoreProgressCache();
      await _load(withLoader: !restored);
    }());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nav = HomeNavigation.maybeOf(context);
    final idx = nav?.currentIndex;
    if (idx == null) return;

    final prev = _lastHomeTabIndex;
    _lastHomeTabIndex = idx;

    // When coming back to the Progress tab, refresh weight/profile (lightweight)
    // so updates made elsewhere (e.g. Perfil) are reflected.
    if (idx == 4 && prev != 4) {
      unawaited(_refreshLight());
    }
  }

  Future<void> _refreshLight() async {
    if (_refreshingLight) return;
    if (!mounted) return;
    if (_loading) return;

    _refreshingLight = true;
    try {
      final profile = await _profiles.getOrCreateProfile();

      final current = _advancedAnalytics;
      if (current == null) {
        await _load(withLoader: false);
        return;
      }

      final nextWeight = await _advancedService.loadWeightSummary();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _advancedAnalytics = ProgressAdvancedAnalytics(
          general: current.general,
          training: current.training,
          activity: current.activity,
          nutrition: current.nutrition,
          goals: current.goals,
          achievements: current.achievements,
          advanced: current.advanced,
          weight: nextWeight,
          insights: current.insights,
        );
      });
      unawaited(_persistProgressCache());
    } catch (_) {
      // best-effort
    } finally {
      _refreshingLight = false;
    }
  }

  Future<void> _load({bool withLoader = true}) async {
    if (withLoader && mounted) setState(() => _loading = true);
    try {
      final profile = await _profiles.getOrCreateProfile();

      // Best-effort: sync steps in background (do not block UI).
      unawaited(_syncStepsFromHealthBestEffort());

      // Load in parallel so the screen becomes responsive sooner.
      final results = await Future.wait([
        _service.loadProgress(days: 7),
        _advancedService.load(profile: profile),
      ]);

      final data = results[0] as ProgressData;
      final advanced = results[1] as ProgressAdvancedAnalytics;

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _data = data;
        _advancedAnalytics = advanced;
        _statusMessage = null;
      });
      unawaited(_persistProgressCache());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = (_data != null && _advancedAnalytics != null)
            ? 'No se detecta una fuente de internet. Mostrando tu progreso guardado.'
            : 'No se detecta una fuente de internet. El progreso se actualizará en cuanto vuelva la conexión.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _progressCacheKey() {
    final uid = Firebase.apps.isNotEmpty
        ? FirebaseAuth.instance.currentUser?.uid
        : null;
    return 'cf_progress_cache_v${_kProgressCacheVersion}_${uid ?? 'no_uid'}';
  }

  Future<bool> _restoreProgressCache() async {
    if (_isRunningWidgetTest) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_progressCacheKey());
      if (raw == null || raw.trim().isEmpty) return false;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;

      final data = _progressDataFromJson(_mapOf(decoded['data']));
      final analytics = _analyticsFromJson(_mapOf(decoded['analytics']));
      if (data == null || analytics == null) return false;

      final profile = await _profiles.getOrCreateProfile();
      if (!mounted) return false;

      setState(() {
        _profile = profile;
        _data = data;
        _advancedAnalytics = analytics;
        _loading = false;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistProgressCache() async {
    if (_isRunningWidgetTest) return;

    final data = _data;
    final analytics = _advancedAnalytics;
    if (data == null || analytics == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = <String, Object?>{
        'v': _kProgressCacheVersion,
        'savedAt': DateTime.now().toIso8601String(),
        'data': _progressDataToJson(data),
        'analytics': _analyticsToJson(analytics),
      };
      await prefs.setString(_progressCacheKey(), jsonEncode(snapshot));
    } catch (_) {
      // Ignore cache failures.
    }
  }

  Future<void> _syncStepsFromHealthBestEffort() async {
    if (_isRunningWidgetTest) return;

    try {
      await HealthService().syncTodaySteps().timeout(
        const Duration(seconds: 6),
        onTimeout: () => null,
      );
    } catch (_) {
      // Ignore (Health Connect/HealthKit may be unavailable or permission denied).
    }
  }

  Future<void> _openSuggestions() async {
    if (_sendingSuggestion) return;

    final controller = TextEditingController();
    const topics = <String>[
      'Inicio',
      'Entrenamiento',
      'Nutrición',
      'Progreso',
      'Otro',
    ];
    String? selectedTopic;

    try {
      final draft = await showDialog<({String topic, String message})>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final cleanMessage = controller.text.trim();
              final canSend =
                  (selectedTopic ?? '').trim().isNotEmpty &&
                  cleanMessage.isNotEmpty;

              return AlertDialog(
                title: const Text('Sugerencias'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedTopic,
                        decoration: const InputDecoration(labelText: 'Tema'),
                        items: [
                          for (final t in topics)
                            DropdownMenuItem(value: t, child: Text(t)),
                        ],
                        onChanged: (value) {
                          setDialogState(() => selectedTopic = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        minLines: 4,
                        maxLines: 8,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Escribe tu sugerencia…',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: canSend
                        ? () {
                            Navigator.of(context).pop((
                              topic: (selectedTopic ?? '').trim(),
                              message: cleanMessage,
                            ));
                          }
                        : null,
                    child: const Text('Enviar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (draft == null) return;
      if (draft.message.trim().isEmpty) return;
      if (draft.topic.trim().isEmpty) return;

      final name = (_profile?.name ?? 'Usuario').trim();
      String email = '';
      if (Firebase.apps.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        email = (user?.email ?? '').trim();
      }

      if (mounted) setState(() => _sendingSuggestion = true);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const AlertDialog(
            content: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Enviando sugerencia...')),
              ],
            ),
          );
        },
      );

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (Firebase.apps.isEmpty || user == null) {
          throw StateError('Authentication required');
        }

        await FirebaseFirestore.instance.collection('suggestions').add({
          'uid': user.uid,
          'topic': draft.topic,
          'message': draft.message,
          'name': name.isEmpty ? 'Usuario' : name,
          'email': email.isEmpty ? null : email,
          'source': 'app',
          'status': 'new',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } finally {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Gracias! Sugerencia enviada.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar la sugerencia.')),
        );
      }
    } finally {
      controller.dispose();
      if (mounted) setState(() => _sendingSuggestion = false);
    }
  }

  bool get _isRunningWidgetTest {
    // We cannot import `flutter_test` from production code, so detect it by
    // checking the binding runtimeType.
    try {
      final type = WidgetsBinding.instance.runtimeType.toString();
      return type.contains('TestWidgetsFlutterBinding') ||
          type.contains('AutomatedTestWidgetsFlutterBinding') ||
          type.contains('LiveTestWidgetsFlutterBinding');
    } catch (_) {
      return false;
    }
  }

  Future<void> _addWeightFlow() async {
    if (_savingWeight) return;
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir peso'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    if (mounted) setState(() => _savingWeight = true);
    try {
      await _weightService.upsertToday(result);

      final profile = _profile ?? await _profiles.getOrCreateProfile();
      final prev = profile.currentWeightKg;
      final shouldUpdateProfile = prev == null || (prev - result).abs() > 0.001;
      final nextProfile = shouldUpdateProfile
          ? profile.copyWith(currentWeightKg: result)
          : profile;

      if (shouldUpdateProfile) {
        await _profiles.saveProfile(nextProfile);
        unawaited(OnboardingService().syncProfileToFirestore(nextProfile));
      }

      final advanced = await _advancedService.load(profile: nextProfile);
      if (!mounted) return;
      setState(() {
        _profile = nextProfile;
        _advancedAnalytics = advanced;
      });
      unawaited(_persistProgressCache());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peso guardado correctamente.')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingWeight = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final data = _data;
    final analytics = _advancedAnalytics;

    return Scaffold(
      body: SafeArea(
        child: _loading && data == null
            ? const Center(child: CircularProgressIndicator())
            : data == null || analytics == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _statusMessage ?? 'No hay datos aún.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_statusMessage != null) ...[
                      InlineStatusBanner(message: _statusMessage!),
                      const SizedBox(height: 12),
                    ],
                    ..._buildBody(context, analytics),
                  ],
                ),
              ),
      ),
    );
  }

  Map<String, Object?> _mapOf(Object? value) {
    if (value is! Map) return const {};
    final out = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String) out[key] = entry.value;
    }
    return out;
  }

  List<Map<String, Object?>> _listOfMaps(Object? value) {
    if (value is! List) return const [];
    return value.map(_mapOf).where((item) => item.isNotEmpty).toList();
  }

  String _stringOf(Object? value, {String fallback = ''}) {
    final raw = (value is String ? value : value?.toString())?.trim();
    return raw == null || raw.isEmpty ? fallback : raw;
  }

  int _intOf(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    final raw = _stringOf(value);
    if (raw.isEmpty) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  double _doubleOf(Object? value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    final raw = _stringOf(value);
    if (raw.isEmpty) return fallback;
    return double.tryParse(raw) ?? fallback;
  }

  List<int> _intListOf(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => _intOf(item)).toList();
  }

  List<String> _stringListOf(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => _stringOf(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, int> _intMapOf(Object? value) {
    final map = _mapOf(value);
    return {for (final entry in map.entries) entry.key: _intOf(entry.value)};
  }

  Map<String, double> _doubleMapOf(Object? value) {
    final map = _mapOf(value);
    return {for (final entry in map.entries) entry.key: _doubleOf(entry.value)};
  }

  Map<String, Object?> _trendMetricToJson(TrendMetric metric) => {
    'current': metric.current,
    'previous': metric.previous,
  };

  TrendMetric _trendMetricFromJson(Object? value) {
    final map = _mapOf(value);
    return TrendMetric(
      current: _doubleOf(map['current']),
      previous: _doubleOf(map['previous']),
    );
  }

  Map<String, Object?> _chartPointToJson(ChartPoint point) => {
    'label': point.label,
    'value': point.value,
  };

  ChartPoint _chartPointFromJson(Object? value) {
    final map = _mapOf(value);
    return ChartPoint(
      label: _stringOf(map['label']),
      value: _doubleOf(map['value']),
    );
  }

  List<Map<String, Object?>> _chartPointsToJson(List<ChartPoint> points) =>
      points.map(_chartPointToJson).toList();

  List<ChartPoint> _chartPointsFromJson(Object? value) {
    return _listOfMaps(value).map(_chartPointFromJson).toList();
  }

  Map<String, Object?> _radarMetricToJson(RadarMetric metric) => {
    'label': metric.label,
    'value': metric.value,
  };

  RadarMetric _radarMetricFromJson(Object? value) {
    final map = _mapOf(value);
    return RadarMetric(
      label: _stringOf(map['label']),
      value: _doubleOf(map['value']),
    );
  }

  List<Map<String, Object?>> _radarMetricsToJson(List<RadarMetric> metrics) =>
      metrics.map(_radarMetricToJson).toList();

  List<RadarMetric> _radarMetricsFromJson(Object? value) {
    return _listOfMaps(value).map(_radarMetricFromJson).toList();
  }

  Map<String, Object?> _progressDataToJson(ProgressData data) => {
    'currentCf': data.currentCf,
    'average7Days': data.average7Days,
    'last7Days': [
      for (final point in data.last7Days)
        {'date': point.date.toIso8601String(), 'value': point.value},
    ],
  };

  ProgressData? _progressDataFromJson(Map<String, Object?> map) {
    if (map.isEmpty) return null;
    final last7Days = <CfHistoryPoint>[];
    for (final item in _listOfMaps(map['last7Days'])) {
      final dateRaw = _stringOf(item['date']);
      final date = DateTime.tryParse(dateRaw);
      if (date == null) continue;
      last7Days.add(CfHistoryPoint(date: date, value: _intOf(item['value'])));
    }
    if (last7Days.isEmpty) return null;

    return ProgressData(
      currentCf: _intOf(map['currentCf']),
      average7Days: _intOf(map['average7Days']),
      last7Days: last7Days,
    );
  }

  Map<String, Object?> _generalToJson(ProgressGeneralSummary summary) => {
    'currentStreak': summary.currentStreak,
    'bestStreak': summary.bestStreak,
    'weeklyStreak': summary.weeklyStreak,
    'monthlyDailyGoalsPercent': summary.monthlyDailyGoalsPercent,
    'weeklyGoalsPercent': summary.weeklyGoalsPercent,
    'monthlyAverageCf': summary.monthlyAverageCf,
    'realConstancyIndex': summary.realConstancyIndex,
    'weeklyGlobalScore': summary.weeklyGlobalScore,
    'monthlyDailyGoalsTrend': _trendMetricToJson(
      summary.monthlyDailyGoalsTrend,
    ),
    'weeklyGoalsTrend': _trendMetricToJson(summary.weeklyGoalsTrend),
    'cfTrend': _trendMetricToJson(summary.cfTrend),
    'weeklyAverageSteps': summary.weeklyAverageSteps,
    'weeklyStepsStreakOver8k': summary.weeklyStepsStreakOver8k,
    'weeklyWorkouts': summary.weeklyWorkouts,
    'weeklyWorkoutStreak': summary.weeklyWorkoutStreak,
    'weeklyTrainedMinutes': summary.weeklyTrainedMinutes,
    'weeklyHealthyEatingDays': summary.weeklyHealthyEatingDays,
    'weeklyHealthyEatingStreak': summary.weeklyHealthyEatingStreak,
    'topWeeklyGoal': summary.topWeeklyGoal,
    'weekStateAverage': summary.weekStateAverage,
    'weekEnergyAverage': summary.weekEnergyAverage,
    'weekStressAverage': summary.weekStressAverage,
    'weekMoodAverage': summary.weekMoodAverage,
    'weekSleepAverage': summary.weekSleepAverage,
  };

  ProgressGeneralSummary _generalFromJson(Object? value) {
    final map = _mapOf(value);
    return ProgressGeneralSummary(
      currentStreak: _intOf(map['currentStreak']),
      bestStreak: _intOf(map['bestStreak']),
      weeklyStreak: _intOf(map['weeklyStreak']),
      monthlyDailyGoalsPercent: _intOf(map['monthlyDailyGoalsPercent']),
      weeklyGoalsPercent: _intOf(map['weeklyGoalsPercent']),
      monthlyAverageCf: _intOf(map['monthlyAverageCf']),
      realConstancyIndex: _intOf(map['realConstancyIndex']),
      weeklyGlobalScore: _intOf(map['weeklyGlobalScore']),
      monthlyDailyGoalsTrend: _trendMetricFromJson(
        map['monthlyDailyGoalsTrend'],
      ),
      weeklyGoalsTrend: _trendMetricFromJson(map['weeklyGoalsTrend']),
      cfTrend: _trendMetricFromJson(map['cfTrend']),
      weeklyAverageSteps: _intOf(map['weeklyAverageSteps']),
      weeklyStepsStreakOver8k: _intOf(map['weeklyStepsStreakOver8k']),
      weeklyWorkouts: _intOf(map['weeklyWorkouts']),
      weeklyWorkoutStreak: _intOf(map['weeklyWorkoutStreak']),
      weeklyTrainedMinutes: _intOf(map['weeklyTrainedMinutes']),
      weeklyHealthyEatingDays: _intOf(map['weeklyHealthyEatingDays']),
      weeklyHealthyEatingStreak: _intOf(map['weeklyHealthyEatingStreak']),
      topWeeklyGoal: _stringOf(map['topWeeklyGoal']),
      weekStateAverage: _doubleOf(map['weekStateAverage']),
      weekEnergyAverage: _doubleOf(map['weekEnergyAverage']),
      weekStressAverage: _doubleOf(map['weekStressAverage']),
      weekMoodAverage: _doubleOf(map['weekMoodAverage']),
      weekSleepAverage: _doubleOf(map['weekSleepAverage']),
    );
  }

  Map<String, Object?> _trainingToJson(ProgressTrainingSummary summary) => {
    'totalWorkouts': summary.totalWorkouts,
    'totalMinutes': summary.totalMinutes,
    'mostPerformedExercises': summary.mostPerformedExercises,
    'mostTrainedMuscleGroup': summary.mostTrainedMuscleGroup,
    'personalRecords': summary.personalRecords,
    'estimatedLevel': summary.estimatedLevel,
    'programAdherencePercent': summary.programAdherencePercent,
    'weeklyTrend': _trendMetricToJson(summary.weeklyTrend),
    'strengthByExercise': {
      for (final entry in summary.strengthByExercise.entries)
        entry.key: _chartPointsToJson(entry.value),
    },
  };

  ProgressTrainingSummary _trainingFromJson(Object? value) {
    final map = _mapOf(value);
    final strengthRaw = _mapOf(map['strengthByExercise']);
    final strengthByExercise = <String, List<ChartPoint>>{};
    for (final entry in strengthRaw.entries) {
      strengthByExercise[entry.key] = _chartPointsFromJson(entry.value);
    }

    return ProgressTrainingSummary(
      totalWorkouts: _intOf(map['totalWorkouts']),
      totalMinutes: _intOf(map['totalMinutes']),
      mostPerformedExercises: _stringListOf(map['mostPerformedExercises']),
      mostTrainedMuscleGroup: _stringOf(map['mostTrainedMuscleGroup']),
      personalRecords: _intOf(map['personalRecords']),
      estimatedLevel: _stringOf(map['estimatedLevel']),
      programAdherencePercent: _intOf(map['programAdherencePercent']),
      weeklyTrend: _trendMetricFromJson(map['weeklyTrend']),
      strengthByExercise: strengthByExercise,
    );
  }

  Map<String, Object?> _activityToJson(ProgressActivitySummary summary) => {
    'averageDailySteps': summary.averageDailySteps,
    'bestStepDayLabel': summary.bestStepDayLabel,
    'bestStepDaySteps': summary.bestStepDaySteps,
    'totalDistanceKm': summary.totalDistanceKm,
    'estimatedStandingMinutes': summary.estimatedStandingMinutes,
    'activeDaysStreak': summary.activeDaysStreak,
    'daysOver8000': summary.daysOver8000,
    'stepsChart': _chartPointsToJson(summary.stepsChart),
    'activityHeatmap': summary.activityHeatmap,
  };

  ProgressActivitySummary _activityFromJson(Object? value) {
    final map = _mapOf(value);
    return ProgressActivitySummary(
      averageDailySteps: _intOf(map['averageDailySteps']),
      bestStepDayLabel: _stringOf(map['bestStepDayLabel']),
      bestStepDaySteps: _intOf(map['bestStepDaySteps']),
      totalDistanceKm: _doubleOf(map['totalDistanceKm']),
      estimatedStandingMinutes: _intOf(map['estimatedStandingMinutes']),
      activeDaysStreak: _intOf(map['activeDaysStreak']),
      daysOver8000: _intOf(map['daysOver8000']),
      stepsChart: _chartPointsFromJson(map['stepsChart']),
      activityHeatmap: _intListOf(map['activityHeatmap']),
    );
  }

  Map<String, Object?> _nutritionToJson(ProgressNutritionSummary summary) => {
    'weeklyCalorieBalance': summary.weeklyCalorieBalance,
    'mostRepeatedMeal': summary.mostRepeatedMeal,
    'highProteinDays': summary.highProteinDays,
    'daysMeetingCalorieGoal': summary.daysMeetingCalorieGoal,
    'averageMonthlyCalories': summary.averageMonthlyCalories,
    'macroDistribution': summary.macroDistribution,
    'caloriesTrend': _chartPointsToJson(summary.caloriesTrend),
    'smoothedWeightTrend': _chartPointsToJson(summary.smoothedWeightTrend),
  };

  ProgressNutritionSummary _nutritionFromJson(Object? value) {
    final map = _mapOf(value);
    return ProgressNutritionSummary(
      weeklyCalorieBalance: _intOf(map['weeklyCalorieBalance']),
      mostRepeatedMeal: _stringOf(map['mostRepeatedMeal']),
      highProteinDays: _intOf(map['highProteinDays']),
      daysMeetingCalorieGoal: _intOf(map['daysMeetingCalorieGoal']),
      averageMonthlyCalories: _intOf(map['averageMonthlyCalories']),
      macroDistribution: _doubleMapOf(map['macroDistribution']),
      caloriesTrend: _chartPointsFromJson(map['caloriesTrend']),
      smoothedWeightTrend: _chartPointsFromJson(map['smoothedWeightTrend']),
    );
  }

  Map<String, Object?> _goalsToJson(ProgressGoalsSummary summary) => {
    'dailyCompletionPercent': summary.dailyCompletionPercent,
    'weeklyCompletionPercent': summary.weeklyCompletionPercent,
    'weeklyStreak': summary.weeklyStreak,
    'categoryBreakdown': summary.categoryBreakdown,
  };

  ProgressGoalsSummary _goalsFromJson(Object? value) {
    final map = _mapOf(value);
    return ProgressGoalsSummary(
      dailyCompletionPercent: _intOf(map['dailyCompletionPercent']),
      weeklyCompletionPercent: _intOf(map['weeklyCompletionPercent']),
      weeklyStreak: _intOf(map['weeklyStreak']),
      categoryBreakdown: _intMapOf(map['categoryBreakdown']),
    );
  }

  Map<String, Object?> _achievementsToJson(
    ProgressAchievementsSummary summary,
  ) => {
    'unlocked': summary.unlocked,
    'inProgress': summary.inProgress,
    'rarest': summary.rarest,
    'byCategory': summary.byCategory,
    'level': summary.level,
    'currentXp': summary.currentXp,
    'nextLevelXp': summary.nextLevelXp,
  };

  ProgressAchievementsSummary _achievementsFromJson(Object? value) {
    final map = _mapOf(value);
    return ProgressAchievementsSummary(
      unlocked: _intOf(map['unlocked']),
      inProgress: _intOf(map['inProgress']),
      rarest: _stringListOf(map['rarest']),
      byCategory: _intMapOf(map['byCategory']),
      level: _intOf(map['level']),
      currentXp: _intOf(map['currentXp']),
      nextLevelXp: _intOf(map['nextLevelXp']),
    );
  }

  Map<String, Object?> _advancedToJson(ProgressAdvancedSummary summary) => {
    'healthyLifeBalanceScore': summary.healthyLifeBalanceScore,
    'historicalStreakTimeline': _chartPointsToJson(
      summary.historicalStreakTimeline,
    ),
    'moodEvolution': _chartPointsToJson(summary.moodEvolution),
    'bestVersionMonth': summary.bestVersionMonth,
    'radarMetrics': _radarMetricsToJson(summary.radarMetrics),
    'waterTrend': _chartPointsToJson(summary.waterTrend),
    'cfTrend': _chartPointsToJson(summary.cfTrend),
    'monthMoodAverage': summary.monthMoodAverage,
    'monthEnergyAverage': summary.monthEnergyAverage,
    'monthStressAverage': summary.monthStressAverage,
    'monthSleepAverage': summary.monthSleepAverage,
    'monthAnimatedAverage': summary.monthAnimatedAverage,
  };

  ProgressAdvancedSummary _advancedFromJson(Object? value) {
    final map = _mapOf(value);
    return ProgressAdvancedSummary(
      healthyLifeBalanceScore: _intOf(map['healthyLifeBalanceScore']),
      historicalStreakTimeline: _chartPointsFromJson(
        map['historicalStreakTimeline'],
      ),
      moodEvolution: _chartPointsFromJson(map['moodEvolution']),
      bestVersionMonth: _stringOf(map['bestVersionMonth']),
      radarMetrics: _radarMetricsFromJson(map['radarMetrics']),
      waterTrend: _chartPointsFromJson(map['waterTrend']),
      cfTrend: _chartPointsFromJson(map['cfTrend']),
      monthMoodAverage: _doubleOf(map['monthMoodAverage']),
      monthEnergyAverage: _doubleOf(map['monthEnergyAverage']),
      monthStressAverage: _doubleOf(map['monthStressAverage']),
      monthSleepAverage: _doubleOf(map['monthSleepAverage']),
      monthAnimatedAverage: _doubleOf(map['monthAnimatedAverage']),
    );
  }

  Map<String, Object?> _weightToJson(ProgressWeightSummaryExtended summary) => {
    'rawTrend': _chartPointsToJson(summary.rawTrend),
    'smoothedTrend': _chartPointsToJson(summary.smoothedTrend),
    'monthlyComparison': summary.monthlyComparison,
    'bestMonth': summary.bestMonth,
    'changeFromLastMonthPercent': summary.changeFromLastMonthPercent,
    'context': summary.context,
    'currentWeight': summary.currentWeight,
    'currentWeightLabel': summary.currentWeightLabel,
  };

  ProgressWeightSummaryExtended _weightFromJson(Object? value) {
    final map = _mapOf(value);
    final currentWeightRaw = map['currentWeight'];
    final currentWeight = currentWeightRaw == null
        ? null
        : _doubleOf(currentWeightRaw);

    return ProgressWeightSummaryExtended(
      rawTrend: _chartPointsFromJson(map['rawTrend']),
      smoothedTrend: _chartPointsFromJson(map['smoothedTrend']),
      monthlyComparison: _doubleOf(map['monthlyComparison']),
      bestMonth: _stringOf(map['bestMonth']),
      changeFromLastMonthPercent: _doubleOf(map['changeFromLastMonthPercent']),
      context: _stringOf(map['context']),
      currentWeight: currentWeight,
      currentWeightLabel: _stringOf(map['currentWeightLabel']),
    );
  }

  Map<String, Object?> _analyticsToJson(ProgressAdvancedAnalytics analytics) =>
      {
        'general': _generalToJson(analytics.general),
        'training': _trainingToJson(analytics.training),
        'activity': _activityToJson(analytics.activity),
        'nutrition': _nutritionToJson(analytics.nutrition),
        'goals': _goalsToJson(analytics.goals),
        'achievements': _achievementsToJson(analytics.achievements),
        'advanced': _advancedToJson(analytics.advanced),
        'weight': _weightToJson(analytics.weight),
        'insights': [for (final item in analytics.insights) item.text],
      };

  ProgressAdvancedAnalytics? _analyticsFromJson(Map<String, Object?> map) {
    if (map.isEmpty) return null;
    return ProgressAdvancedAnalytics(
      general: _generalFromJson(map['general']),
      training: _trainingFromJson(map['training']),
      activity: _activityFromJson(map['activity']),
      nutrition: _nutritionFromJson(map['nutrition']),
      goals: _goalsFromJson(map['goals']),
      achievements: _achievementsFromJson(map['achievements']),
      advanced: _advancedFromJson(map['advanced']),
      weight: _weightFromJson(map['weight']),
      insights: [
        for (final text in _stringListOf(map['insights']))
          ProgressInsightItem(text),
      ],
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    ProgressAdvancedAnalytics analytics,
  ) {
    return [
      HeaderProfile(
        profile: _profile,
        onOpenProfile: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ProfileScreen()))
              .then((_) => _load(withLoader: false));
        },
        onOpenSuggestions: _openSuggestions,
      ),
      const SizedBox(height: 10),
      ProgressAdvancedDashboard(
        analytics: analytics,
        onAddWeight: _addWeightFlow,
        userName: (_profile?.name.trim().isEmpty ?? true)
            ? 'Usuario'
            : _profile!.name,
        currentCf: _data?.currentCf,
      ),
      const SizedBox(height: 10),
      Text(
        'Logros',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      _buildAchievementsEntry(context, analytics),
      const SizedBox(height: 10),
      const ProgressPremiumCard(),
      const SizedBox(height: 8),
    ];
  }

  /*

  bool _profileIsFemale(UserProfile? p) => p?.sex == UserSex.mujer;

  List<({Workout workout, String reason})> _buildWomenCycleWorkoutTips({
    required WomenCycleData? cycle,
    required UserProfile? profile,
    required List<Workout> workouts,
  }) {
    if (workouts.isEmpty) return const [];

    final isActive = cycle != null && cycle.end == null;

    final scored = workouts
        .map(
          (w) => (
            workout: w,
            rec: TrainingRecommendationService.scoreWorkout(
              profile: profile,
              workout: w,
            ),
          ),
        )
        .where((e) => e.rec.score >= 0)
        .toList();

    if (scored.isEmpty) return const [];

    var candidates = scored;
    if (isActive) {
      final low = scored.where((e) {
        final w = e.workout;
        final name = w.name.toLowerCase();
        final category = w.category.toLowerCase();
        final hasMobility =
            w.goals.contains(WorkoutGoal.movilidad) ||
            w.goals.contains(WorkoutGoal.flexibilidad) ||
            name.contains('estir') ||
            name.contains('movil') ||
            name.contains('yoga') ||
            category.contains('estir') ||
            category.contains('movil') ||
            category.contains('yoga');

        final isLight =
            w.difficulty == WorkoutDifficulty.leve ||
            w.durationMinutes <= 20 ||
            w.level.toLowerCase().contains('princip');
        return hasMobility || isLight;
      }).toList();
      if (low.isNotEmpty) candidates = low;
    }

    candidates.sort((a, b) {
      final byScore = b.rec.score.compareTo(a.rec.score);
      if (byScore != 0) return byScore;
      return a.workout.durationMinutes.compareTo(b.workout.durationMinutes);
    });

    String activeReason(Workout w, TrainingRecommendation rec) {
      final tags = <String>[];
      if (w.goals.contains(WorkoutGoal.movilidad)) tags.add('movilidad');
      if (w.goals.contains(WorkoutGoal.flexibilidad)) tags.add('flexibilidad');
      if (w.difficulty == WorkoutDifficulty.leve) tags.add('leve');
      if (w.durationMinutes > 0) tags.add('${w.durationMinutes} min');
      final tagText = tags.isEmpty ? 'baja intensidad' : tags.take(3).join(' · ');
      return 'Días de regla: $tagText. ${rec.explanation}';
    }

    return [
      for (final e in candidates.take(2))
        (
          workout: e.workout,
          reason: isActive ? activeReason(e.workout, e.rec) : e.rec.explanation,
        ),
    ];
  }

  Widget _buildWomenCycleCard(BuildContext context) {
    final cycle = _cycleData;
    final now = DateUtilsCF.dateOnly(DateTime.now());

    final isActive = cycle != null && cycle.end == null;

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

    String statusText() {
      if (cycle == null) return 'Pulsa "Tengo la regla" cuando empiece.';
      if (cycle.end == null) {
        final days = now.difference(cycle.start).inDays + 1;
        return 'Regla activa · día ${days < 1 ? 1 : days}.';
      }

      final daysAgo = now.difference(cycle.end!).inDays;
      if (daysAgo <= 0) return 'Última regla terminó hoy.';
      if (daysAgo == 1) return 'Última regla terminó ayer.';
      return 'Última regla terminó hace $daysAgo día(s).';
    }

    return ProgressSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.female_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ciclo y nutrición femenino',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.45),
                    ),
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.14),
                  ),
                  child: Text(
                    'Regla activa',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(statusText(), style: Theme.of(context).textTheme.bodyMedium),
          if (cycle != null) ...[
            const SizedBox(height: 4),
            Text(
              cycle.end == null
                  ? 'Inicio: ${fmt(cycle.start)}'
                  : 'Inicio: ${fmt(cycle.start)} · Fin: ${fmt(cycle.end!)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: isActive
                    ? FilledButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final next = await _womenCycleService.endPeriod();
                          if (!mounted || next == null) return;
                          setState(() {
                            _cycleData = next;
                            _cycleWorkoutTips = _buildWomenCycleWorkoutTips(
                              cycle: next,
                              profile: _profile,
                              workouts: _allWorkouts,
                            );
                          });
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Fin de regla guardado.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Se me acabó la regla'),
                      )
                    : FilledButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final next = await _womenCycleService.startPeriod();
                          if (!mounted) return;
                          setState(() {
                            _cycleData = next;
                            _cycleWorkoutTips = _buildWomenCycleWorkoutTips(
                              cycle: next,
                              profile: _profile,
                              workouts: _allWorkouts,
                            );
                          });
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Regla iniciada.')),
                          );
                        },
                        icon: const Icon(Icons.water_drop_outlined),
                        label: const Text('Tengo la regla'),
                      ),
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.restaurant_outlined, color: CFColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comidas recomendadas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final tip in _cycleTips.take(3)) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.tips_and_updates_outlined,
                      size: 16,
                      color: CFColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.title,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: context.cfTextPrimary,
                          ),
                        ),
                        Text(
                          tip.reason,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Builder(
              builder: (context) {
                final seen = <String>{};
                final items = <RecipeModel>[];
                for (final tip in _cycleTips) {
                  for (final r in tip.recipes) {
                    if (!seen.add(r.id)) continue;
                    items.add(r);
                    if (items.length >= 2) break;
                  }
                  if (items.length >= 2) break;
                }

                if (items.isEmpty) {
                  return Text(
                    'Sin recomendaciones de recetas todavía.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }

                return Column(
                  children: [
                    for (final r in items) ...[
                      ProgressSectionCard(
                        padding: const EdgeInsets.all(12),
                        boxShadow: const [],
                        backgroundColor: context.cfSoftSurface,
                        borderColor: context.cfBorder,
                        child: InkWell(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(18),
                          ),
                          onTap: () => _openRecipeDetail(r.id),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.restaurant_menu_outlined,
                                color: CFColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${r.durationMinutes} min · ${r.kcalPerServing} kcal/ración',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'P ${r.macrosPerServing.proteinG}g · C ${r.macrosPerServing.carbsG}g · G ${r.macrosPerServing.fatG}g',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: context.cfTextSecondary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right,
                                color: context.cfTextSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 2),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.self_improvement_outlined,
                  color: CFColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ejercicios y estiramientos recomendados',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_cycleWorkoutTips.isEmpty)
              Text(
                'Sin recomendaciones de entreno todavía.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              for (final entry in _cycleWorkoutTips) ...[
                ProgressSectionCard(
                  padding: const EdgeInsets.all(12),
                  boxShadow: const [],
                  backgroundColor: context.cfSoftSurface,
                  borderColor: context.cfBorder,
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                    onTap: () => _openWorkoutDetail(entry.workout),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.fitness_center_outlined,
                          color: CFColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.workout.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${entry.workout.durationMinutes} min · ${entry.workout.level}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.reason,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: context.cfTextSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right,
                          color: context.cfTextSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ],
      ),
    );
  }

  */

  Widget _buildAchievementsEntry(
    BuildContext context,
    ProgressAdvancedAnalytics analytics,
  ) {
    final s = analytics.achievements;
    final xpToLevelStart = (s.level - 1) * 250;
    final denominator = (s.nextLevelXp - xpToLevelStart).clamp(1, 1000000);
    final levelProgress = ((s.currentXp - xpToLevelStart) / denominator).clamp(
      0.0,
      1.0,
    );

    return ProgressSectionCard(
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AchievementsScreen()));
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SmallKpi(
                      label: 'Desbloqueados',
                      value: '${s.unlocked}',
                    ),
                  ),
                  Expanded(
                    child: _SmallKpi(
                      label: 'En progreso',
                      value: '${s.inProgress}',
                    ),
                  ),
                  Expanded(
                    child: _SmallKpi(label: 'Nivel', value: '${s.level}'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('XP', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: levelProgress,
                minHeight: 8,
                backgroundColor: context.cfBorder,
                color: context.cfPrimary,
              ),
              const SizedBox(height: 4),
              Text(
                '${s.currentXp} / ${s.nextLevelXp} XP',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Ver detalle',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallKpi extends StatelessWidget {
  const _SmallKpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 18,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
