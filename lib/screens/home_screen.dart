import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/daily_data_controller.dart';
import '../core/home_navigation.dart';
import '../core/theme.dart';
import '../models/workout.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/app_permissions_service.dart';
import '../services/health_service.dart';
import '../services/home_dashboard_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_permission_service.dart';
import '../services/profile_service.dart';
import '../services/task_reminder_service.dart';
import '../services/training_recommendation_service.dart';
import '../services/workout_service.dart';
import '../utils/date_utils.dart';
import '../widgets/common/inline_status_banner.dart';
import '../widgets/home/home_women_cycle_section.dart';
import 'workout_detail_screen.dart';

class UserData {
  final String name;
  int currentCFIndex;
  int dailyStreak;
  int weeklyStreak;
  bool moodRegisteredToday;
  String currentMoodIcon;
  Map<String, int> waterIntake;
  Map<String, int> stepsCount;
  Map<String, dynamic> dailyGoal;
  Map<String, dynamic> weeklyGoal;
  Map<String, dynamic> weeklyChallenge;
  List<Map<String, dynamic>> habits;
  List<Map<String, dynamic>> todos;
  String currentTimeOfDay;

  UserData({
    required this.name,
    required this.currentCFIndex,
    required this.dailyStreak,
    required this.weeklyStreak,
    required this.moodRegisteredToday,
    required this.currentMoodIcon,
    required this.waterIntake,
    required this.stepsCount,
    required this.dailyGoal,
    required this.weeklyGoal,
    required this.weeklyChallenge,
    required this.habits,
    required this.todos,
    required this.currentTimeOfDay,
  });

  UserData copyWith({
    String? name,
    int? currentCFIndex,
    int? dailyStreak,
    int? weeklyStreak,
    bool? moodRegisteredToday,
    String? currentMoodIcon,
    Map<String, int>? waterIntake,
    Map<String, int>? stepsCount,
    Map<String, dynamic>? dailyGoal,
    Map<String, dynamic>? weeklyGoal,
    Map<String, dynamic>? weeklyChallenge,
    List<Map<String, dynamic>>? habits,
    List<Map<String, dynamic>>? todos,
    String? currentTimeOfDay,
  }) {
    return UserData(
      name: name ?? this.name,
      currentCFIndex: currentCFIndex ?? this.currentCFIndex,
      dailyStreak: dailyStreak ?? this.dailyStreak,
      weeklyStreak: weeklyStreak ?? this.weeklyStreak,
      moodRegisteredToday: moodRegisteredToday ?? this.moodRegisteredToday,
      currentMoodIcon: currentMoodIcon ?? this.currentMoodIcon,
      waterIntake: waterIntake ?? this.waterIntake,
      stepsCount: stepsCount ?? this.stepsCount,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      weeklyChallenge: weeklyChallenge ?? this.weeklyChallenge,
      habits: habits ?? this.habits,
      todos: todos ?? this.todos,
      currentTimeOfDay: currentTimeOfDay ?? this.currentTimeOfDay,
    );
  }
}

