import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/personal_test.dart';
import '../models/user_profile.dart';
import '../models/user_settings.dart';
import '../services/local_storage_service.dart';
import '../services/personal_test_service.dart';
import '../services/profile_service.dart';
import '../services/settings_service.dart';
import '../utils/date_utils.dart';
import '../widgets/profile/profile_action_tile.dart';
import '../widgets/profile/profile_header_card.dart';
import '../widgets/progress/progress_section_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _testService = PersonalTestService();
  final _settingsService = SettingsService();
  final _storage = LocalStorageService();

  UserProfile? _profile;
  PersonalTest? _test;
  UserSettings? _settings;
  Map<String, int> _cfHistory = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await _profileService.getOrCreateProfile();
    final test = await _testService.getTest();
    final settings = await _settingsService.getSettings();
    final history = await _storage.getCfHistory();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _test = test;
      _settings = settings;
      _cfHistory = history;
      _loading = false;
    });
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

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editAvatar() async {
    final profile = _profile;
    if (profile == null) return;

    final picked = await showModalBottomSheet<AvatarSpec>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var icon = profile.avatar.icon;
        var colorIndex = profile.avatar.colorIndex;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return ProgressSectionCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Editar avatar',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Icono', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final v in AvatarIcon.values)
                            ChoiceChip(
                              selected: v == icon,
                              onSelected: (_) => setSheetState(() => icon = v),
                              label: Text(v.name),
                              selectedColor: CFColors.primary.withValues(alpha: 0.12),
                              side: BorderSide(color: v == icon ? CFColors.primary : CFColors.softGray),
                              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: v == icon ? CFColors.primary : CFColors.textSecondary,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Color', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final i in List<int>.generate(4, (x) => x)) ...[
                            InkWell(
                              onTap: () => setSheetState(() => colorIndex = i),
                              borderRadius: const BorderRadius.all(Radius.circular(14)),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: [
                                    CFColors.primary.withValues(alpha: 0.12),
                                    CFColors.primary.withValues(alpha: 0.18),
                                    CFColors.primaryLight.withValues(alpha: 0.28),
                                    CFColors.softGray,
                                  ][i],
                                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                                  border: Border.all(color: colorIndex == i ? CFColors.primary : CFColors.softGray, width: 2),
                                ),
                              ),
                            ),
                            if (i != 3) const SizedBox(width: 10),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(AvatarSpec(icon: icon, colorIndex: colorIndex)),
                          child: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (picked == null) return;
    final next = profile.copyWith(avatar: picked);
    await _profileService.saveProfile(next);
    if (!mounted) return;
    setState(() => _profile = next);
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;

    final nameCtrl = TextEditingController(text: profile.name);
    final ageCtrl = TextEditingController(text: profile.age?.toString() ?? '');
    final heightCtrl = TextEditingController(text: profile.heightCm?.toStringAsFixed(0) ?? '');
    final weightCtrl = TextEditingController(text: profile.currentWeightKg?.toStringAsFixed(1) ?? '');
    final minutesCtrl = TextEditingController(text: profile.availableMinutes?.toString() ?? '');
    final placeCtrl = TextEditingController(text: profile.usualTrainingPlace ?? '');
    final goalCtrl = TextEditingController(text: profile.goal);
    var level = profile.level;

    final result = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Editar perfil',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                    const SizedBox(height: 10),
                    TextField(controller: ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Edad')),
                    const SizedBox(height: 10),
                    TextField(controller: heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Altura (cm)')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Peso actual (kg)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: goalCtrl,
                      decoration: const InputDecoration(labelText: 'Objetivo'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserLevel>(
                      initialValue: level,
                      items: [for (final v in UserLevel.values) DropdownMenuItem(value: v, child: Text(v.label))],
                      onChanged: (v) => level = v ?? level,
                      decoration: const InputDecoration(labelText: 'Nivel'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: minutesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tiempo disponible (min/día)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: placeCtrl,
                      decoration: const InputDecoration(labelText: 'Lugar habitual de entrenamiento'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          final age = int.tryParse(ageCtrl.text.trim());
                          final height = double.tryParse(heightCtrl.text.trim().replaceAll(',', '.'));
                          final weight = double.tryParse(weightCtrl.text.trim().replaceAll(',', '.'));
                          final mins = int.tryParse(minutesCtrl.text.trim());

                          final next = profile.copyWith(
                            name: nameCtrl.text.trim().isEmpty ? profile.name : nameCtrl.text.trim(),
                            goal: goalCtrl.text.trim().isEmpty ? profile.goal : goalCtrl.text.trim(),
                            level: level,
                            age: age,
                            heightCm: height,
                            currentWeightKg: weight,
                            availableMinutes: mins,
                            usualTrainingPlace: placeCtrl.text.trim().isEmpty ? null : placeCtrl.text.trim(),
                          );
                          Navigator.of(context).pop(next);
                        },
                        child: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;
    await _profileService.saveProfile(result);
    if (!mounted) return;
    setState(() => _profile = result);
  }

  Future<void> _editPersonalTest() async {
    final current = _test;
    if (current == null) return;

    var pg = current.primaryGoal;
    var days = current.daysPerWeek;
    var minutes = current.availableMinutes;
    var pref = current.preference;
    final injuriesCtrl = TextEditingController(text: current.injuries);
    final placeCtrl = TextEditingController(text: current.usualTrainingPlace);

    final result = await showModalBottomSheet<PersonalTest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Test personal',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PrimaryGoal>(
                      initialValue: pg,
                      items: [for (final v in PrimaryGoal.values) DropdownMenuItem(value: v, child: Text(v.label))],
                      onChanged: (v) => pg = v ?? pg,
                      decoration: const InputDecoration(labelText: 'Objetivo principal'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: days,
                      items: [for (var i = 1; i <= 7; i++) DropdownMenuItem(value: i, child: Text('$i días/sem'))],
                      onChanged: (v) => days = v ?? days,
                      decoration: const InputDecoration(labelText: 'Días por semana'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: minutes,
                      items: [for (final v in [10, 15, 20, 30, 45, 60]) DropdownMenuItem(value: v, child: Text('$v min'))],
                      onChanged: (v) => minutes = v ?? minutes,
                      decoration: const InputDecoration(labelText: 'Tiempo disponible'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<CardioStrengthPreference>(
                      initialValue: pref,
                      items: [for (final v in CardioStrengthPreference.values) DropdownMenuItem(value: v, child: Text(v.label))],
                      onChanged: (v) => pref = v ?? pref,
                      decoration: const InputDecoration(labelText: 'Preferencia cardio/fuerza'),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: injuriesCtrl, decoration: const InputDecoration(labelText: 'Lesiones (opcional)')),
                    const SizedBox(height: 10),
                    TextField(controller: placeCtrl, decoration: const InputDecoration(labelText: 'Lugar habitual')),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            current.copyWith(
                              primaryGoal: pg,
                              daysPerWeek: days,
                              availableMinutes: minutes,
                              preference: pref,
                              injuries: injuriesCtrl.text.trim(),
                              usualTrainingPlace: placeCtrl.text.trim().isEmpty ? current.usualTrainingPlace : placeCtrl.text.trim(),
                            ),
                          );
                        },
                        child: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;
    await _testService.saveTest(result);
    if (!mounted) return;
    setState(() => _test = result);
  }

  Future<void> _pickNotificationTime() async {
    final settings = _settings;
    if (settings == null) return;
    final initial = TimeOfDay(hour: settings.notificationMinutes ~/ 60, minute: settings.notificationMinutes % 60);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final next = settings.copyWith(notificationMinutes: picked.hour * 60 + picked.minute);
    await _settingsService.saveSettings(next);
    if (!mounted) return;
    setState(() => _settings = next);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final test = _test;
    final settings = _settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: _loading || profile == null || test == null || settings == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    ProfileHeaderCard(
                      profile: profile,
                      maxStreak: _maxStreakFromHistory(_cfHistory),
                      onEditProfile: _editProfile,
                      onEditAvatar: _editAvatar,
                    ),
                    const SizedBox(height: 18),
                    Text('Información personal', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ProgressSectionCard(
                      child: Column(
                        children: [
                          ProfileActionTile(icon: Icons.cake_outlined, title: 'Edad', subtitle: profile.age == null ? '—' : '${profile.age} años', onTap: _editProfile),
                          const Divider(height: 1),
                          ProfileActionTile(icon: Icons.height, title: 'Altura', subtitle: profile.heightCm == null ? '—' : '${profile.heightCm!.round()} cm', onTap: _editProfile),
                          const Divider(height: 1),
                          ProfileActionTile(icon: Icons.monitor_weight_outlined, title: 'Peso actual', subtitle: profile.currentWeightKg == null ? '—' : '${profile.currentWeightKg!.toStringAsFixed(1)} kg', onTap: _editProfile),
                          const Divider(height: 1),
                          ProfileActionTile(icon: Icons.flag_outlined, title: 'Objetivo', subtitle: profile.goal, onTap: _editProfile),
                          const Divider(height: 1),
                          ProfileActionTile(icon: Icons.school_outlined, title: 'Nivel', subtitle: profile.level.label, onTap: _editProfile),
                          const Divider(height: 1),
                          ProfileActionTile(icon: Icons.schedule, title: 'Tiempo disponible', subtitle: profile.availableMinutes == null ? '—' : '${profile.availableMinutes} min/día', onTap: _editProfile),
                          const Divider(height: 1),
                          ProfileActionTile(icon: Icons.place_outlined, title: 'Lugar habitual', subtitle: profile.usualTrainingPlace ?? '—', onTap: _editProfile),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Test personal', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ProgressSectionCard(
                      child: Column(
                        children: [
                          ProfileActionTile(
                            icon: Icons.assignment_outlined,
                            title: 'Resumen',
                            subtitle: '${test.primaryGoal.label} · ${test.daysPerWeek} días/sem · ${test.availableMinutes} min · ${test.preference.label}',
                            onTap: _editPersonalTest,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.edit_note_outlined,
                            title: 'Editar test',
                            subtitle: 'Actualiza tus respuestas',
                            onTap: _editPersonalTest,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Cuenta', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ProgressSectionCard(
                      child: Column(
                        children: [
                          const ProfileActionTile(icon: Icons.g_mobiledata, title: 'Conectar con Google', subtitle: 'Próximamente', enabled: false),
                          const Divider(height: 1),
                          const ProfileActionTile(icon: Icons.email_outlined, title: 'Conectar con correo', subtitle: 'Próximamente', enabled: false),
                          const Divider(height: 1),
                          ProfileActionTile(icon: Icons.logout, title: 'Cerrar sesión', subtitle: 'Visual (sin backend)', onTap: () => _toast('Cierre de sesión: próximamente')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Configuración', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      settings: settings,
                      onPickTime: _pickNotificationTime,
                      onSave: (s) async {
                        await _settingsService.saveSettings(s);
                        if (!mounted) return;
                        setState(() => _settings = s);
                      },
                      onDeleteAccount: () => _toast('Borrar cuenta: próximamente'),
                    ),
                    const SizedBox(height: 18),
                    Text('Soporte', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ProgressSectionCard(
                      child: Column(
                        children: [
                          ProfileActionTile(icon: Icons.support_agent_outlined, title: 'Contacto', onTap: () => _toast('Contacto: próximamente')),
                          const Divider(height: 1),
                          ProfileActionTile(icon: Icons.quiz_outlined, title: 'FAQ', onTap: () => _toast('FAQ: próximamente')),
                          const Divider(height: 1),
                          ProfileActionTile(icon: Icons.description_outlined, title: 'Términos', onTap: () => _toast('Términos: próximamente')),
                          const Divider(height: 1),
                          ProfileActionTile(icon: Icons.privacy_tip_outlined, title: 'Política de privacidad', onTap: () => _toast('Privacidad: próximamente')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Versión 1.0.0',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: CFColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.settings,
    required this.onPickTime,
    required this.onSave,
    required this.onDeleteAccount,
  });

  final UserSettings settings;
  final VoidCallback onPickTime;
  final ValueChanged<UserSettings> onSave;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: settings.notificationMinutes ~/ 60, minute: settings.notificationMinutes % 60);

    return ProgressSectionCard(
      child: Column(
        children: [
          ProfileActionTile(
            icon: Icons.language_outlined,
            title: 'Idioma',
            subtitle: settings.language.label,
            onTap: () async {
              final picked = await showModalBottomSheet<AppLanguage>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  var selected = settings.language;
                  return SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: StatefulBuilder(
                        builder: (context, setSheetState) {
                          return ProgressSectionCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Idioma',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<AppLanguage>(
                                  initialValue: selected,
                                  items: [
                                    for (final v in AppLanguage.values)
                                      DropdownMenuItem(value: v, child: Text(v.label)),
                                  ],
                                  onChanged: (v) => setSheetState(() => selected = v ?? selected),
                                  decoration: const InputDecoration(labelText: 'Idioma'),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () => Navigator.of(context).pop(selected),
                                    child: const Text('Guardar'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
              if (picked == null) return;
              onSave(settings.copyWith(language: picked));
            },
          ),
          const Divider(height: 1),
          ProfileActionTile(icon: Icons.notifications_active_outlined, title: 'Hora notificaciones', subtitle: time.format(context), onTap: onPickTime),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: CFColors.primary.withValues(alpha: 0.10),
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    border: Border.all(color: CFColors.softGray),
                  ),
                  child: const Icon(Icons.privacy_tip_outlined, color: CFColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Privacidad', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(
                        settings.privacyMode ? 'Modo privado activado' : 'Modo privado desactivado',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.privacyMode,
                  activeThumbColor: CFColors.primary,
                  onChanged: (v) => onSave(settings.copyWith(privacyMode: v)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ProfileActionTile(icon: Icons.delete_outline, title: 'Borrar cuenta', subtitle: 'Visual (sin backend)', onTap: onDeleteAccount),
        ],
      ),
    );
  }
}
