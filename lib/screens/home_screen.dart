import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/daily_data_controller.dart';
import '../core/home_navigation.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/home_dashboard_service.dart';
import '../services/local_storage_service.dart';
import '../services/profile_service.dart';
import '../utils/date_utils.dart';

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
  dailyGoal: {'type': 'Entrenamiento', 'description': 'Completar misión diaria', 'progress': 0, 'target': 100},
  weeklyGoal: {'type': 'Hábitos', 'description': 'Cumplir objetivos semanales', 'progress': 0, 'target': 100},
  weeklyChallenge: {
    'title': 'Sin reto activo',
    'description': 'No hay reto activo. ¡Pronto uno nuevo!',
    'userProgress': 0,
    'target': 1,
    'communityProgress': 0,
    'reward': '+0 CF',
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

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  final _profile = ProfileService();
  final _dashboard = HomeDashboardService();
  final _controller = DailyDataController();
  final _storage = LocalStorageService();

  UserData _userData = initialUserData;
  bool _loading = true;
  bool _suggestionVisible = false;
  List<HomeDayStat> _weekDays = const [];
  late final PageController _suggestionPageController;
  int _suggestionIndex = 0;
  String _cityLabel = 'Ubicación no disponible';
  String _tempLabel = '--°C';
  String _weatherEmoji = '🌙';
  DateTime _clockNow = DateTime.now();
  Timer? _clockTimer;
  Timer? _environmentTimer;

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
    ],
    'Nutrición': [
      {'description': 'Comer 3 comidas equilibradas', 'target': 3},
      {'description': 'Añadir 2 raciones de verdura', 'target': 2},
      {'description': 'Evitar ultraprocesados hoy', 'target': 1},
    ],
    'Hidratación': [
      {'description': 'Beber 2L de agua', 'target': 2000},
      {'description': 'Tomar 6 vasos de agua', 'target': 6},
    ],
    'Meditación': [
      {'description': 'Meditar 10 minutos', 'target': 10},
      {'description': 'Respiración guiada 5 min', 'target': 5},
    ],
    'Pasos': [
      {'description': 'Caminar 8000 pasos', 'target': 8000},
      {'description': 'Caminar 10000 pasos', 'target': 10000},
    ],
    'Hábitos': [
      {'description': 'Completar 3 hábitos del día', 'target': 3},
      {'description': 'Cumplir rutina matinal', 'target': 1},
    ],
  };

  static const _weeklyGoalTemplates = <String, List<Map<String, dynamic>>>{
    'Entrenamiento': [
      {'description': 'Entrenar 3 veces esta semana', 'target': 3},
      {'description': 'Acumular 120 min de actividad', 'target': 120},
    ],
    'Nutrición': [
      {'description': 'Comer sano 5 días', 'target': 5},
      {'description': 'Registrar comidas 7 días', 'target': 7},
    ],
    'Hidratación': [
      {'description': 'Cumplir hidratación 6 días', 'target': 6},
      {'description': 'Llegar a 14L en la semana', 'target': 14000},
    ],
    'Meditación': [
      {'description': 'Meditar 4 días', 'target': 4},
      {'description': 'Acumular 60 min', 'target': 60},
    ],
    'Pasos': [
      {'description': 'Caminar 50000 pasos', 'target': 50000},
      {'description': 'Superar 8000 pasos en 5 días', 'target': 5},
    ],
    'Hábitos': [
      {'description': 'Completar 12 hábitos semanales', 'target': 12},
      {'description': 'No romper cadena 7 días', 'target': 7},
    ],
  };

  @override
  void initState() {
    super.initState();
    _suggestionPageController = PageController(viewportFraction: 0.93);
    _startClockTicker();
    _startEnvironmentTicker();
    _loadRealData();
    _refreshEnvironmentInfo();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _environmentTimer?.cancel();
    _suggestionPageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRealData() async {
    setState(() => _loading = true);
    try {
      await _controller.init();

      final now = DateTime.now();
      final time = _resolveTimeOfDay(now);
      final firebaseUser = _auth.currentUser;
      final profile = await _profile.getOrCreateProfile();
      final uid = firebaseUser?.uid;

      String realName = '';
      final profileName = profile.name.trim();
      if (profileName.isNotEmpty) realName = profileName;
      if (realName.isEmpty) {
        realName = (firebaseUser?.displayName ?? '').trim();
      }

      if (realName.isEmpty && uid != null) {
        final preferred = await _dashboard.getUserPreferredName(
          uid: uid,
          fallbackEmail: firebaseUser?.email,
        );
        realName = (preferred ?? '').trim();
      }

      if (realName.isEmpty) {
        final email = (firebaseUser?.email ?? '').trim();
        if (email.contains('@')) realName = email.split('@').first;
      }
      if (realName.isEmpty) realName = 'Usuario';

      HomeDashboardData? dashboardData;
      Map<String, dynamic>? homeConfig;
      Map<String, dynamic>? homeHeader;
      if (uid != null) {
        dashboardData = await _dashboard.loadDashboard(
          uid: uid,
          todayKey: _controller.todayKey,
          todayCfScore: _controller.displayedCfIndex,
        );
        homeConfig = await _dashboard.getUserHomeConfig(uid: uid);
        homeHeader = await _dashboard.getDailyHomeHeader(uid: uid, dateKey: _controller.todayKey);
      }

      final profilePlace = (profile.usualTrainingPlace ?? '').trim();
      final configTemp = (homeConfig?['temperatureC'] as num?)?.round();
      final cityLabel = profilePlace.isNotEmpty ? profilePlace : 'Ubicación no disponible';
      final tempLabel = configTemp == null ? '--°C' : '$configTemp°C';

      final challenge = dashboardData?.weeklyChallenge;
      final habits = dashboardData?.habits ?? const <HabitItem>[];
      final tasks = dashboardData?.tasks ?? const <TaskItem>[];

      final habitsMapped = habits
          .map(
            (h) => {
              'id': h.id,
              'name': h.name,
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
              'difficulty': _pointsToDifficulty(t.cfReward),
              'cfPoints': t.cfReward,
              'isCompleted': t.completed,
            },
          )
          .toList();

      final dailyProgress = (_controller.dailyMissionProgress * 100).round().clamp(0, 100);
      final weeklyProgress = ((dashboardData?.weeklyGoals.progress ?? _controller.weeklyMissionProgress) * 100)
          .round()
          .clamp(0, 100);
        final hasMood = dashboardData?.hasMoodToday ??
          (_controller.todayData.energy != null &&
            _controller.todayData.mood != null &&
            _controller.todayData.stress != null &&
            _controller.todayData.sleep != null);
        final moodIcon = ((homeHeader?['moodIcon'] as String?) ?? '').trim();

      final next = _userData.copyWith(
        name: realName,
        currentCFIndex: _controller.displayedCfIndex,
        dailyStreak: dashboardData?.streak ?? _controller.streakCount,
        weeklyStreak: dashboardData?.weeklyStreak ?? 0,
        moodRegisteredToday: hasMood,
        currentMoodIcon: moodIcon.isNotEmpty ? moodIcon : _userData.currentMoodIcon,
        waterIntake: {
          'current': (_controller.todayData.waterLiters * 1000).round(),
          'target': 2000,
        },
        stepsCount: {
          'current': _controller.todayData.steps,
          'target': 8000,
        },
        dailyGoal: {
          ...((homeConfig?['dailyGoal'] is Map)
              ? Map<String, dynamic>.from(homeConfig?['dailyGoal'] as Map)
              : {
                  'type': _userData.dailyGoal['type'] ?? 'Entrenamiento',
                  'description': _userData.dailyGoal['description'] ?? 'Completar misión diaria',
                  'target': _userData.dailyGoal['target'] ?? 100,
                }),
          'progress': dailyProgress,
        },
        weeklyGoal: {
          ...((homeConfig?['weeklyGoal'] is Map)
              ? Map<String, dynamic>.from(homeConfig?['weeklyGoal'] as Map)
              : {
                  'type': _userData.weeklyGoal['type'] ?? 'Hábitos',
                  'description': _userData.weeklyGoal['description'] ?? 'Cumplir objetivos semanales',
                  'target': _userData.weeklyGoal['target'] ?? 100,
                }),
          'progress': weeklyProgress,
        },
        weeklyChallenge: {
          'title': challenge?.title ?? 'Sin reto activo',
          'description': challenge?.description ?? 'No hay reto activo. ¡Pronto uno nuevo!',
          'userProgress': challenge?.progressValue ?? 0,
          'target': challenge?.targetValue ?? 1,
          'communityProgress': ((challenge?.progress ?? 0) * 100).round(),
          'reward': '+${challenge?.rewardCfBonus ?? 0} CF',
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
        _weekDays = dashboardData?.weekDays ?? const [];
        _cityLabel = cityLabel;
        _tempLabel = tempLabel;
        _suggestionVisible = true;
        if (_suggestionIndex >= suggestions.length) {
          _suggestionIndex = 0;
        }
      });

      if (uid != null) {
        await _dashboard.saveDailyStatsSnapshot(
          uid: uid,
          dateKey: _controller.todayKey,
          cfIndex: next.currentCFIndex,
          steps: next.stepsCount['current'] ?? 0,
          waterMl: next.waterIntake['current'] ?? 0,
        );
        await _dashboard.saveDailyHomeHeader(
          uid: uid,
          dateKey: _controller.todayKey,
          timeOfDay: next.currentTimeOfDay,
          moodRegistered: next.moodRegisteredToday,
          moodIcon: next.currentMoodIcon,
          suggestion: suggestions.first,
        );
      }
      await _refreshEnvironmentInfo();
    } catch (_) {
      final fallbackTime = _resolveTimeOfDay(DateTime.now());
      final fallbackUser = _auth.currentUser;
      final email = (fallbackUser?.email ?? '').trim();
      final fallbackName = (fallbackUser?.displayName ?? '').trim().isNotEmpty
          ? (fallbackUser?.displayName ?? '').trim()
          : (email.contains('@') ? email.split('@').first : 'Usuario');

      if (!mounted) return;
      setState(() {
        _userData = _userData.copyWith(
          name: fallbackName,
          currentTimeOfDay: fallbackTime,
        );
        _cityLabel = 'Ubicación no disponible';
        _tempLabel = '--°C';
        _suggestionVisible = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
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
    _clockNow = DateTime.now();
    final secondsToNextMinute = 60 - _clockNow.second;

    Future<void>.delayed(Duration(seconds: secondsToNextMinute), () {
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

  Future<void> _refreshEnvironmentInfo() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _cityLabel = 'Activa ubicación';
          _tempLabel = '--°C';
          _weatherEmoji = _clockNow.hour >= 7 && _clockNow.hour < 20 ? '☀️' : '🌙';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _cityLabel = 'Permite ubicación';
          _tempLabel = '--°C';
          _weatherEmoji = _clockNow.hour >= 7 && _clockNow.hour < 20 ? '☀️' : '🌙';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      var city = (place?.locality ?? place?.subAdministrativeArea ?? place?.administrativeArea ?? '').trim();

      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current=temperature_2m,weather_code,is_day&timezone=auto',
      );
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      final current = decoded['current'];
      if (current is! Map<String, dynamic>) return;
      final timezoneName = (decoded['timezone'] as String? ?? '').trim();

      final temp = (current['temperature_2m'] as num?)?.round();
      final weatherCode = (current['weather_code'] as num?)?.toInt() ?? -1;
      final isDay = (current['is_day'] as num?)?.toInt() == 1;
      if (city.isEmpty && timezoneName.contains('/')) {
        city = timezoneName.split('/').last.replaceAll('_', ' ');
      }

      if (!mounted) return;
      setState(() {
        _cityLabel = city.isNotEmpty ? city : 'Ubicación detectada';
        if (temp != null) _tempLabel = '$temp°C';
        _weatherEmoji = _weatherEmojiFor(weatherCode: weatherCode, isDay: isDay);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherEmoji = _clockNow.hour >= 7 && _clockNow.hour < 20 ? '☀️' : '🌙';
      });
    }
  }

  String _weatherEmojiFor({required int weatherCode, required bool isDay}) {
    if (weatherCode == 0) return isDay ? '☀️' : '🌙';
    if (weatherCode == 1 || weatherCode == 2) return '🌤️';
    if (weatherCode == 3 || weatherCode == 45 || weatherCode == 48) return '☁️';
    if (weatherCode == 51 || weatherCode == 53 || weatherCode == 55) return '🌦️';
    if (weatherCode == 61 || weatherCode == 63 || weatherCode == 65) return '🌧️';
    if (weatherCode == 71 || weatherCode == 73 || weatherCode == 75 || weatherCode == 77) return '❄️';
    if (weatherCode == 80 || weatherCode == 81 || weatherCode == 82) return '🌧️';
    if (weatherCode == 95 || weatherCode == 96 || weatherCode == 99) return '⛈️';
    return isDay ? '☀️' : '🌙';
  }

  String _pointsToDifficulty(int points) {
    if (points >= 25) return 'Épica';
    if (points >= 15) return 'Difícil';
    if (points >= 10) return 'Media';
    return 'Fácil';
  }

  String _dueDateLabel(DateTime? dueDate) {
    if (dueDate == null) return 'Sin fecha';
    final today = DateUtilsCF.dateOnly(DateTime.now());
    final due = DateUtilsCF.dateOnly(dueDate);
    final diff = due.difference(today).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    return '${due.day.toString().padLeft(2, '0')}/${due.month.toString().padLeft(2, '0')}';
  }

  ({String greeting, String question}) _greetingFor() {
    final name = _userData.name;
    switch (_userData.currentTimeOfDay) {
      case 'morning':
        return (greeting: 'Buenos días, $name', question: '¿Cómo te despertaste hoy?');
      case 'afternoon':
        return (greeting: 'Buenas tardes, $name', question: '¿Qué quieres hacer ahora?');
      case 'evening':
        return (greeting: 'Buenas noches, $name', question: '¿Qué te apetece hacer?');
      default:
        return (greeting: 'Buenas noches, $name', question: '¿Qué quieres hacer antes de dormir?');
    }
  }

  String _timeTempPlaceLine() {
    final now = TimeOfDay.fromDateTime(_clockNow);
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm · $_tempLabel · $_cityLabel $_weatherEmoji';
  }

  String _streakLine() {
    final streak = _userData.dailyStreak;
    return 'Llevas $streak días seguidos 🔥';
  }

  String _coachMicroMessage() {
    final daily = (_userData.dailyGoal['progress'] as int? ?? 0).clamp(0, 100);
    final weekly = (_userData.weeklyGoal['progress'] as int? ?? 0).clamp(0, 100);
    final streak = _userData.dailyStreak;
    if (streak >= 7) return 'Tu constancia ya marca diferencia.';
    if (daily >= 80) return 'Cierra fuerte, hoy casi lo completas.';
    if (weekly >= 70) return 'Buen ritmo, protege tu ventaja semanal.';
    if (streak >= 3) return 'No sueltes, estás en una buena racha.';
    return 'Empieza simple, hoy cuenta de verdad.';
  }

  String _moodText(Map<String, dynamic> insight) {
    final icon = ((insight['moodIcon'] as String?) ?? '').trim();
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
            Text('¡Hola, ${_userData.name}! ¿Cómo te sientes hoy?', style: Theme.of(context).textTheme.titleLarge),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: CFColors.softGray),
                          borderRadius: const BorderRadius.all(Radius.circular(14)),
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

    int energy = 3;
    int mood = 3;
    int stress = 3;
    int sleep = 3;
    final tags = <String>{};

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cuéntanos más (opcional)', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                _levelRow('¿Cuánta energía tienes hoy?', energy, (v) => setLocal(() => energy = v)),
                _levelRow('¿Estás animado?', mood, (v) => setLocal(() => mood = v)),
                _levelRow('¿Hoy estás estresado?', stress, (v) => setLocal(() => stress = v)),
                _levelRow('¿Tienes sueño?', sleep, (v) => setLocal(() => sleep = v)),
                const Text('1 es poco · 5 es mucho', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['#DormíPoco', '#EntrenoDuro', '#MuchoTrabajo', '#BuenDía', '#EstrésAlto']
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

    if (!mounted) return;
    setState(() {
      _userData = _userData.copyWith(
        moodRegisteredToday: true,
        currentMoodIcon: emoji,
        currentCFIndex: (_userData.currentCFIndex + (saved == true ? 3 : 1)).clamp(0, 100),
      );
    });
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _dashboard.saveDailyHomeHeader(
        uid: uid,
        dateKey: _controller.todayKey,
        timeOfDay: _userData.currentTimeOfDay,
        moodRegistered: true,
        moodIcon: emoji,
        suggestion: _suggestionForNow(),
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
                  color: level <= value ? CFColors.primary : CFColors.textSecondary,
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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlaceholderScreen(title: fallbackTitle)));
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
      insight = await _dashboard.getDailyInsight(uid: uid, dateKey: DateUtilsCF.toKey(date));
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
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
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
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text('Puntuaje CF: ${insight['cfIndex'] ?? 0}'),
                    Text('Pasos: ${insight['steps'] ?? 0}'),
                    Text('Agua: ${(((insight['waterLiters'] as num?) ?? 0).toDouble()).toStringAsFixed(1)} L'),
                    Text('Estado de ánimo: ${_moodText(insight)}'),
                    Text('Resumen de deporte: ${_sportSummary(insight)}'),
                    Text('Resumen de alimentación: ${_foodSummary(insight)}'),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
          ],
        ),
      ),
    );
  }

  Future<void> _showCfAndStreakDialog() async {
    final history = await _storage.getCfHistory();
    final keys = history.keys.toList()..sort();
    final recent = keys.length <= 14 ? keys : keys.sublist(keys.length - 14);
    final cfSeries = recent.map((k) => history[k] ?? 0).toList();
    final safeSeries = cfSeries.isEmpty ? <int>[_userData.currentCFIndex] : cfSeries;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rachas y Puntuaje CF'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Puntuaje CF (últimos días)'),
              const SizedBox(height: 8),
              SizedBox(height: 120, child: _BarsChart(values: safeSeries)),
              const SizedBox(height: 10),
              Text('Racha diaria: ${_userData.dailyStreak} días'),
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Future<void> _showWaterDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final current = _userData.waterIntake['current'] ?? 0;
          final target = _userData.waterIntake['target'] ?? 2000;
          final progress = (current / (target <= 0 ? 1 : target)).clamp(0.0, 1.0);

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
                    final nextMl = (_controller.todayData.waterLiters * 1000).round();
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
                  label: const Text('Añadir 250 ml'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
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
    final weekly = await _collectStepSeries(7);
    final monthly = await _collectStepSeries(30);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pasos por semana y mes'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Últimos 7 días'),
                const SizedBox(height: 8),
                SizedBox(height: 120, child: _BarsChart(values: weekly)),
                const SizedBox(height: 12),
                const Text('Últimos 30 días'),
                const SizedBox(height: 8),
                SizedBox(height: 120, child: _BarsChart(values: monthly)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  String _heroCfLabel() {
    final cf = _userData.currentCFIndex;
    if (cf >= 85) return 'Excelente';
    if (cf >= 65) return 'Muy bien';
    if (cf >= 45) return 'En progreso';
    return 'Empezando';
  }

  List<Map<String, dynamic>> _suggestionsForNow() {
    final h = DateTime.now().hour;
    final steps = _userData.stepsCount['current'] ?? 0;
    final water = _userData.waterIntake['current'] ?? 0;
    final stress = _controller.todayData.stress ?? 3;
    final sleep = _controller.todayData.sleep ?? 3;
    final didWorkout = _controller.workoutCompleted;

    final out = <Map<String, dynamic>>[];

    if (h < 12 && steps < 1200) {
      out.add({
        'badge': 'Ideal para ahora',
        'title': 'Despertar suave',
        'microcopy': 'Tu cuerpo pide movimiento. ¿Qué tal 10 min de yoga para despertar?',
        'button': 'Estirar',
        'icon': Icons.self_improvement_outlined,
        'tab': 3,
      });
    }
    if (didWorkout && h >= 12 && h < 19) {
      out.add({
        'badge': 'Post-entreno',
        'title': 'Recuperación inteligente',
        'microcopy': '¡Gran esfuerzo! Recupera energía con un bowl de proteína y verduras.',
        'button': 'Ver receta',
        'icon': Icons.ramen_dining_outlined,
        'tab': 0,
      });
    }
    if (h >= 19 && (stress >= 4 || sleep <= 2)) {
      out.add({
        'badge': 'Basado en tu estado',
        'title': 'Calma mental',
        'microcopy': 'Día intenso. Una meditación de 3 min te ayudará a descansar mejor.',
        'button': 'Meditar',
        'icon': Icons.nights_stay_outlined,
        'tab': 3,
      });
    }
    if (water < 1000) {
      out.add({
        'badge': 'Basado en tu hidratación',
        'title': 'Hidratación rápida',
        'microcopy': 'Vas por debajo de tu meta. Un vaso de agua ahora te ayuda mucho.',
        'button': 'Registrar agua',
        'icon': Icons.water_drop_outlined,
        'action': 'water',
      });
    }

    out.addAll([
      {
        'badge': 'Recomendación del momento',
        'title': 'Paseo digestivo',
        'microcopy': '15 min de caminata para evitar el bajón y sumar pasos diarios.',
        'button': 'Registrar pasos',
        'icon': Icons.directions_walk_outlined,
        'action': 'steps',
      },
      {
        'badge': 'Recomendación del momento',
        'title': 'Mini chequeo',
        'microcopy': 'Revisa tu estado de ánimo para ajustar mejor tu día.',
        'button': 'Registrar estado',
        'icon': Icons.mood_outlined,
        'action': 'mood',
      },
    ]);

    return out;
  }

  Map<String, dynamic> _suggestionForNow() {
    final list = _suggestionsForNow();
    return list.isNotEmpty ? list.first : const <String, dynamic>{};
  }

  Future<void> _executeSuggestion(Map<String, dynamic> suggestion) async {
    final action = (suggestion['action'] as String? ?? '').trim();
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
    String selectedType = (current['type'] as String? ?? 'Entrenamiento').trim();
    final templatesSource = weekly ? _weeklyGoalTemplates : _dailyGoalTemplates;
    final initialOptions = templatesSource[selectedType] ?? const <Map<String, dynamic>>[];
    var selectedTemplate = initialOptions.isNotEmpty
      ? initialOptions.first
      : {
        'description': current['description'] ?? (weekly ? 'Objetivo semanal' : 'Objetivo diario'),
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
                    DropdownMenuItem(value: 'Entrenamiento', child: Text('Entrenamiento')),
                    DropdownMenuItem(value: 'Nutrición', child: Text('Nutrición')),
                    DropdownMenuItem(value: 'Hidratación', child: Text('Hidratación')),
                    DropdownMenuItem(value: 'Meditación', child: Text('Meditación')),
                    DropdownMenuItem(value: 'Pasos', child: Text('Pasos')),
                    DropdownMenuItem(value: 'Hábitos', child: Text('Hábitos')),
                  ],
                  onChanged: (v) {
                    setLocal(() {
                      selectedType = v ?? 'Entrenamiento';
                      final options = templatesSource[selectedType] ?? const <Map<String, dynamic>>[];
                      if (options.isNotEmpty) selectedTemplate = options.first;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Tipo de objetivo'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: ((templatesSource[selectedType] ?? const <Map<String, dynamic>>[])
                          .any((opt) => opt['description'] == selectedTemplate['description']))
                      ? selectedTemplate['description'] as String?
                      : null,
                  items: (templatesSource[selectedType] ?? const <Map<String, dynamic>>[])
                      .map(
                        (opt) => DropdownMenuItem<String>(
                          value: opt['description'] as String,
                          child: Text('${opt['description']} (meta: ${opt['target']})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    final options = templatesSource[selectedType] ?? const <Map<String, dynamic>>[];
                    setLocal(() {
                      selectedTemplate = options.firstWhere(
                        (opt) => opt['description'] == v,
                        orElse: () => options.isNotEmpty ? options.first : selectedTemplate,
                      );
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Objetivo predefinido'),
                ),
                const SizedBox(height: 8),
                const Text('Objetivos predefinidos por tipo. Puedes cambiarlos cuando quieras.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
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
      _userData = weekly ? _userData.copyWith(weeklyGoal: next) : _userData.copyWith(dailyGoal: next);
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
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(c['title'] as String? ?? 'Reto semanal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c['description'] as String? ?? ''),
            const SizedBox(height: 10),
            Text('Tu progreso: ${c['userProgress']}/${c['target']}'),
            Text('Comunidad: ${c['communityProgress']}%'),
            Text('Recompensa: ${c['reward']}'),
            const SizedBox(height: 8),
            const Text('Este bloque se alimenta desde weeklyChallenges en Firestore.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  int _difficultyPoints(String difficulty) => _difficultyToPoints[difficulty] ?? 5;

  Future<void> _openHabitEditor({Map<String, dynamic>? existing}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final selectedDays = <int>{1, 2, 3, 4, 5, 6, 7};
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
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre del hábito')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: difficulty,
                  items: _difficultyToPoints.keys
                      .map((k) => DropdownMenuItem(value: k, child: Text('$k (+${_difficultyToPoints[k]} CF)')))
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
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (save != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final points = _difficultyPoints(difficulty);

    if (existing == null) {
      await _dashboard.createHabit(uid: uid, name: name, repeatDays: selectedDays.toList()..sort(), cfReward: points);
    } else {
      await _dashboard.updateHabit(
        uid: uid,
        habitId: existing['id'] as String,
        name: name,
        repeatDays: selectedDays.toList()..sort(),
        cfReward: points,
      );
    }

    await _loadRealData();
  }

  Future<void> _openTaskEditor({Map<String, dynamic>? existing}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final titleCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    String difficulty = existing?['difficulty'] as String? ?? 'Media';
    DateTime? dueDate;

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Añadir tarea' : 'Editar tarea'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Nombre de la tarea')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: difficulty,
                  items: _difficultyToPoints.keys
                      .map((k) => DropdownMenuItem(value: k, child: Text('$k (+${_difficultyToPoints[k]} CF)')))
                      .toList(),
                  onChanged: (v) => setLocal(() => difficulty = v ?? 'Media'),
                  decoration: const InputDecoration(labelText: 'Dificultad'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    dueDate == null
                        ? 'Sin fecha'
                        : 'Fecha: ${dueDate!.day.toString().padLeft(2, '0')}/${dueDate!.month.toString().padLeft(2, '0')}/${dueDate!.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setLocal(() => dueDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (save != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final points = _difficultyPoints(difficulty);

    if (existing == null) {
      await _dashboard.createTask(
        uid: uid,
        title: title,
        dueDate: dueDate,
        cfReward: points,
        notificationEnabled: true,
      );
    } else {
      await _dashboard.updateTask(
        uid: uid,
        taskId: existing['id'] as String,
        title: title,
        dueDate: dueDate,
        cfReward: points,
        notificationEnabled: true,
      );
    }

    await _loadRealData();
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
        habits: _userData.habits.where((h) => h['id'] != id).toList(growable: false),
      );
    });
  }

  Future<void> _deleteTask(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _dashboard.deleteTask(uid: uid, taskId: id);
    if (!mounted) return;
    setState(() {
      _userData = _userData.copyWith(
        todos: _userData.todos.where((t) => t['id'] != id).toList(growable: false),
      );
    });
  }

  Future<void> _applyCfBonus(int points) async {
    final dateKey = DateUtilsCF.toKey(DateTime.now());
    final history = await _storage.getCfHistory();
    final current = (history[dateKey] ?? _controller.displayedCfIndex).clamp(0, 100);
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
              children: _userData.habits
                  .map(
                    (h) => ListTile(
                      leading: Icon(h['isCompleted'] == true ? Icons.check_circle : Icons.radio_button_unchecked),
                      title: Text(h['name'] as String? ?? ''),
                      subtitle: Text('${h['difficulty']} · +${h['cfPoints']} CF'),
                      trailing: IconButton(
                        onPressed: () async {
                          final id = h['id'] as String?;
                          if (id == null) return;
                          await _deleteHabit(id);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          _showAllHabitsDialog();
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
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
              children: _userData.todos
                  .map(
                    (t) => ListTile(
                      leading: Icon(t['isCompleted'] == true ? Icons.check_circle : Icons.radio_button_unchecked),
                      title: Text(t['name'] as String? ?? ''),
                      subtitle: Text('${t['dueDate']} · ${t['difficulty']} · +${t['cfPoints']} CF'),
                      trailing: IconButton(
                        onPressed: () async {
                          final id = t['id'] as String?;
                          if (id == null) return;
                          await _deleteTask(id);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          _showAllTasksDialog();
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _block({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CFColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: CFColors.softGray),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingFor();
    final cfProgress = (_userData.currentCFIndex / 100).clamp(0.0, 1.0);
    final suggestions = _suggestionsForNow();
    final habitsPreview = _userData.habits.where((h) => h['isCompleted'] != true).take(4).toList();
    final tasksPreview = _userData.todos.where((t) => t['isCompleted'] != true).take(4).toList();

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadRealData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _block(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(greeting.greeting, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(_timeTempPlaceLine(), style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 2),
                          Text(_streakLine(), style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 2),
                          Text(_coachMicroMessage(), style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: _showMoodCheckModal,
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _userData.moodRegisteredToday
                                    ? CFColors.primary.withValues(alpha: 0.07)
                                    : CFColors.primary.withValues(alpha: 0.15),
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _userData.moodRegisteredToday
                                          ? 'Estado de ánimo de hoy: ${_userData.currentMoodIcon}'
                                          : '¿Cómo te sientes hoy?',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
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
                          Text('Recomendación del momento', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          AnimatedSlide(
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeOutCubic,
                            offset: _suggestionVisible ? Offset.zero : const Offset(0, 0.12),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 420),
                              opacity: _suggestionVisible ? 1 : 0,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 188,
                                    child: PageView.builder(
                                      controller: _suggestionPageController,
                                      itemCount: suggestions.length,
                                      onPageChanged: (index) => setState(() => _suggestionIndex = index),
                                      itemBuilder: (context, index) {
                                        final suggestion = suggestions[index];
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: const BorderRadius.all(Radius.circular(22)),
                                              onTap: () => _executeSuggestion(suggestion),
                                              child: ClipRRect(
                                                borderRadius: const BorderRadius.all(Radius.circular(22)),
                                                child: BackdropFilter(
                                                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(14),
                                                    decoration: BoxDecoration(
                                                      color: CFColors.primary.withValues(alpha: 0.08),
                                                      borderRadius: const BorderRadius.all(Radius.circular(22)),
                                                      border: Border.all(color: CFColors.softGray),
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Container(
                                                          width: 52,
                                                          height: 52,
                                                          decoration: BoxDecoration(
                                                            color: CFColors.primary.withValues(alpha: 0.16),
                                                            borderRadius: const BorderRadius.all(Radius.circular(16)),
                                                          ),
                                                          child: Icon(
                                                            suggestion['icon'] as IconData? ?? Icons.auto_awesome_outlined,
                                                            color: CFColors.primary,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                decoration: BoxDecoration(
                                                                  color: CFColors.primary.withValues(alpha: 0.18),
                                                                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                                                                ),
                                                                child: Text(
                                                                  suggestion['badge'] as String? ?? 'Ideal para ahora',
                                                                  style: Theme.of(context).textTheme.bodyMedium,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 8),
                                                              Text(
                                                                suggestion['title'] as String? ?? 'Sugerencia',
                                                                style: Theme.of(context).textTheme.titleLarge,
                                                              ),
                                                              const SizedBox(height: 4),
                                                              Text(
                                                                suggestion['microcopy'] as String? ?? '',
                                                                style: Theme.of(context).textTheme.bodyMedium,
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
                                                _suggestionPageController.previousPage(
                                                  duration: const Duration(milliseconds: 220),
                                                  curve: Curves.easeOut,
                                                );
                                              },
                                        icon: const Icon(Icons.chevron_left),
                                      ),
                                      ...List.generate(
                                        suggestions.length,
                                        (i) => Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          width: i == _suggestionIndex ? 16 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: i == _suggestionIndex
                                                ? CFColors.primary
                                                : CFColors.primary.withValues(alpha: 0.25),
                                            borderRadius: const BorderRadius.all(Radius.circular(99)),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: _suggestionIndex >= suggestions.length - 1
                                            ? null
                                            : () {
                                                _suggestionPageController.nextPage(
                                                  duration: const Duration(milliseconds: 220),
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
                          Text('Estado de tu semana', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _showMonthCalendarDialog,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(7, (i) {
                                final date = DateUtilsCF.dateOnly(DateTime.now())
                                    .subtract(Duration(days: DateTime.now().weekday - 1))
                                    .add(Duration(days: i));
                                final isToday = DateUtilsCF.isSameDay(date, DateTime.now());
                                final key = DateUtilsCF.toKey(date);
                                HomeDayStat? dayStat;
                                for (final d in _weekDays) {
                                  if (d.dateKey == key) {
                                    dayStat = d;
                                    break;
                                  }
                                }
                                final cf = (dayStat?.cfScore ?? 0).clamp(0, 100);
                                final t = cf / 100.0;
                                final base = Color.lerp(CFColors.softGray, CFColors.primary, t) ?? CFColors.softGray;
                                const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                                return Column(
                                  children: [
                                    Text(labels[i]),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isToday ? CFColors.primary : base.withValues(alpha: 0.85),
                                        border: isToday ? Border.all(color: CFColors.textPrimary, width: 1.2) : null,
                                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                                      ),
                                      child: Text(
                                        '${date.day}',
                                        style: TextStyle(
                                          color: isToday ? Colors.white : CFColors.textPrimary,
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
                                        color: CFColors.primary.withValues(alpha: 0.06),
                                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text('Racha'),
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
                                        color: CFColors.primary.withValues(alpha: 0.06),
                                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text('Puntaje CF'),
                                          const SizedBox(height: 4),
                                          ClipRRect(
                                            borderRadius: const BorderRadius.all(Radius.circular(999)),
                                            child: LinearProgressIndicator(
                                              value: cfProgress,
                                              minHeight: 8,
                                              backgroundColor: CFColors.softGray,
                                              valueColor: const AlwaysStoppedAnimation(CFColors.primary),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text('${_userData.currentCFIndex} · ${_heroCfLabel()}'),
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
                                  const Icon(Icons.water_drop_outlined, color: CFColors.primary),
                                  const SizedBox(height: 6),
                                  const Text('Agua'),
                                  Text('${_userData.waterIntake['current']}/${_userData.waterIntake['target']} ml'),
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
                                  const Icon(Icons.directions_walk_outlined, color: CFColors.primary),
                                  const SizedBox(height: 6),
                                  const Text('Pasos'),
                                  Text('${_userData.stepsCount['current']}/${_userData.stepsCount['target']}'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _block(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Metas y objetivos', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => _openGoalEditor(weekly: false),
                            child: _goalCard(
                              title: 'Objetivo diario',
                              description: '${_userData.dailyGoal['type']} · ${_userData.dailyGoal['description']}',
                              progress: (_userData.dailyGoal['progress'] as int? ?? 0),
                              target: (_userData.dailyGoal['target'] as int? ?? 100),
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _openGoalEditor(weekly: true),
                            child: _goalCard(
                              title: 'Objetivo semanal',
                              description: '${_userData.weeklyGoal['type']} · ${_userData.weeklyGoal['description']}',
                              progress: (_userData.weeklyGoal['progress'] as int? ?? 0),
                              target: (_userData.weeklyGoal['target'] as int? ?? 100),
                              extra: 'Racha semanal: ${_userData.weeklyStreak}',
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
                            Text('Reto semanal', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 6),
                            Text(_userData.weeklyChallenge['title'] as String),
                            const SizedBox(height: 4),
                            Text(_userData.weeklyChallenge['description'] as String),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: const BorderRadius.all(Radius.circular(999)),
                              child: LinearProgressIndicator(
                                value: ((_userData.weeklyChallenge['userProgress'] as int) /
                                        ((_userData.weeklyChallenge['target'] as int) <= 0
                                            ? 1
                                            : (_userData.weeklyChallenge['target'] as int)))
                                    .clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: CFColors.softGray,
                                valueColor: const AlwaysStoppedAnimation(CFColors.primary),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Recompensa: ${_userData.weeklyChallenge['reward']}'),
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
                              Expanded(child: Text('Hábitos', style: Theme.of(context).textTheme.titleLarge)),
                              TextButton(onPressed: _showAllHabitsDialog, child: const Text('Ver todos')),
                              IconButton(
                                onPressed: () => _openHabitEditor(),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                          if (habitsPreview.isEmpty)
                            const Text('No tienes hábitos pendientes.')
                          else
                            ...habitsPreview.map(
                              (h) => CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: h['isCompleted'] == true,
                                onChanged: (v) => _toggleHabit(h, v ?? false),
                                title: Text(h['name'] as String),
                                subtitle: Text('${h['difficulty']} · +${h['cfPoints']} CF'),
                                secondary: IconButton(
                                  onPressed: () => _openHabitEditor(existing: h),
                                  icon: const Icon(Icons.edit_outlined),
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
                          Row(
                            children: [
                              Expanded(child: Text('Lista de cosas que hacer', style: Theme.of(context).textTheme.titleLarge)),
                              TextButton(onPressed: _showAllTasksDialog, child: const Text('Ver todas')),
                              IconButton(
                                onPressed: () => _openTaskEditor(),
                                icon: const Icon(Icons.post_add_outlined),
                              ),
                            ],
                          ),
                          if (tasksPreview.isEmpty)
                            const Text('No tienes tareas pendientes.')
                          else
                            ...tasksPreview.map(
                              (t) => CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: t['isCompleted'] == true,
                                onChanged: (v) => _toggleTask(t, v ?? false),
                                title: Text(t['name'] as String),
                                subtitle: Text('${t['dueDate']} · ${t['difficulty']} · +${t['cfPoints']} CF'),
                                secondary: IconButton(
                                  onPressed: () => _openTaskEditor(existing: t),
                                  icon: const Icon(Icons.edit_outlined),
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

class _BarsChart extends StatelessWidget {
  const _BarsChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final max = values.reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values
          .map(
            (v) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: (max <= 0 ? 0 : ((v / max) * 110)).clamp(2, 110).toDouble(),
                  decoration: const BoxDecoration(
                    color: CFColors.primary,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                ),
              ),
            ),
          )
          .toList(),
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
