import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/user_profile.dart';
import '../services/app_permissions_service.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../services/push_token_service.dart';
import '../services/settings_service.dart';
import '../services/task_reminder_service.dart';
import '../widgets/progress/progress_section_card.dart';
import '../widgets/profile/streak_preferences_editor.dart';
import 'main_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _totalSteps = 8;
  static const _quickMinutes = <int>[20, 30, 45, 60, 90];
  static const _quickNotificationMinutes = <int>[450, 840, 1230, 1320];
  static const _stepInfos = <_OnboardingStepInfo>[
    _OnboardingStepInfo(
      eyebrow: 'Permisos',
      title: 'Lo que la app puede pedirte',
      description:
          'Te enseñamos desde el principio qué accesos usa CotidyFit y para qué sirve cada uno.',
      icon: Icons.verified_user_rounded,
    ),
    _OnboardingStepInfo(
      eyebrow: 'Objetivo',
      title: 'Vamos a enfocar tu plan',
      description:
          'Elige qué quieres conseguir primero y te montamos un arranque con sentido.',
      icon: Icons.flag_rounded,
    ),
    _OnboardingStepInfo(
      eyebrow: 'Racha',
      title: 'Haz que volver apetezca',
      description:
          'Personaliza qué cuenta como constancia para que la app juegue a tu favor.',
      icon: Icons.local_fire_department_rounded,
    ),
    _OnboardingStepInfo(
      eyebrow: 'Perfil',
      title: 'Ajustamos la base',
      description:
          'Cuatro datos rápidos para que las recomendaciones tengan contexto real.',
      icon: Icons.person_rounded,
    ),
    _OnboardingStepInfo(
      eyebrow: 'Tiempo',
      title: 'Encájalo en tu semana',
      description:
          'Tu nivel y tu tiempo mandan. El plan se adapta a eso, no al revés.',
      icon: Icons.schedule_rounded,
    ),
    _OnboardingStepInfo(
      eyebrow: 'Preferencias',
      title: 'Diseña cómo quieres entrenar',
      description:
          'Lugar, días y estilo: cuanto mejor se parezca a tu vida, más fácil será seguir.',
      icon: Icons.tune_rounded,
    ),
    _OnboardingStepInfo(
      eyebrow: 'Contexto',
      title: 'Ponemos límites y condiciones',
      description:
          'Nos ayudas a evitar recomendaciones absurdas y a darte algo más útil.',
      icon: Icons.health_and_safety_rounded,
    ),
    _OnboardingStepInfo(
      eyebrow: 'Recordatorios',
      title: 'Cierra el arranque',
      description:
          'Elige una hora cómoda para que la app te acompañe sin molestar.',
      icon: Icons.notifications_active_rounded,
    ),
  ];

  static const _goals = <String>[
    'Perder grasa',
    'Ganar masa muscular',
    'Mantener peso',
    'Mejorar hábitos',
  ];

  static const _sportPreferences = <String>[
    'Fuerza',
    'Cardio',
    'Movilidad',
    'HIIT',
    'Yoga',
    'Calistenia',
    'Funcional',
  ];

  static const _injuryOptions = <String>[
    'Rodilla',
    'Espalda baja',
    'Hombro',
    'Tobillo',
    'Cuello',
    'Ninguna',
  ];

  static const _healthConditionOptions = <String>[
    'Hipertensión',
    'Diabetes tipo 1',
    'Diabetes tipo 2',
    'Colesterol alto',
    'Problemas cardíacos',
    'Asma',
    'Obesidad',
    'Problemas articulares',
    'Ansiedad / estrés crónico',
    'Ninguna',
    'Otra',
  ];

  static const _trainingPlaces = <String>[
    'En casa',
    'Al aire libre',
    'Gimnasio',
    'Parque de calistenia',
    'Mixto',
  ];

  final _service = ProfileService();
  final _onboardingService = OnboardingService();
  final _settingsService = SettingsService();
  final _permissionsService = AppPermissionsService();

  UserProfile? _existing;
  AppPermissionsSnapshot? _permissionSnapshot;

  int _step = 0;
  bool _isAdvancing = true;
  String? _selected;
  final _ageCtrl = TextEditingController();
  UserSex? _sex;
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  UserLevel _level = UserLevel.principiante;
  final _minutesCtrl = TextEditingController();
  TimeOfDay? _availabilityStart;
  TimeOfDay? _availabilityEnd;

  String? _trainingPlace;
  final Set<int> _availableDays = <int>{};
  final Set<String> _prefs = <String>{};

  final Set<String> _injuries = <String>{};
  final Set<String> _healthConditions = <String>{};
  WorkType? _workType;

  TimeOfDay? _notificationTime;
  UserStreakPreferences _streakPreferences = UserStreakPreferences();

  bool _permissionsReviewed = false;
  bool _requestingPermissions = false;
  bool _saving = false;

  _OnboardingStepInfo get _stepInfo => _stepInfos[_step];

  @override
  void initState() {
    super.initState();
    _permissionsReviewed = widget.isEditing;
    _loadExisting();
    _refreshPermissionSnapshot();
  }

  Future<void> _loadExisting() async {
    final existing = await _service.getProfile();
    if (!mounted) return;
    setState(() {
      _existing = existing;

      _selected = existing?.goal;
      _ageCtrl.text = existing?.age?.toString() ?? '';
      _sex = existing?.sex;
      _heightCtrl.text = existing?.heightCm?.toStringAsFixed(0) ?? '';
      _weightCtrl.text = existing?.currentWeightKg?.toStringAsFixed(1) ?? '';

      _level = existing?.level ?? UserLevel.principiante;
      _minutesCtrl.text = existing?.availableMinutes?.toString() ?? '';

      final startMins = existing?.availableTimeStartMinutes;
      if (startMins != null) {
        _availabilityStart = TimeOfDay(
          hour: startMins ~/ 60,
          minute: startMins % 60,
        );
      }
      final endMins = existing?.availableTimeEndMinutes;
      if (endMins != null) {
        _availabilityEnd = TimeOfDay(hour: endMins ~/ 60, minute: endMins % 60);
      }

      final existingPlace = existing?.usualTrainingPlace;
      _trainingPlace =
          existingPlace != null && _trainingPlaces.contains(existingPlace)
          ? existingPlace
          : null;
      _availableDays
        ..clear()
        ..addAll(existing?.availableDays ?? const []);
      _prefs
        ..clear()
        ..addAll(existing?.preferences ?? const []);

      _injuries
        ..clear()
        ..addAll(existing?.injuries ?? const []);

      _healthConditions
        ..clear()
        ..addAll(existing?.healthConditions ?? const []);
      _workType = existing?.workType;
      _streakPreferences =
          existing?.streakPreferences ?? UserStreakPreferences();

      final notif = existing?.notificationMinutes;
      if (notif != null) {
        _notificationTime = TimeOfDay(hour: notif ~/ 60, minute: notif % 60);
      }
    });
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int _timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _permissionsReviewed;
      case 1:
        return _selected != null && _selected!.trim().isNotEmpty;
      case 2:
        return _streakPreferences.isConfigured;
      case 3:
        final age = int.tryParse(_ageCtrl.text.trim());
        final height = double.tryParse(
          _heightCtrl.text.trim().replaceAll(',', '.'),
        );
        return age != null &&
            age >= 10 &&
            age <= 100 &&
            _sex != null &&
            height != null &&
            height >= 120 &&
            height <= 230;
      case 4:
        final mins = int.tryParse(_minutesCtrl.text.trim());
        if (mins == null || mins < 10 || mins > 240) return false;
        if ((_availabilityStart == null) != (_availabilityEnd == null)) {
          return false;
        }
        if (_availabilityStart != null && _availabilityEnd != null) {
          return _timeToMinutes(_availabilityStart!) <=
              _timeToMinutes(_availabilityEnd!);
        }
        return true;
      case 5:
        if (_trainingPlace == null) return false;
        return _availableDays.isNotEmpty;
      case 6:
        return _workType != null && _healthConditions.isNotEmpty;
      case 7:
        return _notificationTime != null;
      default:
        return false;
    }
  }

  Future<void> _refreshPermissionSnapshot() async {
    final snapshot = await _permissionsService.getSnapshot();
    if (!mounted) return;
    setState(() => _permissionSnapshot = snapshot);
  }

  Future<void> _reviewStartupPermissions() async {
    if (_requestingPermissions) return;
    setState(() => _requestingPermissions = true);

    try {
      final snapshot = await _permissionsService.requestStartupPermissions();
      if (!mounted) return;
      setState(() {
        _permissionSnapshot = snapshot;
        _permissionsReviewed = true;
      });
    } catch (_) {
      unawaited(_permissionsService.markStartupPromptHandled());
      if (!mounted) return;
      setState(() => _permissionsReviewed = true);
    } finally {
      if (mounted) {
        setState(() => _requestingPermissions = false);
      }
    }
  }

  void _markPermissionsReviewed() {
    unawaited(_permissionsService.markStartupPromptHandled());
    if (_permissionsReviewed) return;
    setState(() => _permissionsReviewed = true);
  }

  Future<void> _next() async {
    if (!_canContinue || _saving) return;
    if (_step < _totalSteps - 1) {
      setState(() {
        _isAdvancing = true;
        _step += 1;
      });
      return;
    }
    await _save();
  }

  Future<void> _back() async {
    if (_saving) return;
    if (_step <= 0) return;
    setState(() {
      _isAdvancing = false;
      _step -= 1;
    });
  }

  Future<TimeOfDay?> _show24HourTimePicker({required TimeOfDay initialTime}) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        final data = MediaQuery.of(
          context,
        ).copyWith(alwaysUse24HourFormat: true);
        return MediaQuery(data: data, child: child ?? const SizedBox.shrink());
      },
    );
  }

  Future<void> _pickAvailabilityStart() async {
    final initial = _availabilityStart ?? const TimeOfDay(hour: 7, minute: 0);
    final picked = await _show24HourTimePicker(initialTime: initial);
    if (picked == null) return;
    setState(() => _availabilityStart = picked);
  }

  Future<void> _pickAvailabilityEnd() async {
    final initial = _availabilityEnd ?? const TimeOfDay(hour: 21, minute: 0);
    final picked = await _show24HourTimePicker(initialTime: initial);
    if (picked == null) return;
    setState(() => _availabilityEnd = picked);
  }

  Future<void> _pickNotificationTime() async {
    final initial = _notificationTime ?? const TimeOfDay(hour: 20, minute: 0);
    final picked = await _show24HourTimePicker(initialTime: initial);
    if (picked == null) return;
    setState(() => _notificationTime = picked);
  }

  void _toggleInjury(String value) {
    setState(() {
      if (value == 'Ninguna') {
        if (_injuries.contains('Ninguna')) {
          _injuries.remove('Ninguna');
        } else {
          _injuries
            ..clear()
            ..add('Ninguna');
        }
        return;
      }
      _injuries.remove('Ninguna');
      if (_injuries.contains(value)) {
        _injuries.remove(value);
      } else {
        _injuries.add(value);
      }
    });
  }

  void _toggleHealthCondition(String value) {
    setState(() {
      if (value == 'Ninguna') {
        if (_healthConditions.contains('Ninguna')) {
          _healthConditions.remove('Ninguna');
        } else {
          _healthConditions
            ..clear()
            ..add('Ninguna');
        }
        return;
      }
      _healthConditions.remove('Ninguna');
      if (_healthConditions.contains(value)) {
        _healthConditions.remove(value);
      } else {
        _healthConditions.add(value);
      }
    });
  }

  Future<void> _save() async {
    final goal = _selected?.trim();
    if (goal == null || goal.isEmpty) return;

    final age = int.tryParse(_ageCtrl.text.trim());
    final height = double.tryParse(
      _heightCtrl.text.trim().replaceAll(',', '.'),
    );
    final weight = double.tryParse(
      _weightCtrl.text.trim().replaceAll(',', '.'),
    );
    final mins = int.tryParse(_minutesCtrl.text.trim());

    final start = _availabilityStart;
    final end = _availabilityEnd;
    if ((start == null) != (end == null)) {
      _toast('Completa el rango horario o déjalo vacío.');
      return;
    }
    if (start != null &&
        end != null &&
        _timeToMinutes(start) > _timeToMinutes(end)) {
      _toast('El rango horario no es válido.');
      return;
    }

    final place = _trainingPlace;
    if (place == null) return;
    final notification = _notificationTime;
    if (notification == null) return;

    setState(() => _saving = true);

    final base = _existing;
    final next = (base ?? UserProfile(goal: goal)).copyWith(
      goal: goal,
      onboardingCompleted: true,
      age: age,
      sex: _sex,
      heightCm: height,
      currentWeightKg: weight,
      level: _level,
      availableMinutes: mins,
      availableTimeStartMinutes: start == null ? null : _timeToMinutes(start),
      availableTimeEndMinutes: end == null ? null : _timeToMinutes(end),
      usualTrainingPlace: place,
      availableDays: _availableDays.toList()..sort(),
      preferences: _prefs.toList()..sort(),
      injuries: _injuries.toList()..sort(),
      healthConditions: _healthConditions.contains('Ninguna')
          ? const <String>['Ninguna']
          : (_healthConditions.toList()..sort()),
      workType: _workType,
      notificationMinutes: _timeToMinutes(notification),
      streakPreferences: _streakPreferences,
    );

    await _service.saveProfile(next);
    await _onboardingService.syncProfileToFirestore(next);

    final settings = await _settingsService.getSettings();
    await _settingsService.saveSettings(
      settings.copyWith(notificationMinutes: _timeToMinutes(notification)),
    );
    await TaskReminderService.instance.syncDailyCheckInReminder(
      minutesFromMidnight: _timeToMinutes(notification),
      goal: goal,
    );

    try {
      await PushTokenService().registerCurrentDeviceToken();
    } catch (_) {
      // Best-effort only.
    }

    if (!mounted) return;

    if (widget.isEditing) {
      Navigator.of(context).pop(true);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step + 1) / _totalSteps;
    final backgroundGradient = [context.cfBackground, context.cfSoftSurface];

    return Scaffold(
      appBar: widget.isEditing
          ? AppBar(title: const Text('Ajusta tu perfil'))
          : const PreferredSize(
              preferredSize: Size.fromHeight(0),
              child: SizedBox.shrink(),
            ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: backgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildHeroHeader(context, progress),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildStepViewport(context)),
                const SizedBox(height: 16),
                _buildNavigationCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepViewport(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == ValueKey(_step);
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final begin = isIncoming
              ? Offset(_isAdvancing ? 0.16 : -0.16, 0)
              : Offset.zero;
          final end = isIncoming
              ? Offset.zero
              : Offset(_isAdvancing ? -0.10 : 0.10, 0);

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: begin, end: end).animate(curved),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: _buildCurrentStep(context),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _stepPermissions(context);
      case 1:
        return _stepGoal(context);
      case 2:
        return _stepPersonalizedStreak(context);
      case 3:
        return _stepPersonal(context);
      case 4:
        return _stepLevelAndTime(context);
      case 5:
        return _stepAvailability(context);
      case 6:
        return _stepInjuriesAndWork(context);
      case 7:
        return _stepNotifications(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHeroHeader(BuildContext context, double progress) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_step),
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, child) {
        final theme = Theme.of(context);
        final nextLabel = _step < _totalSteps - 1
            ? _stepInfos[_step + 1].eyebrow
            : 'Guardar perfil';

        return ProgressSectionCard(
          padding: const EdgeInsets.all(20),
          backgroundColor: context.cfPrimaryTint,
          borderColor: context.cfPrimaryTintStrong,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.cfPrimaryTint,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(999),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_stepInfo.icon, size: 16, color: context.cfPrimary),
                        const SizedBox(width: 8),
                        Text(
                          '${_stepInfo.eyebrow} · Paso ${_step + 1}/$_totalSteps',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.cfPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(animatedProgress * 100).round()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: context.cfTextSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.isEditing
                    ? 'Refina tu configuración'
                    : 'Tu plan empieza aquí',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _stepInfo.title,
                style: theme.textTheme.headlineMedium?.copyWith(height: 1.05),
              ),
              const SizedBox(height: 8),
              Text(
                _stepInfo.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(999)),
                child: LinearProgressIndicator(
                  value: animatedProgress,
                  minHeight: 8,
                  backgroundColor: context.cfPrimaryTint,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.cfPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < _totalSteps; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? context.cfPrimary
                              : context.cfPrimaryTint,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    if (i != _totalSteps - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _step == _totalSteps - 1
                    ? 'Último paso. Lo demás podrás retocarlo luego desde Perfil.'
                    : 'Siguiente bloque: $nextLabel.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.cfTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavigationCard(BuildContext context) {
    final theme = Theme.of(context);
    return ProgressSectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              _canContinue
                  ? (_step == _totalSteps - 1
                        ? 'Todo listo para crear tu perfil.'
                        : 'Ya puedes seguir cuando quieras.')
                  : 'Completa esta parte para continuar.',
              key: ValueKey('$_step-$_canContinue'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _canContinue ? context.cfPrimary : context.cfTextSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_step == 0 || _saving) ? null : _back,
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: (_canContinue && !_saving) ? _next : null,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _step == _totalSteps - 1 ? 'Finalizar' : 'Continuar',
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _stepPermissions(BuildContext context) {
    final snapshot = _permissionSnapshot;

    return ListView(
      children: [
        _sectionTitle(
          context,
          'Permisos y acceso',
          'Antes de arrancar, te dejamos claro qué puede pedir la app y para qué se usa cada acceso.',
        ),
        ProgressSectionCard(
          backgroundColor: context.cfPrimaryTint,
          borderColor: context.cfPrimaryTintStrong,
          child: Text(
            'CotidyFit solo usa permisos para funciones concretas: recordatorios, ubicación en Inicio y pasos si quieres sincronizarlos dentro de la app. Nada más.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.cfTextPrimary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _permissionCard(
          context,
          title: 'Notificaciones',
          subtitle:
              'Para avisarte de tus recordatorios y ayudarte a mantener la rutina.',
          icon: Icons.notifications_active_outlined,
          status: snapshot?.notifications ?? AppPermissionStatus.unavailable,
        ),
        const SizedBox(height: 12),
        _permissionCard(
          context,
          title: 'Ubicación',
          subtitle:
              'Para mostrar ciudad, clima y hora local en la pantalla de inicio.',
          icon: Icons.location_on_outlined,
          status: snapshot?.location ?? AppPermissionStatus.unavailable,
        ),
        const SizedBox(height: 12),
        _permissionCard(
          context,
          title: 'Pasos y salud',
          subtitle:
            'Se revisa junto con notificaciones y ubicación cuando aceptas este paso. Después podrás volver a gestionarlo desde la sección de pasos.',
          icon: Icons.monitor_heart_outlined,
          status: snapshot?.steps ?? AppPermissionStatus.unavailable,
        ),
        const SizedBox(height: 12),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _requestingPermissions
                      ? null
                      : _reviewStartupPermissions,
                  icon: _requestingPermissions
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  label: Text(
                    _requestingPermissions
                        ? 'Revisando permisos…'
                        : 'Aceptar y revisar ahora',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _requestingPermissions
                      ? null
                      : _markPermissionsReviewed,
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Lo revisaré más tarde'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kIsWeb
                    ? 'En web y escritorio no se muestran los permisos móviles. El flujo real salta en Android y iPhone.'
                    : 'Podrás cambiar estos permisos más tarde desde los ajustes del móvil.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepGoal(BuildContext context) {
    return ListView(
      children: [
        _sectionTitle(
          context,
          'Objetivo principal',
          'Empieza con una sola dirección clara. Después ya afinaremos detalles.',
        ),
        for (final goal in _goals) ...[
          _OnboardingOptionCard(
            title: goal,
            subtitle: _goalMeta(goal).subtitle,
            icon: _goalMeta(goal).icon,
            accent: _goalMeta(goal).accent,
            selected: _selected == goal,
            onTap: _saving ? null : () => setState(() => _selected = goal),
          ),
          if (goal != _goals.last) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _stepPersonalizedStreak(BuildContext context) {
    return ListView(
      children: [
        _sectionTitle(
          context,
          'Tu tipo de racha',
          'Haz que la constancia cuente de una forma que encaje contigo de verdad.',
        ),
        ProgressSectionCard(
          backgroundColor: context.cfSurface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.cfPrimaryTint,
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                ),
                child: Icon(
                  Icons.whatshot_rounded,
                  color: context.cfPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Esta elección afecta a tu Home, tu progreso y tus logros. Merece la pena dejarla bien puesta desde el inicio.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.cfTextPrimary,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ProgressSectionCard(
          padding: const EdgeInsets.all(16),
          child: StreakPreferencesEditor(
            value: _streakPreferences,
            enabled: !_saving,
            title: 'Qué quieres seguir',
            subtitle: 'Puedes ir a un foco simple o montar un mix personal.',
            onChanged: (value) => setState(() => _streakPreferences = value),
          ),
        ),
      ],
    );
  }

  Widget _stepPersonal(BuildContext context) {
    return ListView(
      children: [
        _sectionTitle(
          context,
          'Datos básicos',
          'Solo lo justo para que la app no te recomiende como si fueras otra persona.',
        ),
        ProgressSectionCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration(
                        'Edad',
                        hintText: 'Ej. 28',
                        suffixText: 'años',
                        icon: Icons.cake_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration(
                        'Altura',
                        hintText: 'Ej. 175',
                        suffixText: 'cm',
                        icon: Icons.height_rounded,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _fieldDecoration(
                  'Peso actual',
                  hintText: 'Opcional',
                  suffixText: 'kg',
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sexo',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final sex in UserSex.values)
                    _OnboardingOptionCard.compact(
                      title: sex.label,
                      subtitle: sex == UserSex.otro
                          ? 'Ajuste neutro y flexible'
                          : 'Adaptación inicial del plan',
                      icon: switch (sex) {
                        UserSex.hombre => Icons.male_rounded,
                        UserSex.mujer => Icons.female_rounded,
                        UserSex.otro => Icons.diversity_3_rounded,
                      },
                      accent: CFColors.primary,
                      selected: _sex == sex,
                      onTap: _saving ? null : () => setState(() => _sex = sex),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepLevelAndTime(BuildContext context) {
    final start = _availabilityStart;
    final end = _availabilityEnd;

    return ListView(
      children: [
        _sectionTitle(
          context,
          'Deporte y tiempo',
          'Vamos a ajustar la intensidad y el tamaño del plan a tu realidad.',
        ),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nivel deportivo',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (final level in UserLevel.values) ...[
                _OnboardingOptionCard.compact(
                  title: level.label,
                  subtitle: _levelMeta(level).subtitle,
                  icon: _levelMeta(level).icon,
                  accent: _levelMeta(level).accent,
                  selected: _level == level,
                  onTap: _saving ? null : () => setState(() => _level = level),
                ),
                if (level != UserLevel.values.last) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tiempo disponible por día',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _minutesCtrl,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration(
                  'Minutos',
                  hintText: 'Entre 10 y 240',
                  suffixText: 'min',
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in _quickMinutes)
                    _quickChip(
                      context,
                      label: '$value min',
                      selected: _minutesCtrl.text.trim() == '$value',
                      onTap: _saving
                          ? null
                          : () => setState(() => _minutesCtrl.text = '$value'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rango horario',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (start != null || end != null)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _availabilityStart = null;
                              _availabilityEnd = null;
                            }),
                      child: const Text('Quitar rango'),
                    ),
                ],
              ),
              Text(
                'Opcional. Úsalo si prefieres que la app te proponga entrenos dentro de una franja concreta.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _timeSelectorCard(
                      context,
                      label: 'Desde',
                      value: start == null
                          ? 'Sin definir'
                          : _formatTime24(start),
                      onTap: _saving ? null : _pickAvailabilityStart,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _timeSelectorCard(
                      context,
                      label: 'Hasta',
                      value: end == null ? 'Sin definir' : _formatTime24(end),
                      onTap: _saving ? null : _pickAvailabilityEnd,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepAvailability(BuildContext context) {
    return ListView(
      children: [
        _sectionTitle(
          context,
          'Preferencias',
          'Cuéntanos dónde, cuándo y qué te apetece entrenar para que todo resulte más natural.',
        ),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lugar habitual',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (final place in _trainingPlaces) ...[
                _OnboardingOptionCard.compact(
                  title: place,
                  subtitle: _placeMeta(place).subtitle,
                  icon: _placeMeta(place).icon,
                  accent: _placeMeta(place).accent,
                  selected: _trainingPlace == place,
                  onTap: _saving
                      ? null
                      : () => setState(() => _trainingPlace = place),
                ),
                if (place != _trainingPlaces.last) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Días disponibles',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final d in const <int>[1, 2, 3, 4, 5, 6, 7])
                    _quickChip(
                      context,
                      label: _dayLabel(d),
                      selected: _availableDays.contains(d),
                      onTap: _saving
                          ? null
                          : () {
                              setState(() {
                                if (_availableDays.contains(d)) {
                                  _availableDays.remove(d);
                                } else {
                                  _availableDays.add(d);
                                }
                              });
                            },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estilos que te gustan',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preference in _sportPreferences)
                    _quickChip(
                      context,
                      label: preference,
                      selected: _prefs.contains(preference),
                      onTap: _saving
                          ? null
                          : () {
                              setState(() {
                                if (_prefs.contains(preference)) {
                                  _prefs.remove(preference);
                                } else {
                                  _prefs.add(preference);
                                }
                              });
                            },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepInjuriesAndWork(BuildContext context) {
    return ListView(
      children: [
        _sectionTitle(
          context,
          'Contexto',
          'Una foto rápida de tu situación diaria para que el plan no vaya por libre.',
        ),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tipo de trabajo',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (final workType in WorkType.values) ...[
                _OnboardingOptionCard.compact(
                  title: workType.label,
                  subtitle: _workTypeMeta(workType).subtitle,
                  icon: _workTypeMeta(workType).icon,
                  accent: _workTypeMeta(workType).accent,
                  selected: _workType == workType,
                  onTap: _saving
                      ? null
                      : () => setState(() => _workType = workType),
                ),
                if (workType != WorkType.values.last)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Condiciones médicas',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final value in _healthConditionOptions)
                    _quickChip(
                      context,
                      label: value,
                      selected: _healthConditions.contains(value),
                      onTap: _saving
                          ? null
                          : () => _toggleHealthCondition(value),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Aviso: la app no sustituye asesoramiento médico profesional.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.cfTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ProgressSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lesiones comunes',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final value in _injuryOptions)
                    _quickChip(
                      context,
                      label: value,
                      selected: _injuries.contains(value),
                      onTap: _saving ? null : () => _toggleInjury(value),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepNotifications(BuildContext context) {
    final t = _notificationTime;

    return ListView(
      children: [
        _sectionTitle(
          context,
          'Notificaciones',
          'Elige una hora amable para que la app te recuerde volver sin hacerse pesada.',
        ),
        ProgressSectionCard(
          backgroundColor: context.cfPrimary.withValues(
            alpha: context.cfIsDark ? 0.18 : 0.06,
          ),
          borderColor: context.cfPrimary.withValues(
            alpha: context.cfIsDark ? 0.30 : 0.16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.cfPrimary.withValues(
                        alpha: context.cfIsDark ? 0.26 : 0.12,
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: context.cfPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hora elegida',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t == null ? 'Aún sin seleccionar' : _formatTime24(t),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in _quickNotificationMinutes)
                    _quickChip(
                      context,
                      label: _formatMinutes(minutes),
                      selected:
                          _notificationTime != null &&
                          _timeToMinutes(_notificationTime!) == minutes,
                      onTap: _saving
                          ? null
                          : () => setState(
                              () => _notificationTime = TimeOfDay(
                                hour: minutes ~/ 60,
                                minute: minutes % 60,
                              ),
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _pickNotificationTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(t == null ? 'Elegir otra hora' : 'Cambiar hora'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Podrás cambiarlo después en Configuración cuando quieras.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(
    String label, {
    String? hintText,
    String? suffixText,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixText: suffixText,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: context.cfSoftSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: context.cfBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: context.cfBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: context.cfPrimary, width: 1.4),
      ),
    );
  }

  Widget _quickChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return ChoiceChip(
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap(),
      label: Text(label),
      backgroundColor: context.cfSoftSurface,
      selectedColor: context.cfPrimaryTint,
      side: BorderSide(color: selected ? context.cfPrimary : context.cfBorder),
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: selected ? context.cfPrimary : context.cfTextSecondary,
      ),
    );
  }

  Widget _timeSelectorCard(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cfSoftSurface,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          border: Border.all(color: context.cfBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: context.cfTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required AppPermissionStatus status,
    String? statusLabel,
  }) {
    final resolvedLabel = statusLabel ?? _permissionStatusLabel(status);
    final resolvedColor = _permissionStatusColor(status);

    return ProgressSectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: resolvedColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Icon(icon, color: resolvedColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: resolvedColor.withValues(alpha: 0.10),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(999),
                        ),
                      ),
                      child: Text(
                        resolvedLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: resolvedColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.cfTextSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _permissionStatusLabel(AppPermissionStatus status) {
    switch (status) {
      case AppPermissionStatus.granted:
        return 'Concedido';
      case AppPermissionStatus.notRequested:
        return 'Pendiente';
      case AppPermissionStatus.denied:
        return 'Denegado';
      case AppPermissionStatus.unavailable:
        return 'Solo móvil';
    }
  }

  Color _permissionStatusColor(AppPermissionStatus status) {
    switch (status) {
      case AppPermissionStatus.granted:
        return const Color(0xFF2B7D5A);
      case AppPermissionStatus.notRequested:
        return const Color(0xFF8C6C1F);
      case AppPermissionStatus.denied:
        return const Color(0xFFC44B2C);
      case AppPermissionStatus.unavailable:
        return CFColors.primary;
    }
  }

  _OnboardingOptionMeta _goalMeta(String goal) {
    switch (goal) {
      case 'Perder grasa':
        return const _OnboardingOptionMeta(
          subtitle: 'Prioriza déficit controlado, movimiento y constancia.',
          icon: Icons.trending_down_rounded,
          accent: Color(0xFF2A6F5B),
        );
      case 'Ganar masa muscular':
        return const _OnboardingOptionMeta(
          subtitle: 'Más foco en fuerza, recuperación y progresión.',
          icon: Icons.fitness_center_rounded,
          accent: Color(0xFF8A552A),
        );
      case 'Mantener peso':
        return const _OnboardingOptionMeta(
          subtitle: 'Equilibrio, energía estable y adherencia sostenible.',
          icon: Icons.balance_rounded,
          accent: Color(0xFF4760A8),
        );
      case 'Mejorar hábitos':
        return const _OnboardingOptionMeta(
          subtitle: 'Construye una base sencilla y repetible cada semana.',
          icon: Icons.auto_awesome_rounded,
          accent: Color(0xFF7A4A8E),
        );
      default:
        return const _OnboardingOptionMeta(
          subtitle: 'Ajustaremos el plan a este objetivo.',
          icon: Icons.flag_rounded,
          accent: CFColors.primary,
        );
    }
  }

  _OnboardingOptionMeta _levelMeta(UserLevel level) {
    switch (level) {
      case UserLevel.principiante:
        return const _OnboardingOptionMeta(
          subtitle:
              'Buscamos claridad, confianza y una carga fácil de sostener.',
          icon: Icons.terrain_rounded,
          accent: Color(0xFF2B6C8F),
        );
      case UserLevel.intermedio:
        return const _OnboardingOptionMeta(
          subtitle:
              'Ya hay base. Podemos subir variedad y exigencia con control.',
          icon: Icons.show_chart_rounded,
          accent: Color(0xFF8B6A24),
        );
      case UserLevel.avanzado:
        return const _OnboardingOptionMeta(
          subtitle: 'Más intensidad, mejor ajuste y objetivos con más filo.',
          icon: Icons.rocket_launch_rounded,
          accent: Color(0xFF7C3F2E),
        );
    }
  }

  _OnboardingOptionMeta _placeMeta(String place) {
    switch (place) {
      case 'En casa':
        return const _OnboardingOptionMeta(
          subtitle: 'Sesiones prácticas, sin depender de desplazarte.',
          icon: Icons.home_rounded,
          accent: Color(0xFF385C8C),
        );
      case 'Al aire libre':
        return const _OnboardingOptionMeta(
          subtitle: 'Entrenos más abiertos, caminatas y actividad exterior.',
          icon: Icons.park_rounded,
          accent: Color(0xFF2F7A62),
        );
      case 'Gimnasio':
        return const _OnboardingOptionMeta(
          subtitle:
              'Podemos aprovechar máquinas, cargas y progresiones más precisas.',
          icon: Icons.apartment_rounded,
          accent: Color(0xFF8E5C2F),
        );
      case 'Parque de calistenia':
        return const _OnboardingOptionMeta(
          subtitle: 'Ideal para trabajo con peso corporal y rutinas dinámicas.',
          icon: Icons.sports_gymnastics_rounded,
          accent: Color(0xFF6D4AA0),
        );
      case 'Mixto':
        return const _OnboardingOptionMeta(
          subtitle:
              'Te dejamos más margen para combinar contextos y no encasillarte.',
          icon: Icons.shuffle_rounded,
          accent: Color(0xFF49677B),
        );
      default:
        return const _OnboardingOptionMeta(
          subtitle: 'Ajustaremos el plan a este entorno.',
          icon: Icons.place_rounded,
          accent: CFColors.primary,
        );
    }
  }

  _OnboardingOptionMeta _workTypeMeta(WorkType workType) {
    switch (workType) {
      case WorkType.oficina:
        return const _OnboardingOptionMeta(
          subtitle:
              'Compensaremos sedentarismo y rigidez con movimiento inteligente.',
          icon: Icons.desktop_windows_rounded,
          accent: Color(0xFF335F8A),
        );
      case WorkType.fisico:
        return const _OnboardingOptionMeta(
          subtitle: 'Tendremos en cuenta la fatiga física del día a día.',
          icon: Icons.construction_rounded,
          accent: Color(0xFF8A5E22),
        );
      case WorkType.estudiante:
        return const _OnboardingOptionMeta(
          subtitle:
              'Más flexibilidad para horarios cambiantes y semanas desordenadas.',
          icon: Icons.school_rounded,
          accent: Color(0xFF5F53A6),
        );
      case WorkType.desempleado:
        return const _OnboardingOptionMeta(
          subtitle: 'Podemos construir una rutina con más libertad de horas.',
          icon: Icons.self_improvement_rounded,
          accent: Color(0xFF3A7566),
        );
      case WorkType.mixto:
        return const _OnboardingOptionMeta(
          subtitle: 'Buscamos equilibrio para semanas menos previsibles.',
          icon: Icons.sync_alt_rounded,
          accent: Color(0xFF546A79),
        );
    }
  }

  String _dayLabel(int day) {
    return switch (day) {
      1 => 'Lunes',
      2 => 'Martes',
      3 => 'Miércoles',
      4 => 'Jueves',
      5 => 'Viernes',
      6 => 'Sábado',
      _ => 'Domingo',
    };
  }

  String _formatTime24(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatMinutes(int minutes) {
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return _formatTime24(time);
  }
}

class _OnboardingStepInfo {
  const _OnboardingStepInfo({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
}

class _OnboardingOptionMeta {
  const _OnboardingOptionMeta({
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String subtitle;
  final IconData icon;
  final Color accent;
}

class _OnboardingOptionCard extends StatelessWidget {
  const _OnboardingOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  }) : compact = false;

  const _OnboardingOptionCard.compact({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  }) : compact = true;

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 14)
        : const EdgeInsets.all(16);

    return AnimatedScale(
      scale: selected ? 1 : 0.985,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: padding,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.10) : context.cfSurface,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            border: Border.all(
              color: selected ? accent : context.cfBorder,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: context.cfShadow.withValues(alpha: selected ? 0.26 : 0.14),
                blurRadius: selected ? 20 : 14,
                offset: Offset(0, selected ? 10 : 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: compact ? 44 : 52,
                height: compact ? 44 : 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.18 : 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.3,
                        color: context.cfTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  key: ValueKey(selected),
                  color: selected ? accent : context.cfTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