final UserData initialUserData = UserData(
  name: 'Alex',
  currentCFIndex: 60,
  dailyStreak: 0,
  weeklyStreak: 0,
  moodRegisteredToday: false,
  currentMoodIcon: '',
  waterIntake: {'current': 0, 'target': 2000},
  stepsCount: {'current': 0, 'target': 8000},
  dailyGoal: {
    'type': 'Entrenamiento',
    'description': 'Completar misión diaria',
    'progress': 0,
    'target': 100,
  },
  weeklyGoal: {
    'type': 'Hábitos',
    'description': 'Cumplir objetivos semanales',
    'progress': 0,
    'target': 100,
  },
  weeklyChallenge: {
    'id': '',
    'weekId': '',
    'title': 'Sin reto activo',
    'description': 'No hay reto activo. ¡Pronto uno nuevo!',
    'userProgress': 0,
    'target': 1,
    'communityCompletionPct': 0,
    'reward': '+0 CF',
    'rewardCfBonus': 0,
    'completed': false,
    'isActive': false,
  },
  habits: const [],
  todos: const [],
  currentTimeOfDay: 'morning',
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin<HomeScreen>, WidgetsBindingObserver {
  final _auth = AuthService();
  final _appPermissions = AppPermissionsService();
  final _profile = ProfileService();
  final _dashboard = HomeDashboardService();
  final _controller = DailyDataController();
  final _health = HealthService();
  final _storage = LocalStorageService();
  final _workouts = WorkoutService();

  UserData _userData = initialUserData;
  UserProfile? _profileModel;
  bool _loading = true;
  bool _loadingPrimaryMetrics = true;
  bool _loadingCollections = true;
  bool _suggestionVisible = false;
  List<HomeDayStat> _weekDays = const [];
  late final PageController _suggestionPageController;
  int _suggestionIndex = 0;
  String _cityLabel = 'Ubicación no disponible';
  String _tempLabel = '--°C';
  String _weatherEmoji = '🌙';
  int? _tempC;
  int _weatherCode = -1;
  int? _windKmh;
  DateTime _clockNow = DateTime.now();
  Timer? _clockTimer;
  Timer? _clockStartTimer;
  Timer? _environmentTimer;
  int _weeklyHabitsCompleted = 0;
  int _weeklyHabitActiveDays = 0;
  Map<String, dynamic>? _todayMoodEntry;
  bool _moodAutoPromptScheduled = false;
  bool _moodAutoPromptInProgress = false;
  String? _statusMessage;
  List<int> _cfSeries30Cache = const [];
  List<int> _stepsSeries30Cache = const [];
  AppPermissionStatus _stepsPermissionStatusCache =
      AppPermissionStatus.notRequested;
  Future<void>? _dialogMetricsPrefetchFuture;

  @override
  bool get wantKeepAlive => true;

  static const _difficultyToPoints = <String, int>{
    'Fácil': 5,
    'Media': 10,
    'Difícil': 15,
    'Épica': 25,
  };

  static const _dailyGoalTemplates = <String, List<Map<String, dynamic>>>{
    'Entrenamiento': [
      {'description': 'Completar 1 sesión de fuerza', 'target': 1},
      {'description': 'Hacer 20 min de cardio', 'target': 20},
      {'description': 'Practicar movilidad 15 min', 'target': 15},
      {'description': 'Acumular 30 min de actividad', 'target': 30},
      {'description': 'Completar entrenamiento principal', 'target': 1},
      {'description': 'Añadir bloque de core 10 min', 'target': 10},
    ],
    'Nutrición': [
      {'description': 'Comer 3 comidas equilibradas', 'target': 3},
      {'description': 'Añadir 2 raciones de verdura', 'target': 2},
      {'description': 'Evitar ultraprocesados hoy', 'target': 1},
      {'description': 'Alcanzar 2 comidas completas', 'target': 2},
      {'description': 'Incluir proteína en 3 comidas', 'target': 3},
      {'description': 'Registrar toda la alimentación del día', 'target': 4},
    ],
    'Hidratación': [
      {'description': 'Beber 2L de agua', 'target': 2000},
      {'description': 'Tomar 6 vasos de agua', 'target': 6},
      {'description': 'Llegar a 2.5L de hidratación', 'target': 2500},
      {'description': 'Hidratarse en 8 tomas', 'target': 8},
    ],
    'Meditación': [
      {'description': 'Meditar 10 minutos', 'target': 10},
      {'description': 'Respiración guiada 5 min', 'target': 5},
      {'description': 'Hacer 15 min de mindfulness', 'target': 15},
      {'description': 'Pausa consciente de 8 minutos', 'target': 8},
    ],
    'Pasos': [
      {'description': 'Caminar 8000 pasos', 'target': 8000},
      {'description': 'Caminar 10000 pasos', 'target': 10000},
      {'description': 'Caminar 12000 pasos', 'target': 12000},
      {'description': 'Completar caminata activa', 'target': 6000},
    ],
    'Hábitos': [
      {'description': 'Completar 3 hábitos del día', 'target': 3},
      {'description': 'Cumplir rutina matinal', 'target': 1},
      {'description': 'Completar 4 hábitos del día', 'target': 4},
      {'description': 'Encadenar hábitos clave', 'target': 5},
    ],
  };

  static const _weeklyGoalTemplates = <String, List<Map<String, dynamic>>>{
    'Entrenamiento': [
      {'description': 'Entrenar 3 veces esta semana', 'target': 3},
      {'description': 'Acumular 120 min de actividad', 'target': 120},
      {'description': 'Completar 4 sesiones semanales', 'target': 4},
      {'description': 'Acumular 180 min de entrenamiento', 'target': 180},
    ],
    'Nutrición': [
      {'description': 'Comer sano 5 días', 'target': 5},
      {'description': 'Registrar comidas 7 días', 'target': 7},
      {'description': 'Registrar 14 comidas balanceadas', 'target': 14},
      {'description': 'Cumplir proteína diaria 5 días', 'target': 5},
    ],
    'Hidratación': [
      {'description': 'Cumplir hidratación 6 días', 'target': 6},
      {'description': 'Llegar a 14L en la semana', 'target': 14000},
      {'description': 'Llegar a 16L de agua semanal', 'target': 16000},
      {'description': 'Hidratarse correctamente 7 días', 'target': 7},
    ],
    'Meditación': [
      {'description': 'Meditar 4 días', 'target': 4},
      {'description': 'Acumular 60 min', 'target': 60},
      {'description': 'Completar 5 sesiones de calma', 'target': 5},
      {'description': 'Acumular 90 min de mindfulness', 'target': 90},
    ],
    'Pasos': [
      {'description': 'Caminar 50000 pasos', 'target': 50000},
      {'description': 'Superar 8000 pasos en 5 días', 'target': 5},
      {'description': 'Caminar 60000 pasos', 'target': 60000},
      {'description': 'Superar 10000 pasos en 4 días', 'target': 4},
    ],
    'Hábitos': [
      {'description': 'Completar 12 hábitos semanales', 'target': 12},
      {'description': 'No romper cadena 7 días', 'target': 7},
      {'description': 'Completar 18 hábitos semanales', 'target': 18},
      {'description': 'Cumplir hábitos clave en 5 días', 'target': 5},
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _suggestionPageController = PageController(viewportFraction: 0.93);
    _startClockTicker();
    if (!_isRunningWidgetTest) {
      _startEnvironmentTicker();
    }
    _bootstrap();
    if (!_isRunningWidgetTest) {
      _refreshEnvironmentInfo();
      // One-shot retry: if the user just granted location permission on startup,
      // update climate/location shortly after without waiting 15 minutes.
      Future<void>.delayed(const Duration(seconds: 10), () {
        if (!mounted) return;
        _refreshEnvironmentInfo();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _clockStartTimer?.cancel();
    _environmentTimer?.cancel();
    _suggestionPageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    _startClockTicker();
    if (!_isRunningWidgetTest) {
      unawaited(_refreshEnvironmentInfo());
    }

    final todayKey = DateUtilsCF.toKey(DateTime.now());
    if (todayKey != _controller.todayKey) {
      unawaited(_loadRealData(withLoader: false, allowMoodAutoPrompt: true));
    }
  }

  static const _kHomeCacheKey = 'cf_home_cache_v1';

  bool get _hasVisibleContent {
    if (_profileModel != null) return true;
    if (_weekDays.isNotEmpty) return true;
    if (_userData.habits.isNotEmpty || _userData.todos.isNotEmpty) return true;
    if (_userData.name != initialUserData.name) return true;
    if (_userData.dailyStreak != initialUserData.dailyStreak) return true;
    if ((_userData.stepsCount['current'] ?? 0) > 0) return true;
    return false;
  }

  void _bootstrap() {
    unawaited(() async {
      final restored = await _restoreHomeCache();
      await _loadRealData(withLoader: !restored, allowMoodAutoPrompt: true);
    }());
  }

  void _scheduleMoodAutoPrompt() {
    if (!mounted || _moodAutoPromptScheduled || _moodAutoPromptInProgress) {
      return;
    }

    _moodAutoPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moodAutoPromptScheduled = false;
      if (!mounted) return;
      unawaited(_maybeAutoOpenMoodCheck());
    });
  }

  Future<void> _maybeAutoOpenMoodCheck() async {
    if (!mounted ||
        _loading ||
        _loadingCollections ||
        _moodAutoPromptInProgress ||
        _isRunningWidgetTest ||
        _userData.moodRegisteredToday) {
      return;
    }

    final shouldPrompt = await _controller.shouldPromptMoodToday();
    if (!shouldPrompt || !mounted || _userData.moodRegisteredToday) return;

    _moodAutoPromptInProgress = true;
    try {
      final nav = HomeNavigation.maybeOf(context);
      nav?.goToTab(2);

      await _controller.markMoodPromptShownToday();
      if (!mounted) return;

      final nextFrame = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!nextFrame.isCompleted) {
          nextFrame.complete();
        }
      });
      await nextFrame.future;
      if (!mounted) return;

      await _showMoodCheckModal();
    } finally {
      _moodAutoPromptInProgress = false;
    }
  }

  Future<bool> _restoreHomeCache() async {
    if (_isRunningWidgetTest) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHomeCacheKey);
      if (raw == null || raw.trim().isEmpty) return false;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;

      Map<String, Object?> mapOf(Object? rawMap) {
        if (rawMap is! Map) return const {};
        final out = <String, Object?>{};
        for (final e in rawMap.entries) {
          final k = e.key;
          if (k is String) out[k] = e.value;
        }
        return out;
      }

      List<Map<String, dynamic>> listOfMaps(Object? rawList) {
        if (rawList is! List) return const [];
        final out = <Map<String, dynamic>>[];
        for (final item in rawList) {
          if (item is! Map) continue;
          final m = <String, dynamic>{};
          for (final e in item.entries) {
            final k = e.key;
            if (k is String) m[k] = e.value;
          }
          out.add(m);
        }
        return out;
      }

      final userDataRaw = decoded['userData'];
      if (userDataRaw is! Map) return false;
      final userDataMap = mapOf(userDataRaw);

      final todos = listOfMaps(userDataMap['todos'])
          .map((t) {
            final next = Map<String, dynamic>.from(t);
            final rawDue = next['dueDateValue'];
            if (rawDue is String) {
              final parsed = DateTime.tryParse(rawDue);
              if (parsed != null) next['dueDateValue'] = parsed;
            }
            return next;
          })
          .toList(growable: false);

      final waterMap = mapOf(userDataMap['waterIntake']);
      final stepsMap = mapOf(userDataMap['stepsCount']);

      final restoredUserData = UserData(
        name: (userDataMap['name'] as String?) ?? _userData.name,
        currentCFIndex: _asInt(
          userDataMap['currentCFIndex'],
          fallback: _userData.currentCFIndex,
        ),
        dailyStreak: _asInt(
          userDataMap['dailyStreak'],
          fallback: _userData.dailyStreak,
        ),
        weeklyStreak: _asInt(
          userDataMap['weeklyStreak'],
          fallback: _userData.weeklyStreak,
        ),
        moodRegisteredToday: userDataMap['moodRegisteredToday'] == true,
        currentMoodIcon:
            (userDataMap['currentMoodIcon'] as String?) ??
            _userData.currentMoodIcon,
        waterIntake: {
          'current': _asInt(
            waterMap['current'],
            fallback: _userData.waterIntake['current'] ?? 0,
          ),
          'target': _asInt(
            waterMap['target'],
            fallback: _userData.waterIntake['target'] ?? 2000,
          ),
        },
        stepsCount: {
          'current': _asInt(
            stepsMap['current'],
            fallback: _userData.stepsCount['current'] ?? 0,
          ),
          'target': _asInt(
            stepsMap['target'],
            fallback: _userData.stepsCount['target'] ?? 8000,
          ),
        },
        dailyGoal: Map<String, dynamic>.from(mapOf(userDataMap['dailyGoal'])),
        weeklyGoal: Map<String, dynamic>.from(mapOf(userDataMap['weeklyGoal'])),
        weeklyChallenge: Map<String, dynamic>.from(
          mapOf(userDataMap['weeklyChallenge']),
        ),
        habits: listOfMaps(userDataMap['habits']),
        todos: todos,
        currentTimeOfDay:
            (userDataMap['currentTimeOfDay'] as String?) ??
            _userData.currentTimeOfDay,
      );

      final weekDaysRaw = decoded['weekDays'];
      final restoredWeekDays = <HomeDayStat>[];
      if (weekDaysRaw is List) {
        for (final item in weekDaysRaw) {
          final m = mapOf(item);
          final dateKey = (m['dateKey'] as String?) ?? '';
          if (dateKey.isEmpty) continue;
          restoredWeekDays.add(
            HomeDayStat(
              dateKey: dateKey,
              dayLabel: (m['dayLabel'] as String?) ?? '',
              completed: m['completed'] == true,
              cfScore: _asInt(m['cfScore'], fallback: 0),
              steps: _asInt(m['steps'], fallback: 0),
            ),
          );
        }
      }

      final profile = await _profile.getOrCreateProfile();
      if (!mounted) return false;

      setState(() {
        _userData = restoredUserData;
        _weekDays = restoredWeekDays;
        _weeklyHabitsCompleted = _asInt(
          decoded['weeklyHabitsCompleted'],
          fallback: _weeklyHabitsCompleted,
        );
        _weeklyHabitActiveDays = _asInt(
          decoded['weeklyHabitActiveDays'],
          fallback: _weeklyHabitActiveDays,
        );
        _cityLabel = (decoded['cityLabel'] as String?) ?? _cityLabel;
        _tempLabel = (decoded['tempLabel'] as String?) ?? _tempLabel;
        _weatherEmoji = (decoded['weatherEmoji'] as String?) ?? _weatherEmoji;
        _weatherCode = _asInt(decoded['weatherCode'], fallback: _weatherCode);
        _tempC = decoded['tempC'] is num
            ? (decoded['tempC'] as num).round()
            : _tempC;
        _windKmh = decoded['windKmh'] is num
            ? (decoded['windKmh'] as num).round()
            : _windKmh;
        _suggestionVisible = true;
        _profileModel = profile;
        _loading = false;
        _loadingPrimaryMetrics = false;
        _loadingCollections = true;
        _statusMessage = null;
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistHomeCache() async {
    if (_isRunningWidgetTest) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final u = _userData;

      final todos = u.todos
          .map((t) {
            final next = Map<String, dynamic>.from(t);
            final rawDue = next['dueDateValue'];
            if (rawDue is DateTime) {
              next['dueDateValue'] = rawDue.toIso8601String();
            }
            return next;
          })
          .toList(growable: false);

      final snapshot = <String, Object?>{
        'v': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'userData': <String, Object?>{
          'name': u.name,
          'currentCFIndex': u.currentCFIndex,
          'dailyStreak': u.dailyStreak,
          'weeklyStreak': u.weeklyStreak,
          'moodRegisteredToday': u.moodRegisteredToday,
          'currentMoodIcon': u.currentMoodIcon,
          'waterIntake': u.waterIntake,
          'stepsCount': u.stepsCount,
          'dailyGoal': u.dailyGoal,
          'weeklyGoal': u.weeklyGoal,
          'weeklyChallenge': u.weeklyChallenge,
          'habits': u.habits,
          'todos': todos,
          'currentTimeOfDay': u.currentTimeOfDay,
        },
        'weekDays': [
          for (final d in _weekDays)
            <String, Object?>{
              'dateKey': d.dateKey,
              'dayLabel': d.dayLabel,
              'completed': d.completed,
              'cfScore': d.cfScore,
              'steps': d.steps,
            },
        ],
        'weeklyHabitsCompleted': _weeklyHabitsCompleted,
        'weeklyHabitActiveDays': _weeklyHabitActiveDays,
        'cityLabel': _cityLabel,
        'tempLabel': _tempLabel,
        'weatherEmoji': _weatherEmoji,
        'weatherCode': _weatherCode,
        'tempC': _tempC,
        'windKmh': _windKmh,
      };

      await prefs.setString(_kHomeCacheKey, jsonEncode(snapshot));
    } catch (_) {
      // Ignore cache failures.
    }
  }

  List<int> _fallbackStepSeries30() {
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final todayKey = DateUtilsCF.toKey(today);
    final byKey = <String, int>{
      for (final day in _weekDays) day.dateKey: day.steps,
    };
    final todaySteps = _userData.stepsCount['current'] ?? 0;

    return List<int>.generate(30, (index) {
      final day = today.subtract(Duration(days: 29 - index));
      final key = DateUtilsCF.toKey(day);
      if (key == todayKey) {
        return todaySteps > 0 ? todaySteps : (byKey[key] ?? 0);
      }
      return byKey[key] ?? 0;
    });
  }

  Future<List<int>> _fallbackCfSeries30() async {
    final history = await _storage.getCfHistory();
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final todayKey = DateUtilsCF.toKey(today);
    final byKey = <String, int>{
      for (final day in _weekDays) day.dateKey: day.cfScore,
    };

    return List<int>.generate(30, (index) {
      final day = today.subtract(Duration(days: 29 - index));
      final key = DateUtilsCF.toKey(day);
      final fromHistory = history[key];
      if (fromHistory != null) return fromHistory;
      if (key == todayKey) {
        return _userData.currentCFIndex;
      }
      return byKey[key] ?? 0;
    });
  }

  List<int> _takeLastDays(
    List<int> source,
    int days, {
    required List<int> fallback,
  }) {
    if (source.length >= days) {
      return List<int>.from(source.sublist(source.length - days));
    }
    if (source.isEmpty) return List<int>.from(fallback);
    return List<int>.filled(days - source.length, 0, growable: true)
      ..addAll(source);
  }

  Future<void> _warmHomeDialogMetrics() {
    final existing = _dialogMetricsPrefetchFuture;
    if (existing != null) return existing;

    final future = _loadDialogMetricsCache();
    _dialogMetricsPrefetchFuture = future;
    return future.whenComplete(() {
      if (identical(_dialogMetricsPrefetchFuture, future)) {
        _dialogMetricsPrefetchFuture = null;
      }
    });
  }

  Future<void> _loadDialogMetricsCache() async {
    final localCfSeries = await _fallbackCfSeries30();
    final localStepSeries = _fallbackStepSeries30();

    if (mounted) {
      setState(() {
        if (_cfSeries30Cache.isEmpty) {
          _cfSeries30Cache = localCfSeries;
        }
        if (_stepsSeries30Cache.isEmpty) {
          _stepsSeries30Cache = localStepSeries;
        }
      });
    }

    try {
      final uid = _auth.currentUser?.uid;
      final snapshotFuture = _appPermissions.getSnapshot();
      final cfFuture = uid != null
          ? _dashboard.getCfStats(uid: uid, days: 30)
          : Future<List<int>>.value(localCfSeries);
      final stepsFuture = uid != null
          ? _dashboard.getStepStats(uid: uid, days: 30)
          : Future<List<int>>.value(localStepSeries);

      final results = await Future.wait<Object?>([
        cfFuture,
        stepsFuture,
        snapshotFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _cfSeries30Cache = List<int>.from(results[0] as List<int>);
        _stepsSeries30Cache = List<int>.from(results[1] as List<int>);
        _stepsPermissionStatusCache =
            (results[2] as AppPermissionsSnapshot).steps;
      });
    } catch (_) {
      // Keep local fallback values if refresh fails.
    }
  }

  Future<void> _loadRealData({
    bool withLoader = true,
    bool allowMoodAutoPrompt = false,
  }) async {
    if (mounted) {
      setState(() {
        if (withLoader && !_hasVisibleContent) {
          _loading = true;
        }
        _loadingPrimaryMetrics = true;
        _loadingCollections = true;
        _statusMessage = null;
      });
    }

    UserProfile? profile;
    try {
      await _controller.init();

      final now = DateTime.now();
      final time = _resolveTimeOfDay(now);
      final firebaseUser = _auth.currentUser;
      profile = await _profile.getOrCreateProfile();
      await _workouts.ensureLoaded();
      final uid = firebaseUser?.uid;
      final fallbackName = _fallbackUserName(firebaseUser, profile);

      final essentialData = _userData.copyWith(
        name: fallbackName,
        currentCFIndex: _controller.displayedCfIndex,
        dailyStreak: _controller.streakCount,
        waterIntake: {
          'current': (_controller.todayData.waterLiters * 1000).round(),
          'target': 2000,
        },
        stepsCount: {'current': _controller.todayData.steps, 'target': 8000},
        currentTimeOfDay: time,
      );

      if (!mounted) return;
      setState(() {
        _userData = essentialData;
        _profileModel = profile;
        _suggestionVisible = true;
        _loading = false;
        _loadingPrimaryMetrics = false;
      });

      HomeDashboardData? dashboardData;
      Map<String, dynamic>? homeConfig;
      Map<String, dynamic>? homeHeader;
      Map<String, dynamic>? dailyMood;
      String? preferredName;
      if (uid != null) {
        final results = await Future.wait([
          _dashboard.loadDashboard(
            uid: uid,
            todayKey: _controller.todayKey,
            todayCfScore: _controller.displayedCfIndex,
            profile: profile,
          ),
          _dashboard.getUserHomeConfig(uid: uid),
          _dashboard.getDailyHomeHeader(
            uid: uid,
            dateKey: _controller.todayKey,
          ),
          _dashboard.getDailyMood(uid: uid, dateKey: _controller.todayKey),
          _dashboard.getUserPreferredName(
            uid: uid,
            fallbackEmail: firebaseUser?.email,
          ),
        ]);
        dashboardData = results[0] as HomeDashboardData?;
        homeConfig = results[1] as Map<String, dynamic>?;
        homeHeader = results[2] as Map<String, dynamic>?;
        dailyMood = results[3] as Map<String, dynamic>?;
        preferredName = results[4] as String?;
      }

      final resolvedName = (preferredName ?? '').trim().isNotEmpty
          ? (preferredName ?? '').trim()
          : fallbackName;

      final profilePlace = (profile.usualTrainingPlace ?? '').trim();
      final configTemp = (homeConfig?['temperatureC'] as num?)?.round();
      final cityLabel = profilePlace.isNotEmpty
          ? profilePlace
          : 'Ubicación no disponible';
      final tempLabel = configTemp == null ? '--°C' : '$configTemp°C';

      final challenge = dashboardData?.weeklyChallenge;
      final habits = dashboardData?.habits ?? const <HabitItem>[];
      final tasks = dashboardData?.tasks ?? const <TaskItem>[];

      final habitsMapped = habits
          .map(
            (h) => {
              'id': h.id,
              'name': h.name,
              'repeatDays': h.repeatDays,
              'difficulty': _pointsToDifficulty(h.cfReward),
              'cfPoints': h.cfReward,
              'isCompleted': h.isCompletedToday,
            },
          )
          .toList();

      final todosMapped = tasks
          .map(
            (t) => {
              'id': t.id,
              'name': t.title,
              'dueDate': _dueDateLabel(t.dueDate),
              'dueDateValue': t.dueDate,
              'difficulty': _pointsToDifficulty(t.cfReward),
              'cfPoints': t.cfReward,
              'isCompleted': t.completed,
              'notificationEnabled': t.notificationEnabled,
            },
          )
          .toList();

      final configuredDailyGoal = ((homeConfig?['dailyGoal'] is Map)
          ? Map<String, dynamic>.from(homeConfig?['dailyGoal'] as Map)
          : {
              'type': _userData.dailyGoal['type'] ?? 'Entrenamiento',
              'description':
                  _userData.dailyGoal['description'] ??
                  'Completar misión diaria',
              'target': _userData.dailyGoal['target'] ?? 100,
            });

      final configuredWeeklyGoal = ((homeConfig?['weeklyGoal'] is Map)
          ? Map<String, dynamic>.from(homeConfig?['weeklyGoal'] as Map)
          : {
              'type': _userData.weeklyGoal['type'] ?? 'Hábitos',
              'description':
                  _userData.weeklyGoal['description'] ??
                  'Cumplir objetivos semanales',
              'target': _userData.weeklyGoal['target'] ?? 100,
            });

      final dailyProgress = _computeDailyGoalProgress(
        goalType: (configuredDailyGoal['type'] as String? ?? 'Entrenamiento')
            .trim(),
        target: _asInt(configuredDailyGoal['target'], fallback: 1),
        habitsMapped: habitsMapped,
      );
      final weeklyProgress = _computeWeeklyGoalProgress(
        goalType: (configuredWeeklyGoal['type'] as String? ?? 'Hábitos').trim(),
        target: _asInt(configuredWeeklyGoal['target'], fallback: 1),
        dashboardData: dashboardData,
        habitsMapped: habitsMapped,
      );
      final hasMood =
          (dailyMood != null && dailyMood.isNotEmpty) ||
          dashboardData?.hasMoodToday == true ||
          (_controller.todayData.energy != null &&
              _controller.todayData.mood != null &&
              _controller.todayData.stress != null &&
              _controller.todayData.sleep != null);
      final moodIcon =
          ((dailyMood?['emoji'] as String?) ??
                  (homeHeader?['moodIcon'] as String?) ??
                  '')
              .trim();

      final next = essentialData.copyWith(
        name: resolvedName,
        currentCFIndex: _controller.displayedCfIndex,
        dailyStreak: dashboardData?.streak ?? essentialData.dailyStreak,
        weeklyStreak: dashboardData?.weeklyStreak ?? 0,
        moodRegisteredToday: hasMood,
        currentMoodIcon: moodIcon.isNotEmpty
            ? moodIcon
            : essentialData.currentMoodIcon,
        dailyGoal: {...configuredDailyGoal, 'progress': dailyProgress},
        weeklyGoal: {...configuredWeeklyGoal, 'progress': weeklyProgress},
        weeklyChallenge: {
          'id': challenge?.id ?? '',
          'weekId': challenge?.weekId ?? '',
          'title': challenge?.title ?? 'Sin reto activo',
          'description':
              challenge?.description ??
              'No hay reto activo. ¡Pronto uno nuevo!',
          'userProgress': challenge?.progressValue ?? 0,
          'target': challenge?.targetValue ?? 1,
          'communityCompletionPct': challenge?.communityCompletionPct ?? 0,
          'reward': '+${challenge?.rewardCfBonus ?? 0} CF',
          'rewardCfBonus': challenge?.rewardCfBonus ?? 0,
          'completed': challenge?.completed ?? false,
          'isActive': challenge != null,
        },
        habits: habitsMapped,
        todos: todosMapped,
        currentTimeOfDay: time,
      );

      if (!mounted) return;
      final suggestions = _suggestionsForNow();
      setState(() {
        _userData = next;
        _profileModel = profile;
        _weekDays = dashboardData?.weekDays ?? const [];
        _weeklyHabitsCompleted = dashboardData?.weeklyHabitsCompleted ?? 0;
        _weeklyHabitActiveDays = dashboardData?.weeklyHabitActiveDays ?? 0;
        _todayMoodEntry = dailyMood;
        _cityLabel = cityLabel;
        _tempLabel = tempLabel;
        _suggestionVisible = true;
        _loadingCollections = false;
        _statusMessage = null;
        if (_suggestionIndex >= suggestions.length) {
          _suggestionIndex = 0;
        }
      });
      unawaited(_syncTaskReminders(todosMapped));

      if (uid != null && challenge != null) {
        unawaited(
          _claimWeeklyChallengeRewardIfEligible(uid: uid, challenge: challenge),
        );
      }

      if (uid != null) {
        unawaited(
          _dashboard.saveDailyStatsSnapshot(
            uid: uid,
            dateKey: _controller.todayKey,
            cfIndex: next.currentCFIndex,
            steps: next.stepsCount['current'] ?? 0,
            waterMl: next.waterIntake['current'] ?? 0,
          ),
        );
        unawaited(
          _dashboard.saveDailyHomeHeader(
            uid: uid,
            dateKey: _controller.todayKey,
            timeOfDay: next.currentTimeOfDay,
            moodRegistered: next.moodRegisteredToday,
            moodIcon: next.currentMoodIcon,
            suggestion: _suggestionForStorage(),
          ),
        );
      }
      unawaited(_refreshEnvironmentInfo());
      unawaited(_persistHomeCache());
    } catch (_) {
      final fallbackTime = _resolveTimeOfDay(DateTime.now());
      final fallbackUser = _auth.currentUser;
      final fallbackName = _fallbackUserName(fallbackUser, profile);

      if (!mounted) return;
      setState(() {
        _userData = _userData.copyWith(
          name: fallbackName,
          currentTimeOfDay: fallbackTime,
        );
        _cityLabel = 'Ubicación no disponible';
        _tempLabel = '--°C';
        _suggestionVisible = true;
        _loadingPrimaryMetrics = false;
        _loadingCollections = false;
        _statusMessage = _hasVisibleContent
            ? 'No se detecta una fuente de internet. Mostrando los últimos datos guardados.'
            : 'No se detecta una fuente de internet. Las secciones se completarán cuando vuelva la conexión.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
      unawaited(_warmHomeDialogMetrics());
      if (allowMoodAutoPrompt) {
        _scheduleMoodAutoPrompt();
      }
    }
  }

  String _resolveTimeOfDay(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h <= 11) return 'morning';
    if (h >= 12 && h <= 17) return 'afternoon';
    if (h >= 18 && h <= 21) return 'evening';
    return 'night';
  }

  void _startClockTicker() {
    _clockTimer?.cancel();
    _clockStartTimer?.cancel();
    _clockNow = DateTime.now();
    final secondsToNextMinute = 60 - _clockNow.second;

    _clockStartTimer = Timer(Duration(seconds: secondsToNextMinute), () {
      if (!mounted) return;
      setState(() {
        _clockNow = DateTime.now();
      });

      _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        setState(() {
          _clockNow = DateTime.now();
        });
      });
    });
  }

  void _startEnvironmentTicker() {
    _environmentTimer?.cancel();
    _environmentTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _refreshEnvironmentInfo();
    });
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

  Future<void> _refreshEnvironmentInfo() async {
    if (_isRunningWidgetTest) return;
    final fallbackEmoji = _clockNow.hour >= 7 && _clockNow.hour < 20
        ? '☀️'
        : '🌙';
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _cityLabel = 'Activa ubicación';
          _tempLabel = '--°C';
          _weatherEmoji = fallbackEmoji;
          _tempC = null;
          _weatherCode = -1;
          _windKmh = null;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _cityLabel = 'Permite ubicación';
          _tempLabel = '--°C';
          _weatherEmoji = fallbackEmoji;
          _tempC = null;
          _weatherCode = -1;
          _windKmh = null;
        });
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {
        pos = null;
      }

      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 10));

      String city = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        ).timeout(const Duration(seconds: 8));
        final place = placemarks.isNotEmpty ? placemarks.first : null;
        city =
            (place?.locality ??
                    place?.subAdministrativeArea ??
                    place?.administrativeArea ??
                    '')
                .trim();
      } catch (_) {
        city = '';
      }

      int? temp;
      int weatherCode = -1;
      bool isDay = _clockNow.hour >= 7 && _clockNow.hour < 20;
      int? windKmh;
      String timezoneName = '';

      try {
        final candidates = <Uri>[
          Uri.parse(
            'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current=temperature_2m,weather_code,is_day,wind_speed_10m&timezone=auto',
          ),
          Uri.parse(
            'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current=temperature_2m,weather_code,is_day,windspeed_10m&timezone=auto',
          ),
          Uri.parse(
            'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current=temperature_2m,weather_code,is_day&timezone=auto',
          ),
        ];

        http.Response? response;
        for (final uri in candidates) {
          try {
            final r = await http.get(uri).timeout(const Duration(seconds: 10));
            if (r.statusCode >= 200 && r.statusCode < 300) {
              response = r;
              break;
            }
          } catch (_) {
            // keep trying
          }
        }

        if (response != null) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final current = decoded['current'];
            if (current is Map<String, dynamic>) {
              temp = (current['temperature_2m'] as num?)?.round();
              weatherCode = (current['weather_code'] as num?)?.toInt() ?? -1;
              final isDayRaw = (current['is_day'] as num?)?.toInt();
              if (isDayRaw != null) isDay = isDayRaw == 1;
              final wind =
                  (current['wind_speed_10m'] as num?) ??
                  (current['windspeed_10m'] as num?);
              windKmh = wind?.round();
            }
            timezoneName = (decoded['timezone'] as String? ?? '').trim();
          }
        }
      } catch (_) {
        // best-effort
      }

      if (city.isEmpty && timezoneName.contains('/')) {
        city = timezoneName.split('/').last.replaceAll('_', ' ');
      }

      if (!mounted) return;
      setState(() {
        _cityLabel = city.isNotEmpty ? city : 'Ubicación detectada';
        _tempLabel = temp == null ? '--°C' : '$temp°C';
        _tempC = temp;
        _weatherCode = weatherCode;
        _windKmh = windKmh;
        _weatherEmoji = weatherCode == -1
            ? (isDay ? '☀️' : '🌙')
            : _weatherEmojiFor(weatherCode: weatherCode, isDay: isDay);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherEmoji = fallbackEmoji;
      });
    }
  }

  bool _isRainOrSnowCode(int code) {
    // Open-Meteo WMO Weather interpretation codes.
    // Treat precipitation + storms + snow as "rainy" for activity advice.
    if (code < 0) return false;
    if (code == 45 || code == 48) return false; // fog
    if (code >= 51 && code <= 67) return true; // drizzle/rain/freezing rain
    if (code >= 71 && code <= 77) return true; // snow
    if (code >= 80 && code <= 82) return true; // rain showers
    if (code >= 85 && code <= 86) return true; // snow showers
    if (code >= 95 && code <= 99) return true; // thunderstorm
    return false;
  }

  String _weatherRecommendation() {
    final hasWeather = _tempC != null || _weatherCode != -1;
    if (!hasWeather) {
      return 'Activa la ubicación para ver el clima y recomendaciones.';
    }

    final windy = (_windKmh != null && _windKmh! >= 35);
    final rainy = _isRainOrSnowCode(_weatherCode);
    final temp = _tempC;

    if (rainy || windy) {
      if (rainy && windy) {
        return 'Hay lluvia y viento: mejor quédate en casa y haz un entreno indoor.';
      }
      if (rainy) {
        return 'Parece que llueve: mejor entrena en casa (fuerza, core o movilidad).';
      }
      return 'Hace mucho viento: mejor entreno en casa o zona cubierta.';
    }

    if (temp != null && temp >= 30) {
      return 'Hace mucho calor: si sales, hidrátate y evita las horas centrales.';
    }
    if (temp != null && temp <= 5) {
      return 'Hace bastante frío: si sales, abrígate y calienta bien antes.';
    }

    return 'Buen clima para salir: paseo rápido, caminar o cardio suave al aire libre.';
  }

  Widget _weatherBlock() {
    final isServiceDisabled = _cityLabel == 'Activa ubicación';
    final isPermissionMissing = _cityLabel == 'Permite ubicación';
    final hint = isServiceDisabled
        ? 'Activa la ubicación del teléfono para ver el clima.'
        : isPermissionMissing
        ? 'Permite la ubicación para mostrar ciudad y temperatura.'
        : _weatherRecommendation();

    final now = TimeOfDay.fromDateTime(_clockNow);
    final timeLabel =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final tempInline = _tempC != null ? '$_tempC°C' : _tempLabel;
    final conditionInline = _weatherCode == -1
        ? '—'
        : _weatherConditionLabel(_weatherCode);
    final mainLine = '$tempInline · $conditionInline $_weatherEmoji';
    final secondaryLine = '$_cityLabel · $timeLabel';

    return _block(
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        onTap: () async {
          try {
            final serviceEnabled = await Geolocator.isLocationServiceEnabled();
            if (!serviceEnabled) {
              await Geolocator.openLocationSettings();
              return;
            }

            var permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await LocationPermissionService.ensurePermission();
            }
            if (permission == LocationPermission.deniedForever) {
              await Geolocator.openAppSettings();
              return;
            }

            await _refreshEnvironmentInfo();
          } catch (_) {
            // best-effort
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mainLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              secondaryLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
                color: context.cfTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _weatherEmojiFor({required int weatherCode, required bool isDay}) {
    if (weatherCode == 0) return isDay ? '☀️' : '🌙';
    if (weatherCode == 1 || weatherCode == 2) return '🌤️';
    if (weatherCode == 3 || weatherCode == 45 || weatherCode == 48) return '☁️';
    if (weatherCode == 51 || weatherCode == 53 || weatherCode == 55) {
      return '🌦️';
    }
    if (weatherCode == 61 || weatherCode == 63 || weatherCode == 65) {
      return '🌧️';
    }
    if (weatherCode == 71 ||
        weatherCode == 73 ||
        weatherCode == 75 ||
        weatherCode == 77) {
      return '❄️';
    }
    if (weatherCode == 80 || weatherCode == 81 || weatherCode == 82) {
      return '🌧️';
    }
    if (weatherCode == 95 || weatherCode == 96 || weatherCode == 99) {
      return '⛈️';
    }
    return isDay ? '☀️' : '🌙';
  }

  String _weatherConditionLabel(int code) {
    if (code == 0) return 'Despejado';
    if (code == 1) return 'Mayormente despejado';
    if (code == 2) return 'Parcialmente nublado';
    if (code == 3) return 'Nublado';
    if (code == 45 || code == 48) return 'Niebla';
    if (code == 51 || code == 53 || code == 55) return 'Llovizna';
    if (code == 56 || code == 57) return 'Llovizna helada';
    if (code == 61 || code == 63 || code == 65) return 'Lluvia';
    if (code == 66 || code == 67) return 'Lluvia helada';
    if (code == 71 || code == 73 || code == 75 || code == 77) return 'Nieve';
    if (code == 80 || code == 81 || code == 82) return 'Chubascos';
    if (code == 85 || code == 86) return 'Chubascos de nieve';
    if (code == 95 || code == 96 || code == 99) return 'Tormenta';
    return '—';
  }

  String _pointsToDifficulty(int points) {
    if (points >= 25) return 'Épica';
    if (points >= 15) return 'Difícil';
    if (points >= 10) return 'Media';
    return 'Fácil';
  }

  int _asInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  int _computeDailyGoalProgress({
    required String goalType,
    required int target,
    required List<Map<String, dynamic>> habitsMapped,
  }) {
    final t = target <= 0 ? 1 : target;
    final type = goalType.toLowerCase();

    if (type.contains('entren')) {
      if (t <= 1) return _controller.workoutCompleted ? 1 : 0;
      return _controller.todayData.activeMinutes.clamp(0, t);
    }
    if (type.contains('nutri')) {
      return _controller.mealsLoggedCount.clamp(0, t);
    }
    if (type.contains('hidra')) {
      final currentMl = (_controller.todayData.waterLiters * 1000).round();
      return currentMl.clamp(0, t);
    }
    if (type.contains('medita')) {
      return _controller.todayData.meditationMinutes.clamp(0, t);
    }
    if (type.contains('paso')) {
      return _controller.todayData.steps.clamp(0, t);
    }
    if (type.contains('háb') || type.contains('habi')) {
      final done = habitsMapped.where((h) => h['isCompleted'] == true).length;
      return done.clamp(0, t);
    }

    return (_controller.dailyMissionProgress * t).round().clamp(0, t);
  }

  int _computeWeeklyGoalProgress({
    required String goalType,
    required int target,
    required HomeDashboardData? dashboardData,
    required List<Map<String, dynamic>> habitsMapped,
  }) {
    final t = target <= 0 ? 1 : target;
    final type = goalType.toLowerCase();
    final weekly = dashboardData?.weeklyGoals;

    if (type.contains('entren')) {
      return (weekly?.trainingDays ?? 0).clamp(0, t);
    }
    if (type.contains('nutri')) {
      return (weekly?.healthyEatingDays ?? 0).clamp(0, t);
    }
    if (type.contains('hidra')) {
      return _controller.weekWaterDays.clamp(0, t);
    }
    if (type.contains('medita')) {
      return (weekly?.meditationDays ?? 0).clamp(0, t);
    }
    if (type.contains('paso')) {
      final totalSteps = (dashboardData?.weekDays ?? const <HomeDayStat>[])
          .fold<int>(0, (acc, day) => acc + day.steps);
      if (t >= 20000) return totalSteps.clamp(0, t);
      return (weekly?.stepsDays6000 ?? 0).clamp(0, t);
    }
    if (type.contains('háb') || type.contains('habi')) {
      final weeklyCompleted = dashboardData?.weeklyHabitsCompleted ?? 0;
      final weeklyDays = dashboardData?.weeklyHabitActiveDays ?? 0;
      if (t <= 7) {
        return weeklyDays.clamp(0, t);
      }
      return weeklyCompleted.clamp(0, t);
    }

    return ((weekly?.progress ?? _controller.weeklyMissionProgress) * t)
        .round()
        .clamp(0, t);
  }

  String _fallbackUserName(User? firebaseUser, UserProfile? profile) {
    final profileName = (profile?.name ?? '').trim();
    if (profileName.isNotEmpty) return profileName;

    final displayName = (firebaseUser?.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;

    final email = (firebaseUser?.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;

    return 'Usuario';
  }

  Future<void> _syncTaskReminders(List<Map<String, dynamic>> tasks) async {
    for (final task in tasks) {
      final taskId = (task['id'] as String? ?? '').trim();
      if (taskId.isEmpty) continue;

      final rawDueDate = task['dueDateValue'];
      final dueDate = rawDueDate is DateTime
          ? rawDueDate
          : DateTime.tryParse(rawDueDate?.toString() ?? '');

      await TaskReminderService.instance.syncTaskReminder(
        taskId: taskId,
        title: (task['name'] as String? ?? 'Tarea pendiente').trim(),
        dueDate: dueDate,
        enabled: task['notificationEnabled'] == true,
        completed: task['isCompleted'] == true,
      );
    }
  }

  String _dueDateLabel(DateTime? dueDate) {
    if (dueDate == null) return 'Sin fecha';
    final localizations = MaterialLocalizations.of(context);
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final due = DateUtilsCF.dateOnly(dueDate);
    final diff = due.difference(today).inDays;
    final timeLabel = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(dueDate),
      alwaysUse24HourFormat: true,
    );
    if (diff == 0) return 'Hoy · $timeLabel';
    if (diff == 1) return 'Mañana · $timeLabel';
    return '${localizations.formatShortDate(dueDate)} · $timeLabel';
  }

  String _dueDateEditorLabel(DateTime dueDate) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatFullDate(dueDate)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(dueDate), alwaysUse24HourFormat: true)}';
  }

  String _repeatDaysLabel(Object? rawRepeatDays) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    if (rawRepeatDays is! List) return 'Todos los días';

    final days =
        rawRepeatDays
            .map((e) {
              if (e is int) return e;
              if (e is num) return e.round();
              return int.tryParse(e.toString());
            })
            .whereType<int>()
            .where((d) => d >= 1 && d <= 7)
            .toSet()
            .toList()
          ..sort();

    if (days.isEmpty) return 'Todos los días';
    return days.map((d) => labels[d - 1]).join(' ');
  }

  ({String greeting, String question}) _greetingFor() {
    final name = _userData.name;
    switch (_userData.currentTimeOfDay) {
      case 'morning':
        return (
          greeting: 'Buenos días, $name',
          question: '¿Cómo te despertaste hoy?',
        );
      case 'afternoon':
        return (
          greeting: 'Buenas tardes, $name',
          question: '¿Qué quieres hacer ahora?',
        );
      case 'evening':
        return (
          greeting: 'Buenas noches, $name',
          question: '¿Qué te apetece hacer?',
        );
      default:
        return (
          greeting: 'Buenas noches, $name',
          question: '¿Qué quieres hacer antes de dormir?',
        );
    }
  }

  String _streakLine() {
    final streak = _userData.dailyStreak;
    return 'Llevas $streak dias seguidos en ${_streakLabel().toLowerCase()} 🔥';
  }

  String _streakLabel() {
    final profile = _profileModel;
    if (profile == null || !profile.hasPersonalizedStreakPreferences) {
      return 'tu racha';
    }

    final title = profile.effectiveStreakPreferences.title;
    if (title == 'Mix flexible' || title == 'Mix completo') {
      return 'tu racha personalizada';
    }
    return 'tu racha de ${title.toLowerCase()}';
  }

  String _streakCardLabel() {
    final profile = _profileModel;
    if (profile == null || !profile.hasPersonalizedStreakPreferences) {
      return 'Racha';
    }

    final chip = profile.effectiveStreakPreferences.chipLabel;
    if (chip == 'Mix flexible' || chip == 'Mix total') {
      return 'Racha mix';
    }
    return chip;
  }

  String _coachMicroMessage() {
    final daily = (_userData.dailyGoal['progress'] as int? ?? 0).clamp(0, 100);
    final weekly = (_userData.weeklyGoal['progress'] as int? ?? 0).clamp(
      0,
      100,
    );
    final streak = _userData.dailyStreak;
    if (streak >= 7) return 'Tu constancia ya marca diferencia.';
    if (daily >= 80) return 'Cierra fuerte, hoy casi lo completas.';
    if (weekly >= 70) return 'Buen ritmo, protege tu ventaja semanal.';
    if (streak >= 3) return 'No sueltes, estás en una buena racha.';
    return 'Empieza simple, hoy cuenta de verdad.';
  }

  String _moodText(Map<String, dynamic> insight) {
    final icon = ((insight['moodIcon'] as String?) ?? '').trim();
    final moodValue = _asInt(insight['moodValue'], fallback: 0);
    if (moodValue >= 4) return 'Contento';
    if (moodValue == 3) return 'Neutral';
    if (moodValue > 0) return 'Bajo';
    if (icon == '😄' || icon == '🙂' || icon == ':D') return 'Contento';
    if (icon == '😐') return 'Neutral';
    if (icon == '🙁') return 'Bajo';
    if (icon == '😩') return 'Cansado';
    if (insight['moodRegistered'] == true) return 'Registrado';
    return 'Sin registrar';
  }

  String _sportSummary(Map<String, dynamic> insight) {
    final steps = (insight['steps'] as int? ?? 0);
    final workout = insight['workoutCompleted'] == true;
    if (workout && steps >= 8000) return 'Entreno completado y buen volumen.';
    if (workout) return 'Entreno completado hoy.';
    if (steps >= 8000) return 'Buen movimiento diario con pasos altos.';
    if (steps >= 4000) return 'Actividad moderada, puedes cerrar fuerte.';
    return 'Actividad baja hoy, suma un bloque corto.';
  }

  String _foodSummary(Map<String, dynamic> insight) {
    final meals = (insight['mealsLoggedCount'] as int? ?? 0);
    if (meals >= 3) return 'Alimentación completa y bien registrada.';
    if (meals == 2) return 'Vas bien, falta una comida por registrar.';
    if (meals == 1) return 'Registro parcial, añade más consistencia.';
    return 'Sin registro de comidas en este día.';
  }

  Future<void> _showMoodCheckModal() async {
    final previousMood = _todayMoodEntry ?? const <String, dynamic>{};
    final hadMoodBefore =
        previousMood.isNotEmpty || _userData.moodRegisteredToday;

    String emojiLabel(Object? value) {
      final s = (value as String? ?? '').trim();
      return s;
    }

    final initialEmoji = emojiLabel(previousMood['emoji']);
    final emoji = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Hola, ${_userData.name}! ¿Cómo te sientes hoy?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ['😄', '🙂', '😐', '🙁', '😩']
                  .map(
                    (icon) => InkWell(
                      onTap: () => Navigator.of(context).pop(icon),
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: initialEmoji == icon
                                ? context.cfPrimary
                                : context.cfBorder,
                          ),
                          color: initialEmoji == icon
                              ? context.cfPrimaryTint
                              : context.cfSurface,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(14),
                          ),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 34)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );

    if (emoji == null || !mounted) return;

    int energy = _asInt(previousMood['energy'], fallback: 3).clamp(1, 5);
    int mood = _asInt(previousMood['mood'], fallback: 3).clamp(1, 5);
    int stress = _asInt(previousMood['stress'], fallback: 3).clamp(1, 5);
    int sleep = _asInt(previousMood['sleep'], fallback: 3).clamp(1, 5);
    final tags = <String>{
      ...(previousMood['tags'] is List
          ? (previousMood['tags'] as List).map((e) => e.toString())
          : const <String>[]),
    };

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuéntanos más (opcional)',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _levelRow(
                  '¿Cuánta energía tienes hoy?',
                  energy,
                  (v) => setLocal(() => energy = v),
                ),
                _levelRow(
                  '¿Estás animado?',
                  mood,
                  (v) => setLocal(() => mood = v),
                ),
                _levelRow(
                  '¿Hoy estás estresado?',
                  stress,
                  (v) => setLocal(() => stress = v),
                ),
                _levelRow(
                  '¿Cómo has dormido?',
                  sleep,
                  (v) => setLocal(() => sleep = v),
                ),
                const Text(
                  '1 es poco · 5 es mucho',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            '#DormíPoco',
                            '#EntrenoDuro',
                            '#MuchoTrabajo',
                            '#BuenDía',
                            '#EstrésAlto',
                          ]
                          .map(
                            (tag) => FilterChip(
                              selected: tags.contains(tag),
                              label: Text(tag),
                              onSelected: (_) {
                                setLocal(() {
                                  if (tags.contains(tag)) {
                                    tags.remove(tag);
                                  } else {
                                    tags.add(tag);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Saltar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await _controller.setEnergy(energy);
    await _controller.setMood(mood);
    await _controller.setStress(stress);
    await _controller.setSleep(sleep);
    await _controller.markMoodPromptShownToday();

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _dashboard.saveDailyMood(
        uid: uid,
        dateKey: _controller.todayKey,
        emoji: emoji,
        energy: energy,
        mood: mood,
        stress: stress,
        sleep: sleep,
        tags: tags.toList()..sort(),
      );
    }

    if (!mounted) return;
    final bonus = hadMoodBefore ? 0 : (saved == true ? 3 : 1);
    setState(() {
      _userData = _userData.copyWith(
        moodRegisteredToday: true,
        currentMoodIcon: emoji,
        currentCFIndex: (_userData.currentCFIndex + bonus).clamp(0, 100),
      );
      _todayMoodEntry = {
        'emoji': emoji,
        'energy': energy,
        'mood': mood,
        'stress': stress,
        'sleep': sleep,
        'tags': tags.toList()..sort(),
        'registered': true,
      };
    });
    if (uid != null) {
      await _dashboard.saveDailyHomeHeader(
        uid: uid,
        dateKey: _controller.todayKey,
        timeOfDay: _userData.currentTimeOfDay,
        moodRegistered: true,
        moodIcon: emoji,
        suggestion: _suggestionForStorage(),
      );
    }
  }

  Widget _levelRow(String title, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Row(
            children: List.generate(5, (i) {
              final level = i + 1;
              return IconButton(
                onPressed: () => onChanged(level),
                icon: Icon(
                  level <= value ? Icons.circle : Icons.circle_outlined,
                  size: 16,
                  color: level <= value
                      ? context.cfPrimary
                      : context.cfTextSecondary,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _goToTab(int index, String fallbackTitle) {
    final nav = HomeNavigation.maybeOf(context);
    if (nav != null) {
      nav.goToTab(index);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceholderScreen(title: fallbackTitle),
      ),
    );
  }

  Future<void> _showMonthCalendarDialog() async {
    DateTime selected = DateTime.now();
    Map<String, dynamic> insight = const <String, dynamic>{};

    Future<void> loadInsightFor(DateTime date) async {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        insight = const <String, dynamic>{};
        return;
      }
      insight = await _dashboard.getDailyInsight(
        uid: uid,
        dateKey: DateUtilsCF.toKey(date),
      );
    }

    await loadInsightFor(selected);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Semana y calendario completo'),
          content: SizedBox(
            width: 360,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CalendarDatePicker(
                      initialDate: selected,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      onDateChanged: (d) async {
                        selected = d;
                        await loadInsightFor(d);
                        setLocal(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Detalle del día ${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Puntuaje CF: ${insight['cfIndex'] ?? 0}'),
                    Text('Pasos: ${insight['steps'] ?? 0}'),
                    Text(
                      'Agua: ${(((insight['waterLiters'] as num?) ?? 0).toDouble()).toStringAsFixed(1)} L',
                    ),
                    Text('Estado de ánimo: ${_moodText(insight)}'),
                    Text('Resumen de deporte: ${_sportSummary(insight)}'),
                    Text('Resumen de alimentación: ${_foodSummary(insight)}'),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCfAndStreakDialog() async {
    final fallbackSeries = _cfSeries30Cache.isNotEmpty
        ? List<int>.from(_cfSeries30Cache)
        : await _fallbackCfSeries30();

    List<int> normalizeSeries(List<int> source) {
      if (source.isEmpty) return const [0];
      final hasVariation = source.any((v) => v != source.first);
      if (hasVariation) return source;
      return List<int>.generate(
        source.length,
        (i) => (source.first + (i.isEven ? 0 : 1)).clamp(0, 100),
      );
    }

    List<int> pickSeries(List<int> source, int days) {
      if (source.length <= days) return normalizeSeries(source);
      return normalizeSeries(source.sublist(source.length - days));
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var selectedDays = 14;
        var cfSeries30 = fallbackSeries;
        var refreshing = false;
        var refreshStarted = false;

        Future<void> refreshDialogMetrics(
          void Function(VoidCallback fn) setDialogState,
        ) async {
          if (refreshing) return;

          setDialogState(() {
            refreshing = true;
          });

          try {
            await _warmHomeDialogMetrics();
            if (!mounted || !dialogContext.mounted) return;

            final refreshedSeries = _cfSeries30Cache.isNotEmpty
                ? List<int>.from(_cfSeries30Cache)
                : await _fallbackCfSeries30();
            if (!mounted || !dialogContext.mounted) return;

            setDialogState(() {
              cfSeries30 = refreshedSeries;
              refreshing = false;
            });
          } catch (_) {
            if (!dialogContext.mounted) return;
            setDialogState(() {
              refreshing = false;
            });
          }
        }

        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('Racha y puntuaje CF'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Puntuaje CF (últimos $selectedDays días)'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [7, 14, 30]
                        .map(
                          (d) => ChoiceChip(
                            label: Text('${d}d'),
                            selected: selectedDays == d,
                            onSelected: (_) => setLocal(() => selectedDays = d),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  if (!refreshStarted) ...[
                    Builder(
                      builder: (_) {
                        refreshStarted = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!dialogContext.mounted) return;
                          unawaited(refreshDialogMetrics(setLocal));
                        });
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                  if (refreshing) ...[
                    const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    height: 170,
                    child: _CfHistoryChart(
                      values: pickSeries(cfSeries30, selectedDays),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('${_streakLabel()}: ${_userData.dailyStreak} dias'),
                  Text('Racha semanal: ${_userData.weeklyStreak} semanas'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _goToTab(4, 'Progreso');
                      },
                      child: const Text('Ir a Progreso'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showWaterDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final current = _userData.waterIntake['current'] ?? 0;
          final target = _userData.waterIntake['target'] ?? 2000;
          final progress = (current / (target <= 0 ? 1 : target)).clamp(
            0.0,
            1.0,
          );

          return AlertDialog(
            title: const Text('Hidratación'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 100,
                  width: 100,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: CFColors.softGray,
                    color: CFColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text('$current / $target ml'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await _controller.addWater250ml();
                    final nextMl = (_controller.todayData.waterLiters * 1000)
                        .round();
                    setState(() {
                      _userData = _userData.copyWith(
                        waterIntake: {
                          ..._userData.waterIntake,
                          'current': nextMl,
                        },
                      );
                    });
                    final uid = _auth.currentUser?.uid;
                    if (uid != null) {
                      await _dashboard.saveDailyStatsSnapshot(
                        uid: uid,
                        dateKey: _controller.todayKey,
                        cfIndex: _userData.currentCFIndex,
                        steps: _userData.stepsCount['current'] ?? 0,
                        waterMl: nextMl,
                      );
                    }
                    setLocal(() {});
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir un vaso de agua.'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<int>> _collectStepSeries(int days) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      return _dashboard.getStepStats(uid: uid, days: days);
    }

    final out = <int>[];
    final today = DateUtilsCF.dateOnly(DateTime.now());
    for (var i = days - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final key = DateUtilsCF.toKey(date);
      out.add(_controller.todayKey == key ? _controller.todayData.steps : 0);
    }
    return out;
  }

  Future<void> _showStepsDialog() async {
    final fallbackMonthly = _stepsSeries30Cache.isNotEmpty
        ? List<int>.from(_stepsSeries30Cache)
        : _fallbackStepSeries30();
    final fallbackWeekly = _takeLastDays(
      fallbackMonthly,
      7,
      fallback: _takeLastDays(
        _fallbackStepSeries30(),
        7,
        fallback: List<int>.filled(7, 0),
      ),
    );

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var weeklyValues = fallbackWeekly;
        var monthlyValues = fallbackMonthly;
        var stepsPermissionStatus = _stepsPermissionStatusCache;
        var loadingStepMetrics = false;
        var requestingStepsPermission = false;
        var refreshStarted = false;

        Future<void> refreshStepsData(
          void Function(VoidCallback fn) setDialogState,
        ) async {
          if (loadingStepMetrics) return;

          setDialogState(() => loadingStepMetrics = true);
          try {
            await _warmHomeDialogMetrics();
            if (!mounted || !dialogContext.mounted) return;

            final refreshedMonthly = _stepsSeries30Cache.isNotEmpty
                ? List<int>.from(_stepsSeries30Cache)
                : _fallbackStepSeries30();
            final refreshedWeekly = _takeLastDays(
              refreshedMonthly,
              7,
              fallback: fallbackWeekly,
            );

            setDialogState(() {
              weeklyValues = refreshedWeekly;
              monthlyValues = refreshedMonthly;
              stepsPermissionStatus = _stepsPermissionStatusCache;
              loadingStepMetrics = false;
            });
          } catch (_) {
            if (!dialogContext.mounted) return;
            setDialogState(() => loadingStepMetrics = false);
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> requestStepsPermission() async {
              if (requestingStepsPermission) return;

              setDialogState(() => requestingStepsPermission = true);
              try {
                final status = await _appPermissions.requestStepsPermission();
                if (status == AppPermissionStatus.granted) {
                  await _health.syncTodaySteps();
                  await _loadRealData(withLoader: false);
                  final refreshedMonthly = await _collectStepSeries(30);
                  final refreshedWeekly = _takeLastDays(
                    refreshedMonthly,
                    7,
                    fallback: fallbackWeekly,
                  );
                  if (!mounted) return;
                  setState(() {
                    _stepsSeries30Cache = List<int>.from(refreshedMonthly);
                    _stepsPermissionStatusCache = AppPermissionStatus.granted;
                  });
                  setDialogState(() {
                    weeklyValues = refreshedWeekly;
                    monthlyValues = refreshedMonthly;
                    stepsPermissionStatus = AppPermissionStatus.granted;
                    requestingStepsPermission = false;
                  });
                  _showStepsPermissionSnackBar(
                    'Actividad física activada. Ya puedes sincronizar tus pasos.',
                  );
                  return;
                }

                if (mounted) {
                  setState(() {
                    _stepsPermissionStatusCache = status;
                  });
                }
                setDialogState(() {
                  stepsPermissionStatus = status;
                  requestingStepsPermission = false;
                });
                _showStepsPermissionSnackBar(_stepsPermissionMessage(status));
              } catch (_) {
                if (mounted) {
                  setState(() {
                    _stepsPermissionStatusCache =
                        AppPermissionStatus.unavailable;
                  });
                }
                setDialogState(() {
                  stepsPermissionStatus = AppPermissionStatus.unavailable;
                  requestingStepsPermission = false;
                });
                _showStepsPermissionSnackBar(
                  'No se ha podido activar el acceso a pasos en este dispositivo.',
                );
              }
            }

            return AlertDialog(
              title: const Text('Pasos por semana y mes'),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!refreshStarted) ...[
                        Builder(
                          builder: (_) {
                            refreshStarted = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!dialogContext.mounted) return;
                              unawaited(refreshStepsData(setDialogState));
                            });
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                      if (loadingStepMetrics) ...[
                        const LinearProgressIndicator(minHeight: 3),
                        const SizedBox(height: 12),
                      ],
                      if (stepsPermissionStatus !=
                          AppPermissionStatus.granted) ...[
                        Text(
                          stepsPermissionStatus !=
                                  AppPermissionStatus.unavailable
                              ? 'Activa la actividad física para que CotidyFit pueda leer y sincronizar tus pasos automáticamente.'
                              : 'El acceso a pasos no está disponible ahora mismo en este dispositivo.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (stepsPermissionStatus !=
                            AppPermissionStatus.unavailable) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: requestingStepsPermission
                                  ? null
                                  : requestStepsPermission,
                              icon: requestingStepsPermission
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.directions_walk_rounded),
                              label: Text(
                                requestingStepsPermission
                                    ? 'Activando actividad física...'
                                    : 'Permitir actividad física',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          const SizedBox(height: 16),
                        ],
                      ],
                      const Text('Últimos 7 días'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 170,
                        child: _StepsHistoryChart(values: weeklyValues),
                      ),
                      const SizedBox(height: 12),
                      const Text('Últimos 30 días'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 170,
                        child: _StepsHistoryChart(values: monthlyValues),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStepsPermissionSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _stepsPermissionMessage(AppPermissionStatus status) {
    switch (status) {
      case AppPermissionStatus.granted:
        return 'Actividad física activada. Ya puedes sincronizar tus pasos.';
      case AppPermissionStatus.notRequested:
      case AppPermissionStatus.denied:
        return 'No se ha concedido el acceso a pasos o actividad física.';
      case AppPermissionStatus.unavailable:
        return 'Health Connect no está disponible en este dispositivo.';
    }
  }

  String _heroCfLabel() {
    final cf = _userData.currentCFIndex;
    if (cf >= 85) return 'Excelente';
    if (cf >= 65) return 'Muy bien';
    if (cf >= 45) return 'En progreso';
    return 'Empezando';
  }

  Map<String, dynamic>? _personalizedWorkoutSuggestion() {
    final workouts = _workouts.getAllWorkouts();
    final profile = _profileModel;
    if (workouts.isEmpty || profile == null) return null;

    final hour = DateTime.now().hour;
    final stress = _controller.todayData.stress ?? 3;
    final sleep = _controller.todayData.sleep ?? 3;
    final didWorkout = _controller.workoutCompleted;
    final steps = _userData.stepsCount['current'] ?? 0;
    final availableMinutes = profile.availableMinutes;
    final workType = profile.workType;

    final scored = workouts
        .map((workout) {
          final recommendation = TrainingRecommendationService.scoreWorkout(
            profile: profile,
            workout: workout,
          );

          var contextualScore = recommendation.score;
          final tags = <String>[];
          final name = workout.name.toLowerCase();
          final category = workout.category.toLowerCase();
          final recoveryStyle =
              workout.goals.contains(WorkoutGoal.movilidad) ||
              workout.goals.contains(WorkoutGoal.flexibilidad) ||
              workout.difficulty == WorkoutDifficulty.leve ||
              name.contains('movil') ||
              name.contains('estir') ||
              name.contains('yoga') ||
              category.contains('movil') ||
              category.contains('estir') ||
              category.contains('yoga');

          if (availableMinutes != null && availableMinutes > 0) {
            if (workout.durationMinutes <= availableMinutes) {
              contextualScore += 2;
              tags.add('entra en tu tiempo disponible');
            } else if (workout.durationMinutes > availableMinutes + 10) {
              contextualScore -= 1;
            }
          }

          if (!didWorkout && hour < 12 && workout.durationMinutes <= 20) {
            contextualScore += 1;
            tags.add('es una opción rápida para arrancar el día');
          }

          if (!didWorkout &&
              steps < 2500 &&
              (workType == WorkType.oficina ||
                  workType == WorkType.estudiante)) {
            if (workout.durationMinutes <= 25 || recoveryStyle) {
              contextualScore += 1;
              tags.add('te ayuda a romper el sedentarismo de hoy');
            }
          }

          if (didWorkout) {
            if (recoveryStyle) {
              contextualScore += 2;
              tags.add('favorece recuperación y movilidad');
            } else {
              contextualScore -= 2;
            }
          }

          if (hour >= 19 && (stress >= 4 || sleep <= 2)) {
            if (recoveryStyle) {
              contextualScore += 2;
              tags.add('encaja mejor con tu energía de hoy');
            } else if (workout.difficulty == WorkoutDifficulty.experto) {
              contextualScore -= 2;
            }
          }

          return (
            workout: workout,
            recommendation: recommendation,
            score: contextualScore,
            tags: tags,
          );
        })
        .where((entry) => entry.score >= 0)
        .toList();

    if (scored.isEmpty) return null;

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.workout.durationMinutes.compareTo(b.workout.durationMinutes);
    });

    final best = scored.first;
    final reasons = <String>[
      best.recommendation.explanation,
      ...best.tags,
    ].where((text) => text.trim().isNotEmpty).toList(growable: false);

    return {
      'badge': didWorkout
          ? 'Recuperación personalizada'
          : 'Entrenamiento para ti',
      'title': best.workout.name,
      'microcopy': reasons.isNotEmpty
          ? reasons.take(2).join(' ')
          : 'Te recomendamos esta opción por encaje general con tu perfil.',
      'button': didWorkout ? 'Ver recuperación' : 'Ver entrenamiento',
      'icon': didWorkout
          ? Icons.self_improvement_outlined
          : Icons.fitness_center_outlined,
      'action': 'workout',
      'workout': best.workout,
    };
  }

  List<Map<String, dynamic>> _suggestionsForNow() {
    final h = DateTime.now().hour;
    final steps = _userData.stepsCount['current'] ?? 0;
    final water = _userData.waterIntake['current'] ?? 0;
    final stress = _controller.todayData.stress ?? 3;
    final sleep = _controller.todayData.sleep ?? 3;
    final didWorkout = _controller.workoutCompleted;
    final workType = _profileModel?.workType;
    final dailyProgress = (_userData.dailyGoal['progress'] as int? ?? 0).clamp(
      0,
      100,
    );
    final weeklyProgress = (_userData.weeklyGoal['progress'] as int? ?? 0)
        .clamp(0, 100);
    final weekday = DateTime.now().weekday;

    final out = <Map<String, dynamic>>[];

    final workoutSuggestion = _personalizedWorkoutSuggestion();
    if (workoutSuggestion != null) {
      out.add(workoutSuggestion);
    }

    if (!didWorkout && h < 12 && steps < 1200) {
      out.add({
        'badge': 'Ideal para esta mañana',
        'title': workType == WorkType.oficina || workType == WorkType.estudiante
            ? 'Activa el cuerpo antes de sentarte'
            : 'Despertar suave',
        'microcopy':
            workType == WorkType.oficina || workType == WorkType.estudiante
            ? 'Llevas pocos pasos y tu día apunta a sedentario. Un bloque corto ahora te cambia el resto del día.'
            : 'Tu cuerpo pide movimiento. Un bloque corto de movilidad puede hacer que el día empiece mucho mejor.',
        'button': 'Moverme ahora',
        'icon': Icons.self_improvement_outlined,
        'tab': 3,
      });
    }
    if (didWorkout && h >= 12 && h < 19) {
      out.add({
        'badge': 'Post-entreno',
        'title': 'Recuperación inteligente',
        'microcopy': _profileModel?.goal.trim().isNotEmpty == true
            ? 'Ya entrenaste. Prioriza una comida que acompañe tu objetivo de ${_profileModel!.goal.toLowerCase()}.'
            : '¡Gran esfuerzo! Recupera energía con una comida completa y buena hidratación.',
        'button': 'Ver receta',
        'icon': Icons.ramen_dining_outlined,
        'tab': 0,
      });
    }
    if (h >= 19 &&
        (stress >= 4 || sleep <= 2) &&
        !_userData.moodRegisteredToday) {
      out.add({
        'badge': 'Basado en tu estado',
        'title': 'Calma mental',
        'microcopy': sleep <= 2
            ? 'Dormiste poco y el cuerpo suele notarlo al final del día. Un cierre suave te ayudará más que apretar.'
            : 'Tu nivel de estrés está alto. Unos minutos de pausa ahora pueden mejorar mucho tu descanso.',
        'button': 'Meditar',
        'icon': Icons.nights_stay_outlined,
        'tab': 3,
      });
    }
    if (water < 1000) {
      final missing = (2000 - water).clamp(0, 2000);
      out.add({
        'badge': 'Basado en tu hidratación',
        'title': 'Hidratación rápida',
        'microcopy': missing > 0
            ? 'Vas por debajo de tu meta diaria. Si sumas ${missing >= 500 ? 'un buen vaso' : 'un pequeño vaso'} ahora, te será más fácil llegar hoy.'
            : 'Un vaso de agua ahora te ayuda a mantener el ritmo del día.',
        'button': 'Registrar agua',
        'icon': Icons.water_drop_outlined,
        'action': 'water',
      });
    }

    if (!didWorkout && weekday >= DateTime.thursday && weeklyProgress < 55) {
      out.add({
        'badge': 'Objetivo semanal',
        'title': 'Recupera tu semana',
        'microcopy':
            'Vas sobre el ${weeklyProgress.toString()}% de tu objetivo semanal. Un entreno corto hoy te deja mejor colocado para cerrarla bien.',
        'button': 'Ver opciones',
        'icon': Icons.flag_outlined,
        'action': 'workout',
        'workout': workoutSuggestion?['workout'],
      });
    }

    if (!_userData.moodRegisteredToday && dailyProgress < 50) {
      out.add({
        'badge': 'Chequeo personal',
        'title': 'Mini chequeo',
        'microcopy':
            'Registrar cómo te sientes ayuda a ajustar mejor tus decisiones del día y a entender tus patrones.',
        'button': 'Registrar estado',
        'icon': Icons.mood_outlined,
        'action': 'mood',
      });
    }

    if (steps < 6000) {
      out.add({
        'badge': 'Movimiento diario',
        'title': workType == WorkType.oficina || workType == WorkType.estudiante
            ? 'Rompe el sedentarismo'
            : 'Paseo digestivo',
        'microcopy':
            workType == WorkType.oficina || workType == WorkType.estudiante
            ? 'Llevas pocos pasos para el tipo de día que sueles tener. Una caminata corta te vendrá especialmente bien.'
            : 'Un paseo corto ahora te ayuda a sumar pasos sin que se sienta como otra tarea grande.',
        'button': 'Registrar pasos',
        'icon': Icons.directions_walk_outlined,
        'action': 'steps',
      });
    }

    return out;
  }

  Map<String, dynamic> _suggestionForNow() {
    final list = _suggestionsForNow();
    return list.isNotEmpty ? list.first : const <String, dynamic>{};
  }

  Map<String, dynamic> _suggestionForStorage() {
    final suggestion = _suggestionForNow();
    if (suggestion.isEmpty) return const <String, dynamic>{};

    final out = <String, dynamic>{};

    void copyString(String key) {
      final value = (suggestion[key] as String?)?.trim();
      if (value != null && value.isNotEmpty) {
        out[key] = value;
      }
    }

    copyString('badge');
    copyString('title');
    copyString('microcopy');
    copyString('button');
    copyString('action');

    final tab = suggestion['tab'];
    if (tab is int) {
      out['tab'] = tab;
    }

    final icon = suggestion['icon'];
    if (icon is IconData) {
      out['iconCodePoint'] = icon.codePoint;
      if (icon.fontFamily != null) {
        out['iconFontFamily'] = icon.fontFamily;
      }
      if (icon.fontPackage != null) {
        out['iconFontPackage'] = icon.fontPackage;
      }
    }

    return out;
  }

  Future<void> _executeSuggestion(Map<String, dynamic> suggestion) async {
    final action = (suggestion['action'] as String? ?? '').trim();
    if (action == 'workout') {
      final workout = suggestion['workout'];
      if (workout is Workout) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkoutDetailScreen(workout: workout),
          ),
        );
        return;
      }
    }
    if (action == 'water') {
      await _showWaterDialog();
      return;
    }
    if (action == 'steps') {
      await _showStepsDialog();
      return;
    }
    if (action == 'mood') {
      await _showMoodCheckModal();
      return;
    }
    final tab = suggestion['tab'] as int?;
    _goToTab(tab ?? 3, 'Sugerencia');
  }

  Future<void> _openGoalEditor({required bool weekly}) async {
    final current = weekly ? _userData.weeklyGoal : _userData.dailyGoal;
    String selectedType = (current['type'] as String? ?? 'Entrenamiento')
        .trim();
    final templatesSource = weekly ? _weeklyGoalTemplates : _dailyGoalTemplates;
    final initialOptions =
        templatesSource[selectedType] ?? const <Map<String, dynamic>>[];
    var selectedTemplate = initialOptions.isNotEmpty
        ? initialOptions.first
        : {
            'description':
                current['description'] ??
                (weekly ? 'Objetivo semanal' : 'Objetivo diario'),
            'target': current['target'] ?? 100,
          };

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(weekly ? 'Objetivo semanal' : 'Objetivo diario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  items: const [
                    DropdownMenuItem(
                      value: 'Entrenamiento',
                      child: Text('Entrenamiento'),
                    ),
                    DropdownMenuItem(
                      value: 'Nutrición',
                      child: Text('Nutrición'),
                    ),
                    DropdownMenuItem(
                      value: 'Hidratación',
                      child: Text('Hidratación'),
                    ),
                    DropdownMenuItem(
                      value: 'Meditación',
                      child: Text('Meditación'),
                    ),
                    DropdownMenuItem(value: 'Pasos', child: Text('Pasos')),
                    DropdownMenuItem(value: 'Hábitos', child: Text('Hábitos')),
                  ],
                  onChanged: (v) {
                    setLocal(() {
                      selectedType = v ?? 'Entrenamiento';
                      final options =
                          templatesSource[selectedType] ??
                          const <Map<String, dynamic>>[];
                      if (options.isNotEmpty) selectedTemplate = options.first;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Tipo de objetivo',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue:
                      ((templatesSource[selectedType] ??
                              const <Map<String, dynamic>>[])
                          .any(
                            (opt) =>
                                opt['description'] ==
                                selectedTemplate['description'],
                          ))
                      ? selectedTemplate['description'] as String?
                      : null,
                  items:
                      (templatesSource[selectedType] ??
                              const <Map<String, dynamic>>[])
                          .map(
                            (opt) => DropdownMenuItem<String>(
                              value: opt['description'] as String,
                              child: Text(opt['description'] as String),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    final options =
                        templatesSource[selectedType] ??
                        const <Map<String, dynamic>>[];
                    setLocal(() {
                      selectedTemplate = options.firstWhere(
                        (opt) => opt['description'] == v,
                        orElse: () => options.isNotEmpty
                            ? options.first
                            : selectedTemplate,
                      );
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Objetivo predefinido',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Objetivos predefinidos por tipo. Puedes cambiarlos cuando quieras.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final next = {
      ...current,
      'type': selectedType,
      'description': selectedTemplate['description'] as String,
      'target': (selectedTemplate['target'] as int? ?? 100),
    };

    setState(() {
      _userData = weekly
          ? _userData.copyWith(weeklyGoal: next)
          : _userData.copyWith(dailyGoal: next);
    });

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _dashboard.saveUserGoals(
        uid: uid,
        dailyGoal: weekly ? _userData.dailyGoal : next,
        weeklyGoal: weekly ? next : _userData.weeklyGoal,
      );
    }
  }

  Future<void> _showChallengeDetails() async {
    final c = _userData.weeklyChallenge;

    final title = (c['title'] as String? ?? 'Reto semanal').trim();
    final description = (c['description'] as String? ?? '').trim();
    final userProgress = _asInt(c['userProgress'], fallback: 0);
    final target = _asInt(c['target'], fallback: 1);
    final communityCompletionPct = _asInt(
      c['communityCompletionPct'],
      fallback: 0,
    ).clamp(0, 100);
    final rewardText = (c['reward'] as String? ?? '').trim();
    final completed =
        (c['completed'] == true) || (target > 0 && userProgress >= target);
    final progress = (userProgress / (target <= 0 ? 1 : target))
        .clamp(0.0, 1.0)
        .toDouble();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.isNotEmpty) Text(description),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(999)),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: CFColors.softGray,
                  valueColor: const AlwaysStoppedAnimation(CFColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              _challengeInfoRow(
                icon: Icons.show_chart_outlined,
                label: 'Tu progreso',
                value: '$userProgress/$target',
              ),
              const SizedBox(height: 6),
              _challengeInfoRow(
                icon: Icons.people_outline,
                label: 'Comunidad (completado)',
                value: '$communityCompletionPct%',
              ),
              const SizedBox(height: 6),
              _challengeInfoRow(
                icon: Icons.workspace_premium_outlined,
                label: 'Recompensa al completar (semana)',
                value: rewardText,
              ),
              if (completed) ...[
                const SizedBox(height: 10),
                Text(
                  '¡Reto completado! La recompensa se aplica para esta semana.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _challengeInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: CFColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Future<void> _claimWeeklyChallengeRewardIfEligible({
    required String uid,
    required WeeklyChallengeData challenge,
  }) async {
    if (!challenge.completed) return;
    final reward = challenge.rewardCfBonus;
    if (reward <= 0) return;

    final progressRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weeklyChallengeProgress')
        .doc(challenge.id);

    var claimed = false;
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(progressRef);
        if (!snap.exists) return;
        final data = snap.data() ?? const <String, dynamic>{};

        final docWeekId = (data['weekId'] as String? ?? '').trim();
        if (docWeekId != challenge.weekId) return;

        final already = (data['rewardClaimedWeekId'] as String? ?? '').trim();
        if (already == challenge.weekId) return;

        tx.set(progressRef, {
          'rewardClaimedWeekId': challenge.weekId,
          'rewardClaimedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        claimed = true;
      });
    } catch (_) {
      return;
    }

    if (!claimed) return;
    await _applyWeeklyChallengeRewardAcrossWeek(
      uid: uid,
      weekId: challenge.weekId,
      reward: reward,
    );
  }

  Future<void> _applyWeeklyChallengeRewardAcrossWeek({
    required String uid,
    required String weekId,
    required int reward,
  }) async {
    final start =
        DateUtilsCF.fromKey(weekId) ?? DateUtilsCF.dateOnly(DateTime.now());
    final end = start.add(const Duration(days: 6));
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final last = today.isBefore(end) ? today : end;
    if (last.isBefore(start)) return;

    final totalDays = last.difference(start).inDays + 1;
    final daysCount = totalDays <= 0 ? 1 : totalDays;
    final baseAdd = reward ~/ daysCount;
    final remainder = reward % daysCount;

    final keys = List<String>.generate(
      daysCount,
      (i) => DateUtilsCF.toKey(start.add(Duration(days: i))),
    );

    final history = await _storage.getCfHistory();
    final todayKey = DateUtilsCF.toKey(DateTime.now());
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    int? newTodayCf;

    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final add = baseAdd + (i < remainder ? 1 : 0);
      if (add <= 0) continue;

      final local = (history[key] ?? 0).clamp(0, 100);
      var base = local;

      if (key == todayKey) {
        final fallback = _controller.displayedCfIndex.clamp(0, 100);
        if (fallback > base) base = fallback;
        try {
          final snap = await userRef.collection('dailyStats').doc(key).get();
          final remote = _asInt(
            snap.data()?['cfIndex'],
            fallback: 0,
          ).clamp(0, 100);
          if (remote > base) base = remote;
        } catch (_) {
          // Ignore read failures; use local/controller base.
        }
      } else {
        try {
          final snap = await userRef.collection('dailyStats').doc(key).get();
          final remote = _asInt(
            snap.data()?['cfIndex'],
            fallback: 0,
          ).clamp(0, 100);
          if (remote > base) base = remote;
        } catch (_) {
          // Ignore read failures; use local base.
        }
      }

      final next = (base + add).clamp(0, 100);

      await _storage.upsertCfForDate(dateKey: key, cf: next);
      await userRef.collection('dailyStats').doc(key).set({
        'dateKey': key,
        'cfIndex': next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (key == todayKey) {
        newTodayCf = next;
      }
    }

    if (!mounted) return;
    if (newTodayCf != null) {
      setState(() {
        _userData = _userData.copyWith(currentCFIndex: newTodayCf);
      });
    }
  }

  int _difficultyPoints(String difficulty) =>
      _difficultyToPoints[difficulty] ?? 5;

  Future<void> _openHabitEditor({Map<String, dynamic>? existing}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final nameCtrl = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final selectedDays = <int>{1, 2, 3, 4, 5, 6, 7};
    final rawRepeatDays = existing?['repeatDays'];
    if (rawRepeatDays is List) {
      final parsed = rawRepeatDays
          .map((e) {
            if (e is int) return e;
            if (e is num) return e.round();
            return int.tryParse(e.toString());
          })
          .whereType<int>()
          .where((d) => d >= 1 && d <= 7)
          .toSet();
      if (parsed.isNotEmpty) {
        selectedDays
          ..clear()
          ..addAll(parsed);
      }
    }
    String difficulty = existing?['difficulty'] as String? ?? 'Media';

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Añadir hábito' : 'Editar hábito'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del hábito',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: difficulty,
                  items: _difficultyToPoints.keys
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text('$k (+${_difficultyToPoints[k]} CF)'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => difficulty = v ?? 'Media'),
                  decoration: const InputDecoration(labelText: 'Dificultad'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: List.generate(7, (i) {
                    final d = i + 1;
                    final labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                    final selected = selectedDays.contains(d);
                    return FilterChip(
                      selected: selected,
                      label: Text(labels[i]),
                      onSelected: (_) {
                        setLocal(() {
                          if (selected) {
                            selectedDays.remove(d);
                          } else {
                            selectedDays.add(d);
                          }
                        });
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            if (existing != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () {
                  final id = existing['id'] as String?;
                  if (id == null) return;
                  Navigator.of(context).pop(false);
                  unawaited(_deleteHabit(id));
                },
                child: const Text('Borrar hábito'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final points = _difficultyPoints(difficulty);
    final repeatDays = selectedDays.toList()..sort();
    final weekday = DateTime.now().weekday;
    final shouldShowToday = repeatDays.isEmpty || repeatDays.contains(weekday);

    if (existing == null) {
      final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      if (shouldShowToday) {
        setState(() {
          _userData = _userData.copyWith(
            habits: [
              {
                'id': tempId,
                'name': name,
                'repeatDays': repeatDays,
                'difficulty': difficulty,
                'cfPoints': points,
                'isCompleted': false,
              },
              ..._userData.habits,
            ],
          );
        });
      }

      unawaited(() async {
        try {
          final createdId = await _dashboard.createHabit(
            uid: uid,
            name: name,
            repeatDays: repeatDays,
            cfReward: points,
          );
          if (!mounted) return;
          if (!shouldShowToday) return;
          setState(() {
            _userData = _userData.copyWith(
              habits: _userData.habits
                  .map((h) => (h['id'] == tempId) ? {...h, 'id': createdId} : h)
                  .toList(growable: false),
            );
          });
        } catch (_) {
          if (!mounted) return;
          if (!shouldShowToday) return;
          setState(() {
            _userData = _userData.copyWith(
              habits: _userData.habits
                  .where((h) => h['id'] != tempId)
                  .toList(growable: false),
            );
          });
        }
      }());
    } else {
      final habitId = existing['id'] as String;
      final previousHabits = _userData.habits;
      final updated = {
        ...existing,
        'name': name,
        'repeatDays': repeatDays,
        'difficulty': difficulty,
        'cfPoints': points,
      };

      final nextHabits = shouldShowToday
          ? previousHabits
                .map((h) => (h['id'] == habitId) ? updated : h)
                .toList(growable: false)
          : previousHabits
                .where((h) => h['id'] != habitId)
                .toList(growable: false);

      setState(() {
        _userData = _userData.copyWith(habits: nextHabits);
      });

      unawaited(() async {
        try {
          await _dashboard.updateHabit(
            uid: uid,
            habitId: habitId,
            name: name,
            repeatDays: repeatDays,
            cfReward: points,
          );
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _userData = _userData.copyWith(habits: previousHabits);
          });
        }
      }());
    }
  }

  Future<void> _openTaskEditor({Map<String, dynamic>? existing}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final titleCtrl = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    String difficulty = existing?['difficulty'] as String? ?? 'Media';
    DateTime? dueDate;
    final rawDueDate = existing?['dueDateValue'];
    if (rawDueDate is DateTime) {
      dueDate = rawDueDate;
    }
    final now = DateTime.now();

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Añadir tarea' : 'Editar tarea'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la tarea',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: difficulty,
                  items: _difficultyToPoints.keys
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text('$k (+${_difficultyToPoints[k]} CF)'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => difficulty = v ?? 'Media'),
                  decoration: const InputDecoration(labelText: 'Dificultad'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    dueDate == null
                        ? 'Sin fecha ni hora'
                        : 'Fecha: ${_dueDateEditorLabel(dueDate!)}',
                  ),
                  subtitle: const Text(
                    'CotidyFit te avisará a la hora que elijas.',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dueDate != null)
                        IconButton(
                          onPressed: () => setLocal(() => dueDate = null),
                          icon: const Icon(Icons.close),
                          tooltip: 'Quitar fecha',
                        ),
                      const Icon(Icons.schedule_outlined),
                    ],
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      locale: const Locale('es'),
                      initialDate: dueDate ?? now,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked == null || !context.mounted) return;

                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                        dueDate ?? now.add(const Duration(hours: 1)),
                      ),
                      builder: (context, child) {
                        if (child == null) return const SizedBox.shrink();
                        return Localizations.override(
                          context: context,
                          locale: const Locale('es'),
                          child: MediaQuery(
                            data: MediaQuery.of(
                              context,
                            ).copyWith(alwaysUse24HourFormat: true),
                            child: child,
                          ),
                        );
                      },
                    );
                    if (pickedTime == null) return;

                    setLocal(() {
                      dueDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            if (existing != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () {
                  final id = existing['id'] as String?;
                  if (id == null) return;
                  Navigator.of(context).pop(false);
                  unawaited(_deleteTask(id));
                },
                child: const Text('Borrar'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final points = _difficultyPoints(difficulty);

    if (existing == null) {
      final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _userData = _userData.copyWith(
          todos: [
            {
              'id': tempId,
              'name': title,
              'dueDate': _dueDateLabel(dueDate),
              'dueDateValue': dueDate,
              'difficulty': difficulty,
              'cfPoints': points,
              'isCompleted': false,
              'notificationEnabled': dueDate != null,
            },
            ..._userData.todos,
          ],
        );
      });

      unawaited(() async {
        try {
          final createdId = await _dashboard.createTask(
            uid: uid,
            title: title,
            dueDate: dueDate,
            cfReward: points,
            notificationEnabled: dueDate != null,
          );
          if (!mounted) return;
          setState(() {
            _userData = _userData.copyWith(
              todos: _userData.todos
                  .map((t) => (t['id'] == tempId) ? {...t, 'id': createdId} : t)
                  .toList(growable: false),
            );
          });
          await TaskReminderService.instance.syncTaskReminder(
            taskId: createdId,
            title: title,
            dueDate: dueDate,
            enabled: dueDate != null,
            completed: false,
          );
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _userData = _userData.copyWith(
              todos: _userData.todos
                  .where((t) => t['id'] != tempId)
                  .toList(growable: false),
            );
          });
        }
      }());
    } else {
      final taskId = existing['id'] as String;
      final previousTodos = _userData.todos;
      final updated = {
        ...existing,
        'name': title,
        'dueDate': _dueDateLabel(dueDate),
        'dueDateValue': dueDate,
        'difficulty': difficulty,
        'cfPoints': points,
        'notificationEnabled': dueDate != null,
      };

      setState(() {
        _userData = _userData.copyWith(
          todos: previousTodos
              .map((t) => (t['id'] == taskId) ? updated : t)
              .toList(growable: false),
        );
      });

      unawaited(() async {
        try {
          await _dashboard.updateTask(
            uid: uid,
            taskId: taskId,
            title: title,
            dueDate: dueDate,
            cfReward: points,
            notificationEnabled: dueDate != null,
          );
          await TaskReminderService.instance.syncTaskReminder(
            taskId: taskId,
            title: title,
            dueDate: dueDate,
            enabled: dueDate != null,
            completed: existing['isCompleted'] == true,
          );
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _userData = _userData.copyWith(todos: previousTodos);
          });
        }
      }());
    }
  }

  Future<void> _toggleHabit(Map<String, dynamic> item, bool checked) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final id = item['id'] as String;
    final previous = _userData.habits;
    final nextHabits = previous
        .map((h) => h['id'] == id ? {...h, 'isCompleted': checked} : h)
        .toList(growable: false);

    setState(() {
      _userData = _userData.copyWith(habits: nextHabits);
    });

    await _dashboard.setHabitCompletedToday(
      uid: uid,
      dateKey: _controller.todayKey,
      habitId: id,
      completed: checked,
    );

    if (checked) {
      final points = (item['cfPoints'] as int? ?? 0);
      await _applyCfBonus(points);
    }
  }

  Future<void> _toggleTask(Map<String, dynamic> item, bool checked) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final id = item['id'] as String;
    final previous = _userData.todos;
    final nextTasks = previous
        .map((t) => t['id'] == id ? {...t, 'isCompleted': checked} : t)
        .toList(growable: false);

    setState(() {
      _userData = _userData.copyWith(todos: nextTasks);
    });

    await _dashboard.setTaskCompleted(uid: uid, taskId: id, completed: checked);
    final rawDueDate = item['dueDateValue'];
    final dueDate = rawDueDate is DateTime
        ? rawDueDate
        : DateTime.tryParse(rawDueDate?.toString() ?? '');
    await TaskReminderService.instance.syncTaskReminder(
      taskId: id,
      title: (item['name'] as String? ?? 'Tarea pendiente').trim(),
      dueDate: dueDate,
      enabled: item['notificationEnabled'] == true,
      completed: checked,
    );
    if (checked) {
      final points = (item['cfPoints'] as int? ?? 0);
      await _applyCfBonus(points);
    }
  }

  Future<void> _deleteHabit(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _dashboard.deleteHabit(uid: uid, habitId: id);
    if (!mounted) return;
    setState(() {
      _userData = _userData.copyWith(
        habits: _userData.habits
            .where((h) => h['id'] != id)
            .toList(growable: false),
      );
    });
  }

  Future<void> _deleteTask(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _dashboard.deleteTask(uid: uid, taskId: id);
    await TaskReminderService.instance.cancelTaskReminder(id);
    if (!mounted) return;
    setState(() {
      _userData = _userData.copyWith(
        todos: _userData.todos
            .where((t) => t['id'] != id)
            .toList(growable: false),
      );
    });
  }

  Future<void> _applyCfBonus(int points) async {
    final dateKey = DateUtilsCF.toKey(DateTime.now());
    final history = await _storage.getCfHistory();
    final current = (history[dateKey] ?? _controller.displayedCfIndex).clamp(
      0,
      100,
    );
    final next = (current + points).clamp(0, 100);
    await _storage.upsertCfForDate(dateKey: dateKey, cf: next);
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _dashboard.saveDailyStatsSnapshot(
        uid: uid,
        dateKey: dateKey,
        cfIndex: next,
        steps: _userData.stepsCount['current'] ?? 0,
        waterMl: _userData.waterIntake['current'] ?? 0,
      );
    }
  }

  Future<void> _showAllHabitsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Todos tus hábitos'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              children: _userData.habits.map((h) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Icon(
                          h['isCompleted'] == true
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _openHabitEditor(existing: h);
                            if (!context.mounted) return;
                            _showAllHabitsDialog();
                          },
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h['name'] as String? ?? ''),
                                const SizedBox(height: 2),
                                Text(
                                  '${_repeatDaysLabel(h['repeatDays'])} · +${h['cfPoints']} CF',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAllTasksDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Todas tus tareas'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              children: _userData.todos.map((t) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Icon(
                          t['isCompleted'] == true
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _openTaskEditor(existing: t);
                            if (!context.mounted) return;
                            _showAllTasksDialog();
                          },
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['name'] as String? ?? ''),
                                const SizedBox(height: 2),
                                Text(
                                  '${t['dueDate']} · +${t['cfPoints']} CF',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _block({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cfSurface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: context.cfBorder),
        boxShadow: [
          BoxShadow(
            color: context.cfShadow,
            blurRadius: context.cfIsDark ? 24 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _placeholderLine({double widthFactor = 1, double height = 12}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.cfPrimaryTint,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
        ),
      ),
    );
  }

  Widget _loadingListPlaceholder({int items = 3}) {
    return Column(
      children: List<Widget>.generate(items, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == items - 1 ? 0 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: CFColors.primary.withValues(alpha: 0.09),
                  borderRadius: const BorderRadius.all(Radius.circular(7)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _placeholderLine(widthFactor: 0.76),
                    const SizedBox(height: 8),
                    _placeholderLine(widthFactor: 0.42, height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _checklistRow({
    required bool checked,
    required ValueChanged<bool> onChecked,
    required VoidCallback onTap,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Checkbox(
            value: checked,
            onChanged: (v) => onChecked(v ?? false),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final greeting = _greetingFor();
    final cfProgress = (_userData.currentCFIndex / 100).clamp(0.0, 1.0);
    final suggestions = _suggestionsForNow();
    final habitsPreview = _userData.habits
        .where((h) => h['isCompleted'] != true)
        .take(4)
        .toList();
    final tasksPreview = _userData.todos
        .where((t) => t['isCompleted'] != true)
        .take(4)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: _loading && !_hasVisibleContent
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _loadRealData(withLoader: false),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    if (_statusMessage != null) ...[
                      InlineStatusBanner(message: _statusMessage!),
                      const SizedBox(height: 10),
                    ],
                    _block(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting.greeting,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _streakLine(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _coachMicroMessage(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: _showMoodCheckModal,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(12),
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _userData.moodRegisteredToday
                                    ? context.cfPrimaryTint
                                    : context.cfPrimaryTintStrong,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(12),
                                ),
                                border: Border.all(
                                  color: _userData.moodRegisteredToday
                                      ? context.cfPrimaryTintStrong
                                      : context.cfPrimary,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _userData.moodRegisteredToday
                                          ? 'Estado de ánimo de hoy: ${_userData.currentMoodIcon}'
                                          : '¿Cómo te sientes hoy?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: context.cfTextPrimary,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: context.cfTextSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _weatherBlock(),
                    const SizedBox(height: 10),
                    _block(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recomendación del momento',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          AnimatedSlide(
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeOutCubic,
                            offset: _suggestionVisible
                                ? Offset.zero
                                : const Offset(0, 0.12),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 420),
                              opacity: _suggestionVisible ? 1 : 0,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: () {
                                      final screenWidth = MediaQuery.sizeOf(
                                        context,
                                      ).width;
                                      final textScale = MediaQuery.textScalerOf(
                                        context,
                                      ).scale(1);
                                      final compact = screenWidth < 392;
                                      final baseHeight = compact ? 224.0 : 208.0;
                                      final extraHeight =
                                          ((textScale - 1) * 56).clamp(0.0, 36.0);
                                      return baseHeight + extraHeight;
                                    }(),
                                    child: PageView.builder(
                                      controller: _suggestionPageController,
                                      itemCount: suggestions.length,
                                      onPageChanged: (index) => setState(
                                        () => _suggestionIndex = index,
                                      ),
                                      itemBuilder: (context, index) {
                                        final suggestion = suggestions[index];
                                        final compact =
                                            MediaQuery.sizeOf(context).width <
                                            392;
                                        final textScale = MediaQuery
                                            .textScalerOf(context)
                                            .scale(1);
                                        final microcopyMaxLines = compact
                                            ? (textScale > 1.08 ? 2 : 3)
                                            : (textScale > 1.08 ? 3 : 4);
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  const BorderRadius.all(
                                                    Radius.circular(22),
                                                  ),
                                              onTap: () => _executeSuggestion(
                                                suggestion,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.all(
                                                      Radius.circular(22),
                                                    ),
                                                child: BackdropFilter(
                                                  filter: ImageFilter.blur(
                                                    sigmaX: 7,
                                                    sigmaY: 7,
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          14,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          context.cfSoftSurface,
                                                      borderRadius:
                                                          const BorderRadius.all(
                                                            Radius.circular(22),
                                                          ),
                                                      border: Border.all(
                                                        color: context.cfBorder,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Container(
                                                          width: compact
                                                              ? 48
                                                              : 52,
                                                          height: compact
                                                              ? 48
                                                              : 52,
                                                          decoration: BoxDecoration(
                                                            color: context
                                                                .cfPrimaryTint,
                                                            borderRadius:
                                                                const BorderRadius.all(
                                                                  Radius.circular(
                                                                    16,
                                                                  ),
                                                                ),
                                                            border: Border.all(
                                                              color: context
                                                                  .cfPrimaryTintStrong,
                                                            ),
                                                          ),
                                                          child: Icon(
                                                            suggestion['icon']
                                                                    as IconData? ??
                                                                Icons
                                                                    .auto_awesome_outlined,
                                                            color: context
                                                                .cfPrimary,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: compact
                                                              ? 10
                                                              : 12,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize.max,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: context
                                                                      .cfPrimaryTint,
                                                                  borderRadius:
                                                                      const BorderRadius.all(
                                                                        Radius.circular(
                                                                          999,
                                                                        ),
                                                                      ),
                                                                  border: Border.all(
                                                                    color: context
                                                                        .cfPrimaryTintStrong,
                                                                  ),
                                                                ),
                                                                child: Text(
                                                                  suggestion['badge']
                                                                          as String? ??
                                                                      'Ideal para ahora',
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: Theme.of(context)
                                                                      .textTheme
                                                                      .bodySmall
                                                                      ?.copyWith(
                                                                        color: context
                                                                            .cfPrimary,
                                                                        fontWeight:
                                                                            FontWeight.w800,
                                                                      ),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                height: compact
                                                                    ? 6
                                                                    : 8,
                                                              ),
                                                              Flexible(
                                                                fit: FlexFit.loose,
                                                                child: Text(
                                                                  suggestion['title']
                                                                          as String? ??
                                                                      'Sugerencia',
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: Theme.of(context)
                                                                      .textTheme
                                                                      .titleMedium
                                                                      ?.copyWith(
                                                                        color: context
                                                                            .cfTextPrimary,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w800,
                                                                      ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              Expanded(
                                                                child: Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .topLeft,
                                                                  child: Text(
                                                                    suggestion['microcopy']
                                                                            as String? ??
                                                                        '',
                                                                    maxLines:
                                                                        microcopyMaxLines,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: Theme.of(context)
                                                                        .textTheme
                                                                        .bodyMedium
                                                                        ?.copyWith(
                                                                          color: context
                                                                              .cfTextSecondary,
                                                                          height:
                                                                              1.35,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: _suggestionIndex <= 0
                                            ? null
                                            : () {
                                                _suggestionPageController
                                                    .previousPage(
                                                      duration: const Duration(
                                                        milliseconds: 220,
                                                      ),
                                                      curve: Curves.easeOut,
                                                    );
                                              },
                                        icon: const Icon(Icons.chevron_left),
                                      ),
                                      ...List.generate(
                                        suggestions.length,
                                        (i) => Container(
                                          margin: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          width: i == _suggestionIndex ? 16 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: i == _suggestionIndex
                                                ? context.cfPrimary
                                                : context.cfPrimaryTintStrong,
                                            borderRadius:
                                                const BorderRadius.all(
                                                  Radius.circular(99),
                                                ),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed:
                                            _suggestionIndex >=
                                                suggestions.length - 1
                                            ? null
                                            : () {
                                                _suggestionPageController
                                                    .nextPage(
                                                      duration: const Duration(
                                                        milliseconds: 220,
                                                      ),
                                                      curve: Curves.easeOut,
                                                    );
                                              },
                                        icon: const Icon(Icons.chevron_right),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _block(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estado de tu semana',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _showMonthCalendarDialog,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (i) {
                                final date =
                                    DateUtilsCF.dateOnly(DateTime.now())
                                        .subtract(
                                          Duration(
                                            days: DateTime.now().weekday - 1,
                                          ),
                                        )
                                        .add(Duration(days: i));
                                final isToday = DateUtilsCF.isSameDay(
                                  date,
                                  DateTime.now(),
                                );
                                final key = DateUtilsCF.toKey(date);
                                HomeDayStat? dayStat;
                                for (final d in _weekDays) {
                                  if (d.dateKey == key) {
                                    dayStat = d;
                                    break;
                                  }
                                }
                                final cf = (dayStat?.cfScore ?? 0).clamp(
                                  0,
                                  100,
                                );
                                final t = cf / 100.0;
                                final base =
                                    Color.lerp(
                                      CFColors.softGray,
                                      CFColors.primary,
                                      t,
                                    ) ??
                                    CFColors.softGray;
                                const labels = [
                                  'L',
                                  'M',
                                  'X',
                                  'J',
                                  'V',
                                  'S',
                                  'D',
                                ];
                                return Column(
                                  children: [
                                    Text(labels[i]),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? CFColors.primary
                                            : base.withValues(alpha: 0.85),
                                        border: isToday
                                            ? Border.all(
                                                color: CFColors.textPrimary,
                                                width: 1.2,
                                              )
                                            : null,
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        '${date.day}',
                                        style: TextStyle(
                                          color: isToday
                                              ? Colors.white
                                              : CFColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _showCfAndStreakDialog,
                                  child: SizedBox(
                                    height: 116,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: CFColors.primary.withValues(
                                          alpha: 0.06,
                                        ),
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(12),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(_streakCardLabel()),
                                          Text('${_userData.dailyStreak} días'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: _showCfAndStreakDialog,
                                  child: SizedBox(
                                    height: 116,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: CFColors.primary.withValues(
                                          alpha: 0.06,
                                        ),
                                        borderRadius: const BorderRadius.all(
                                          Radius.circular(12),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text('Puntaje CF'),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius:
                                                const BorderRadius.all(
                                                  Radius.circular(999),
                                                ),
                                            child: LinearProgressIndicator(
                                              value: cfProgress,
                                              minHeight: 8,
                                              backgroundColor:
                                                  CFColors.softGray,
                                              valueColor:
                                                  const AlwaysStoppedAnimation(
                                                    CFColors.primary,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${_userData.currentCFIndex} · ${_heroCfLabel()}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _showWaterDialog,
                            child: _block(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.water_drop_outlined,
                                    color: CFColors.primary,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text('Agua'),
                                  Text(
                                    '${_userData.waterIntake['current']}/${_userData.waterIntake['target']} ml',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _showStepsDialog,
                            child: _block(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.directions_walk_outlined,
                                    color: CFColors.primary,
                                  ),
                                  const SizedBox(height: 6),
                                  const Text('Pasos'),
                                  Text(
                                    '${_userData.stepsCount['current']}/${_userData.stepsCount['target']}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_profileModel != null &&
                        _profileModel!.sex == UserSex.mujer) ...[
                      HomeWomenCycleSection(profile: _profileModel!),
                      const SizedBox(height: 10),
                    ],
                    _block(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metas y objetivos',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => _openGoalEditor(weekly: false),
                            child: _goalCard(
                              title: 'Objetivo diario',
                              description:
                                  '${_userData.dailyGoal['type']} · ${_userData.dailyGoal['description']}',
                              progress:
                                  (_userData.dailyGoal['progress'] as int? ??
                                  0),
                              target:
                                  (_userData.dailyGoal['target'] as int? ??
                                  100),
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _openGoalEditor(weekly: true),
                            child: _goalCard(
                              title: 'Objetivo semanal',
                              description:
                                  '${_userData.weeklyGoal['type']} · ${_userData.weeklyGoal['description']}',
                              progress:
                                  (_userData.weeklyGoal['progress'] as int? ??
                                  0),
                              target:
                                  (_userData.weeklyGoal['target'] as int? ??
                                  100),
                              extra:
                                  'Racha semanal: ${_userData.weeklyStreak} · Hábitos: $_weeklyHabitsCompleted en $_weeklyHabitActiveDays días',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _block(
                      child: InkWell(
                        onTap: _showChallengeDetails,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reto semanal',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (_loadingCollections &&
                                _userData.weeklyChallenge['isActive'] !=
                                    true) ...[
                              const SizedBox(height: 10),
                              _placeholderLine(widthFactor: 0.54),
                              const SizedBox(height: 8),
                              _placeholderLine(widthFactor: 0.82),
                              const SizedBox(height: 8),
                              _placeholderLine(widthFactor: 0.68),
                            ] else ...[
                              const SizedBox(height: 6),
                              Text(
                                _userData.weeklyChallenge['title'] as String,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userData.weeklyChallenge['description']
                                    as String,
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(999),
                                ),
                                child: LinearProgressIndicator(
                                  value:
                                      ((_userData.weeklyChallenge['userProgress']
                                                  as int) /
                                              ((_userData.weeklyChallenge['target']
                                                          as int) <=
                                                      0
                                                  ? 1
                                                  : (_userData
                                                            .weeklyChallenge['target']
                                                        as int)))
                                          .clamp(0.0, 1.0),
                                  minHeight: 8,
                                  backgroundColor: CFColors.softGray,
                                  valueColor: const AlwaysStoppedAnimation(
                                    CFColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Recompensa (semana): ${_userData.weeklyChallenge['reward']}',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _block(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Hábitos',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              TextButton(
                                onPressed: _showAllHabitsDialog,
                                child: const Text('Ver todos'),
                              ),
                              IconButton(
                                onPressed: () => _openHabitEditor(),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                          if (_loadingCollections && habitsPreview.isEmpty)
                            _loadingListPlaceholder()
                          else if (habitsPreview.isEmpty)
                            const Text('No tienes hábitos pendientes.')
                          else
                            ...habitsPreview.map((h) {
                              return _checklistRow(
                                checked: h['isCompleted'] == true,
                                onChecked: (v) => _toggleHabit(h, v),
                                onTap: () => _openHabitEditor(existing: h),
                                title: (h['name'] as String? ?? '').trim(),
                                subtitle:
                                    '${_repeatDaysLabel(h['repeatDays'])} · +${h['cfPoints']} CF',
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _block(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Lista de cosas que hacer',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              TextButton(
                                onPressed: _showAllTasksDialog,
                                child: const Text('Ver todas'),
                              ),
                              IconButton(
                                onPressed: () => _openTaskEditor(),
                                icon: const Icon(Icons.post_add_outlined),
                              ),
                            ],
                          ),
                          if (_loadingCollections && tasksPreview.isEmpty)
                            _loadingListPlaceholder()
                          else if (tasksPreview.isEmpty)
                            const Text('No tienes tareas pendientes.')
                          else
                            ...tasksPreview.map((t) {
                              return _checklistRow(
                                checked: t['isCompleted'] == true,
                                onChecked: (v) => _toggleTask(t, v),
                                onTap: () => _openTaskEditor(existing: t),
                                title: (t['name'] as String? ?? '').trim(),
                                subtitle:
                                    '${t['dueDate']} · +${t['cfPoints']} CF',
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _goalCard({
    required String title,
    required String description,
    required int progress,
    required int target,
    String? extra,
  }) {
    final ratio = (progress / (target <= 0 ? 1 : target)).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(description),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: CFColors.softGray,
              valueColor: const AlwaysStoppedAnimation(CFColors.primary),
            ),
          ),
          const SizedBox(height: 4),
          Text('$progress / $target (${(ratio * 100).round()}%)'),
          if (extra != null) Text(extra),
        ],
      ),
    );
  }
}

class _StepsHistoryChart extends StatelessWidget {
  const _StepsHistoryChart({required this.values});

  final List<int> values;

  static const _weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i].clamp(0, 200000).toDouble();
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: v,
              width: values.length > 20 ? 6 : 10,
              color: CFColors.primary,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final maxY = _stepChartMaxY(maxValue);
    final last = values.length - 1;
    final mid = values.length ~/ 2;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        barGroups: bars,
        gridData: FlGridData(
          show: true,
          horizontalInterval: maxY <= 4000 ? 1000 : maxY / 4,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: CFColors.softGray, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: maxY <= 4000 ? 1000 : maxY / 4,
              getTitlesWidget: (value, meta) => Text(
                _formatAxisSteps(value),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final x = value.toInt();
                if (x < 0 || x >= values.length) {
                  return const SizedBox.shrink();
                }

                String label = '';
                if (values.length <= 7) {
                  label = _weekdayLabelForIndex(x, values.length);
                } else {
                  if (x == 0) label = _weekdayLabelForIndex(x, values.length);
                  if (x == mid) {
                    label = _weekdayLabelForIndex(x, values.length);
                  }
                  if (x == last) label = 'Hoy';
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => CFColors.textPrimary,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final x = group.x;
              final dayLabel = _fullDayLabelForIndex(x, values.length);
              return BarTooltipItem(
                '$dayLabel\n${_formatStepCount(rod.toY.round())} pasos',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
    );
  }

  static double _stepChartMaxY(int maxValue) {
    if (maxValue <= 0) return 4000;
    if (maxValue <= 4000) return 4000;
    final padded = (maxValue * 1.15).ceil();
    final step = padded <= 10000 ? 1000 : 2000;
    return ((padded + step - 1) ~/ step * step).toDouble();
  }

  static String _formatAxisSteps(double value) {
    return _formatStepCount(value.round());
  }

  static String _formatStepCount(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }

  static String _weekdayLabelForIndex(int index, int total) {
    final date = _dateForIndex(index, total);
    return _weekdays[date.weekday - 1];
  }

  static String _fullDayLabelForIndex(int index, int total) {
    final date = _dateForIndex(index, total);
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final dayText = DateUtilsCF.isSameDay(date, today)
        ? 'Hoy'
        : '${_weekdays[date.weekday - 1]} ${date.day}/${date.month}';
    return dayText;
  }

  static DateTime _dateForIndex(int index, int total) {
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final daysAgo = (total - 1 - index).clamp(0, total - 1);
    return today.subtract(Duration(days: daysAgo));
  }
}

class _CfHistoryChart extends StatelessWidget {
  const _CfHistoryChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final bars = <BarChartGroupData>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i].clamp(0, 100).toDouble();
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: v,
              width: values.length > 20 ? 6 : 8,
              color: CFColors.primary,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    final last = values.length - 1;
    final mid = values.length ~/ 2;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        barGroups: bars,
        gridData: FlGridData(
          show: true,
          horizontalInterval: 25,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: CFColors.softGray, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 25,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final x = value.toInt();
                String label = '';
                if (x == 0) label = 'L-$last';
                if (x == mid) label = 'L-${last - mid}';
                if (x == last) label = 'Hoy';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => CFColors.textPrimary,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final daysAgo = last - group.x;
              final label = daysAgo == 0 ? 'Hoy' : 'Hace $daysAgo d';
              return BarTooltipItem(
                '$label\nCF: ${rod.toY.round()}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
      ),
      swapAnimationDuration: const Duration(milliseconds: 300),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Pantalla: $title')),
    );
  }
}
