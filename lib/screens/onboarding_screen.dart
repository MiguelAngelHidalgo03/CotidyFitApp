import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/user_profile.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../services/settings_service.dart';
import 'main_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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
  final _pageCtrl = PageController();

  UserProfile? _existing;

  int _step = 0;
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

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
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
        _availabilityStart = TimeOfDay(hour: startMins ~/ 60, minute: startMins % 60);
      }
      final endMins = existing?.availableTimeEndMinutes;
      if (endMins != null) {
        _availabilityEnd = TimeOfDay(hour: endMins ~/ 60, minute: endMins % 60);
      }

      final existingPlace = existing?.usualTrainingPlace;
      _trainingPlace = existingPlace != null && _trainingPlaces.contains(existingPlace) ? existingPlace : null;
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

      final notif = existing?.notificationMinutes;
      if (notif != null) {
        _notificationTime = TimeOfDay(hour: notif ~/ 60, minute: notif % 60);
      }
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
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
        return _selected != null && _selected!.trim().isNotEmpty;
      case 1:
        final age = int.tryParse(_ageCtrl.text.trim());
        final height = double.tryParse(_heightCtrl.text.trim().replaceAll(',', '.'));
        return age != null && age >= 10 && age <= 100 && _sex != null && height != null && height >= 120 && height <= 230;
      case 2:
        final mins = int.tryParse(_minutesCtrl.text.trim());
        if (mins == null || mins < 10 || mins > 240) return false;
        if ((_availabilityStart == null) != (_availabilityEnd == null)) return false;
        if (_availabilityStart != null && _availabilityEnd != null) {
          return _timeToMinutes(_availabilityStart!) <= _timeToMinutes(_availabilityEnd!);
        }
        return true;
      case 3:
        if (_trainingPlace == null) return false;
        return _availableDays.isNotEmpty;
      case 4:
        return _workType != null && _healthConditions.isNotEmpty;
      case 5:
        return _notificationTime != null;
      default:
        return false;
    }
  }

  Future<void> _next() async {
    if (!_canContinue || _saving) return;
    if (_step < 5) {
      setState(() => _step += 1);
      await _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
      return;
    }
    await _save();
  }

  Future<void> _back() async {
    if (_saving) return;
    if (_step <= 0) return;
    setState(() => _step -= 1);
    await _pageCtrl.animateToPage(
      _step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickAvailabilityStart() async {
    final initial = _availabilityStart ?? const TimeOfDay(hour: 7, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() => _availabilityStart = picked);
  }

  Future<void> _pickAvailabilityEnd() async {
    final initial = _availabilityEnd ?? const TimeOfDay(hour: 21, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() => _availabilityEnd = picked);
  }

  Future<void> _pickNotificationTime() async {
    final initial = _notificationTime ?? const TimeOfDay(hour: 20, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
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
    final height = double.tryParse(_heightCtrl.text.trim().replaceAll(',', '.'));
    final weight = double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.'));
    final mins = int.tryParse(_minutesCtrl.text.trim());

    final start = _availabilityStart;
    final end = _availabilityEnd;
    if ((start == null) != (end == null)) {
      _toast('Completa el rango horario o déjalo vacío.');
      return;
    }
    if (start != null && end != null && _timeToMinutes(start) > _timeToMinutes(end)) {
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
    );

    await _service.saveProfile(next);
    await _onboardingService.syncProfileToFirestore(next);

    final settings = await _settingsService.getSettings();
    await _settingsService.saveSettings(
      settings.copyWith(notificationMinutes: _timeToMinutes(notification)),
    );

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
    return Scaffold(
      appBar: widget.isEditing ? AppBar(title: const Text('Onboarding')) : const PreferredSize(preferredSize: Size.fromHeight(0), child: SizedBox.shrink()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isEditing) ...[
                Text('Bienvenido', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
              ],
              Text(
                'Tu plan empieza aquí',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Paso ${_step + 1} de 6',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepGoal(context),
                    _stepPersonal(context),
                    _stepLevelAndTime(context),
                    _stepAvailability(context),
                    _stepInjuriesAndWork(context),
                    _stepNotifications(context),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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
                          : Text(_step == 5 ? 'Finalizar' : 'Continuar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _stepGoal(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Objetivo principal', 'Elige lo más importante para ti ahora.'),
        Expanded(
          child: ListView.separated(
            itemCount: _goals.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final goal = _goals[index];
              final selected = _selected == goal;
              return Card(
                child: InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  onTap: _saving ? null : () => setState(() => _selected = goal),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: selected ? CFColors.primary : CFColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            goal,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _stepPersonal(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Datos básicos', 'Ajusta la experiencia a tu situación actual.'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Edad'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<UserSex>(
                    initialValue: _sex,
                    decoration: const InputDecoration(labelText: 'Sexo'),
                    items: [
                      for (final v in UserSex.values)
                        DropdownMenuItem(value: v, child: Text(v.label)),
                    ],
                    onChanged: _saving ? null : (v) => setState(() => _sex = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Altura (cm)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Peso actual (kg) (opcional)'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLevelAndTime(BuildContext context) {
    final start = _availabilityStart;
    final end = _availabilityEnd;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Deporte y tiempo', 'Así adaptamos los entrenos a tu agenda.'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DropdownButtonFormField<UserLevel>(
                    initialValue: _level,
                    decoration: const InputDecoration(labelText: 'Nivel deportivo'),
                    items: [
                      for (final v in UserLevel.values)
                        DropdownMenuItem(value: v, child: Text(v.label)),
                    ],
                    onChanged: _saving ? null : (v) => setState(() => _level = v ?? _level),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _minutesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Tiempo disponible (min/día)'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Rango horario (opcional)',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _pickAvailabilityStart,
                          icon: const Icon(Icons.schedule),
                          label: Text(start == null ? 'Desde' : start.format(context)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _pickAvailabilityEnd,
                          icon: const Icon(Icons.schedule),
                          label: Text(end == null ? 'Hasta' : end.format(context)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepAvailability(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Preferencias', 'Selecciona cómo te gusta entrenar.'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lugar habitual de entrenamiento',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final p in _trainingPlaces)
                        ChoiceChip(
                          selected: _trainingPlace == p,
                          onSelected: _saving ? null : (_) => setState(() => _trainingPlace = p),
                          label: Text(p),
                          selectedColor: CFColors.primary.withValues(alpha: 0.12),
                          side: BorderSide(color: _trainingPlace == p ? CFColors.primary : CFColors.softGray),
                          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _trainingPlace == p ? CFColors.primary : CFColors.textSecondary,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Días disponibles', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final d in const <int>[1, 2, 3, 4, 5, 6, 7])
                        ChoiceChip(
                          selected: _availableDays.contains(d),
                          onSelected: _saving
                              ? null
                              : (_) {
                                  setState(() {
                                    if (_availableDays.contains(d)) {
                                      _availableDays.remove(d);
                                    } else {
                                      _availableDays.add(d);
                                    }
                                  });
                                },
                          label: Text(switch (d) {
                            1 => 'L',
                            2 => 'M',
                            3 => 'X',
                            4 => 'J',
                            5 => 'V',
                            6 => 'S',
                            _ => 'D',
                          }),
                          selectedColor: CFColors.primary.withValues(alpha: 0.12),
                          side: BorderSide(color: _availableDays.contains(d) ? CFColors.primary : CFColors.softGray),
                          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _availableDays.contains(d) ? CFColors.primary : CFColors.textSecondary,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Preferencias deportivas', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final p in _sportPreferences)
                        ChoiceChip(
                          selected: _prefs.contains(p),
                          onSelected: _saving
                              ? null
                              : (_) {
                                  setState(() {
                                    if (_prefs.contains(p)) {
                                      _prefs.remove(p);
                                    } else {
                                      _prefs.add(p);
                                    }
                                  });
                                },
                          label: Text(p),
                          selectedColor: CFColors.primary.withValues(alpha: 0.12),
                          side: BorderSide(color: _prefs.contains(p) ? CFColors.primary : CFColors.softGray),
                          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _prefs.contains(p) ? CFColors.primary : CFColors.textSecondary,
                              ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepInjuriesAndWork(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, 'Contexto', 'Una foto rápida de tu día a día.'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lesiones comunes', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final v in _injuryOptions)
                        ChoiceChip(
                          selected: _injuries.contains(v),
                          onSelected: _saving ? null : (_) => _toggleInjury(v),
                          label: Text(v),
                          selectedColor: CFColors.primary.withValues(alpha: 0.12),
                          side: BorderSide(color: _injuries.contains(v) ? CFColors.primary : CFColors.softGray),
                          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _injuries.contains(v) ? CFColors.primary : CFColors.textSecondary,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('¿Tienes alguna condición médica?', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final v in _healthConditionOptions)
                        ChoiceChip(
                          selected: _healthConditions.contains(v),
                          onSelected: _saving ? null : (_) => _toggleHealthCondition(v),
                          label: Text(v),
                          selectedColor: CFColors.primary.withValues(alpha: 0.12),
                          side: BorderSide(color: _healthConditions.contains(v) ? CFColors.primary : CFColors.softGray),
                          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _healthConditions.contains(v) ? CFColors.primary : CFColors.textSecondary,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aviso: La app no sustituye asesoramiento médico profesional.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CFColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<WorkType>(
                    initialValue: _workType,
                    decoration: const InputDecoration(labelText: 'Tipo de trabajo'),
                    items: [
                      for (final v in WorkType.values)
                        DropdownMenuItem(value: v, child: Text(v.label)),
                    ],
                    onChanged: _saving ? null : (v) => setState(() => _workType = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepNotifications(BuildContext context) {
    final t = _notificationTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Notificaciones', 'Elige una hora para recordatorios.'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickNotificationTime,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(t == null ? 'Seleccionar hora' : t.format(context)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Podrás cambiarlo después en Configuración.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
