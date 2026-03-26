import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../core/app_theme_controller.dart';
import '../core/theme.dart';
import '../models/user_profile.dart';
import '../models/user_settings.dart';
import '../services/achievements_service.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../services/profile_service.dart';
import '../services/settings_service.dart';
import '../services/user_repository.dart';
import '../services/weight_service.dart';
import '../widgets/profile/profile_header_card.dart';
import '../widgets/profile/profile_action_tile.dart';
import '../widgets/progress/progress_section_card.dart';
import '../utils/js_error_details.dart';

import 'auth/auth_wrapper.dart';

import 'profile/contact_screen.dart';
import 'profile/faq_screen.dart';
import 'profile/privacy_screen.dart';
import 'profile/premium_screen.dart';
import 'profile/streak_preferences_setup_screen.dart';
import 'profile/terms_screen.dart';
import 'profile/widgets/profile_edit_sheets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _onboardingService = OnboardingService();
  final _profileService = ProfileService();
  final _settingsService = SettingsService();
  final _weightService = WeightService();
  final _achievementsService = AchievementsService();

  UserProfile? _profile;
  UserSettings? _settings;
  bool _loading = true;
  String? _identityEnsuredUid;
  String? _identityEnsuringUid;
  int? _achievementsLevel;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<UserProfile> _syncCurrentWeightWithProgress(
    UserProfile profile,
  ) async {
    try {
      final history = await _weightService.getHistory();
      final latest = history.isEmpty ? null : history.last;
      final latestWeight = latest?.weight;

      // Source of truth: last registered weight entry (used in Progreso).
      if (latestWeight != null && latestWeight > 0) {
        final prev = profile.currentWeightKg;
        final needsUpdate = prev == null || (prev - latestWeight).abs() > 0.001;
        if (!needsUpdate) return profile;

        final next = profile.copyWith(currentWeightKg: latestWeight);
        await _profileService.saveProfile(next);
        unawaited(_onboardingService.syncProfileToFirestore(next));
        return next;
      }

      // If there is a profile weight but no history yet, seed today so Progreso matches.
      final pWeight = profile.currentWeightKg;
      if (pWeight != null && pWeight > 0) {
        await _weightService.upsertToday(pWeight);
      }
    } catch (_) {
      // best-effort
    }

    return profile;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final baseProfile = await _profileService.getOrCreateProfile();
    final profile = await _syncCurrentWeightWithProgress(baseProfile);
    final settings = await _settingsService.getSettings();

    // Best-effort: ensure identity exists so UI doesn't show "—".
    if (Firebase.apps.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await UserRepository().ensureUniqueTagForUser(user);
        } catch (_) {
          // best-effort
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _settings = settings;
      _loading = false;
    });

    unawaited(_refreshAchievementsLevel());
  }

  Future<void> _refreshAchievementsLevel() async {
    try {
      final items = await _achievementsService.getAchievementsForCurrentUser();
      final unlockedItems = items.where((e) => e.user.unlocked).toList();
      final inProgressItems = items
          .where((e) => !e.user.unlocked && e.progressRatio > 0)
          .toList();

      final xp =
          (unlockedItems.length * 50) +
          (inProgressItems.length * 10) +
          items.fold<int>(0, (a, b) => a + (b.progressRatio * 20).round());

      final level = (xp ~/ 250) + 1;
      if (!mounted) return;
      setState(() => _achievementsLevel = level);
    } catch (_) {
      // best-effort
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _debugBoxedError(String label, Object error, StackTrace stack) {
    debugPrint(label);
    debugPrint('type: ${error.runtimeType}');

    if (error is FirebaseException) {
      debugPrint('firebase.code: ${error.code}');
      debugPrint('firebase.plugin: ${error.plugin}');
      if (error.message != null) {
        debugPrint('firebase.message: ${error.message}');
      }
    }
    if (error is PlatformException) {
      debugPrint('platform.code: ${error.code}');
      if (error.message != null) {
        debugPrint('platform.message: ${error.message}');
      }
      if (error.details != null) {
        debugPrint('platform.details: ${error.details}');
      }
    }

    String safe;
    try {
      safe = Error.safeToString(error);
    } catch (_) {
      safe = '<unprintable>';
    }
    debugPrint('error: $safe');

    if (kIsWeb) {
      final jsDetails = tryDescribeJsError(error);
      if (jsDetails != null) debugPrint(jsDetails);
    }

    final stackString = stack.toString();
    debugPrint(
      'stack: ${stackString.trim().isEmpty ? '<empty>' : stackString}',
    );

    // Some platforms box the original error/stack in properties named `error` and `stack`.
    // Accessing these can throw (especially on web), so keep it very defensive.
    Object? boxedError;
    Object? boxedStack;
    if (!kIsWeb) {
      try {
        final dyn = error as dynamic;
        try {
          boxedError = dyn.error;
        } catch (_) {
          boxedError = null;
        }
        try {
          boxedStack = dyn.stack;
        } catch (_) {
          boxedStack = null;
        }
      } catch (_) {
        boxedError = null;
        boxedStack = null;
      }
    }

    if (boxedError != null) {
      debugPrint('boxed.type: ${boxedError.runtimeType}');
      String boxedSafe;
      try {
        boxedSafe = Error.safeToString(boxedError);
      } catch (_) {
        boxedSafe = '<unprintable>';
      }
      debugPrint('boxed.error: $boxedSafe');

      if (kIsWeb) {
        final jsDetails = tryDescribeJsError(boxedError);
        if (jsDetails != null) debugPrint('boxed.$jsDetails');
      }
    }
    if (boxedStack != null) {
      try {
        final s = boxedStack.toString();
        debugPrint('boxed.stack: ${s.trim().isEmpty ? '<empty>' : s}');
      } catch (_) {
        debugPrint('boxed.stack: <unprintable>');
      }
    }
  }

  void _ensureIdentityOnce(User user) {
    if (Firebase.apps.isEmpty) return;
    if (_identityEnsuredUid == user.uid) return;
    if (_identityEnsuringUid == user.uid) return;
    _identityEnsuringUid = user.uid;

    unawaited(() async {
      try {
        await UserRepository().ensureUniqueTagForUser(user);
        _identityEnsuredUid = user.uid;
      } catch (e, st) {
        // best-effort; avoid noisy UI here.
        _debugBoxedError('ensureUniqueTagForUser failed', e, st);
      } finally {
        if (_identityEnsuringUid == user.uid) {
          _identityEnsuringUid = null;
        }
      }
    }());
  }

  Future<void> _signOut() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (!mounted) return;
        _toast('Firebase no está configurado');
        return;
      }
      await AuthService().signOut();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _toast('No se pudo cerrar sesión');
    }
  }

  void _openPremium() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
  }

  Future<void> _deleteAccount() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (!mounted) return;
        _toast('Firebase no está configurado');
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        _toast('No hay sesión activa');
        return;
      }

      final controller = TextEditingController();
      try {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                final typed = controller.text.trim().toUpperCase();
                final canDelete = typed == 'ELIMINAR';

                return AlertDialog(
                  title: const Text('Eliminar cuenta'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Esta acción es permanente. Se eliminarán tus datos y chats asociados.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: CFColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Escribe ELIMINAR para confirmar:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'ELIMINAR',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: canDelete
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      child: const Text('Eliminar'),
                    ),
                  ],
                );
              },
            );
          },
        );

        if (confirmed != true) return;
        if (!mounted) return;

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
                  Expanded(child: Text('Eliminando cuenta...')),
                ],
              ),
            );
          },
        );

        var ok = false;
        try {
          final callable = FirebaseFunctions.instance.httpsCallable(
            'deleteMyAccount',
          );
          await callable.call(<String, dynamic>{'confirm': 'eliminar'});
          ok = true;
        } on FirebaseFunctionsException catch (e, st) {
          _debugBoxedError('deleteMyAccount failed', e, st);
          if (mounted) {
            final message = switch (e.code) {
              'invalid-argument' => 'La confirmacion no es valida',
              'unauthenticated' =>
                'Tu sesion ha caducado. Vuelve a iniciar sesion',
              _ => 'No se pudo eliminar la cuenta',
            };
            _toast(message);
          }
        } catch (e, st) {
          _debugBoxedError('deleteMyAccount failed', e, st);
          if (mounted) {
            _toast('No se pudo eliminar la cuenta');
          }
        } finally {
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }

        if (!ok) return;

        try {
          await AuthService().clearLocalAccountData();
        } catch (_) {
          // best-effort
        }

        try {
          await AuthService().signOut();
        } catch (_) {
          // best-effort
        }

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      } finally {
        controller.dispose();
      }
    } catch (_) {
      if (!mounted) return;
      _toast('No se pudo eliminar la cuenta');
    }
  }

  Future<void> _saveProfile(UserProfile next) async {
    final beforeName = _profile?.name.trim();
    await _profileService.saveProfile(next);
    await _onboardingService.syncProfileToFirestore(next);

    // Keep identity in sync with the visible profile name.
    // Tag stays immutable; updateUsername will auto-generate a new tag only on collision.
    final afterName = next.name.trim();
    if (Firebase.apps.isNotEmpty &&
        afterName.isNotEmpty &&
        beforeName != afterName) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await UserRepository().updateUsername(
            uid: user.uid,
            newUsername: afterName,
          );
        } catch (e, st) {
          _debugBoxedError('updateUsername (from profile name) failed', e, st);
        }
      }
    }

    if (!mounted) return;
    setState(() => _profile = next);
  }

  Future<void> _saveSettings(UserSettings next) async {
    await _settingsService.saveSettings(next);
    if (!mounted) return;
    setState(() => _settings = next);
  }

  Future<void> _editThemeMode() async {
    final settings = _settings;
    if (settings == null) return;

    final picked = await showModalBottomSheet<AppThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in AppThemeMode.values)
                RadioListTile<AppThemeMode>(
                  value: mode,
                  groupValue: settings.appThemeMode,
                  title: Text(mode.label),
                  subtitle: Text(switch (mode) {
                    AppThemeMode.system => 'Sigue el ajuste del dispositivo',
                    AppThemeMode.light => 'Usa la apariencia clara',
                    AppThemeMode.dark => 'Usa la apariencia oscura',
                  }),
                  onChanged: (value) {
                    if (value == null) return;
                    Navigator.of(context).pop(value);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (picked == null || picked == settings.appThemeMode) return;
    await _saveSettings(settings.copyWith(appThemeMode: picked));
    await AppThemeController.instance.setMode(picked);
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
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Icono',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
                              selectedColor: CFColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              side: BorderSide(
                                color: v == icon
                                    ? CFColors.primary
                                    : CFColors.softGray,
                              ),
                              labelStyle: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: v == icon
                                        ? CFColors.primary
                                        : CFColors.textSecondary,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Color',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final i in List<int>.generate(4, (x) => x)) ...[
                            InkWell(
                              onTap: () => setSheetState(() => colorIndex = i),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(14),
                              ),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: [
                                    CFColors.primary.withValues(alpha: 0.12),
                                    CFColors.primary.withValues(alpha: 0.18),
                                    CFColors.primaryLight.withValues(
                                      alpha: 0.28,
                                    ),
                                    CFColors.softGray,
                                  ][i],
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(14),
                                  ),
                                  border: Border.all(
                                    color: colorIndex == i
                                        ? CFColors.primary
                                        : CFColors.softGray,
                                    width: 2,
                                  ),
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
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(AvatarSpec(icon: icon, colorIndex: colorIndex)),
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
    await _saveProfile(next);
  }

  Future<void> _editName() async {
    final profile = _profile;
    if (profile == null) return;

    final name = await ProfileEditSheets.editText(
      context,
      title: 'Nombre',
      label: 'Nombre',
      initialValue: profile.name,
      maxLength: 24,
    );
    if (name == null || name.trim().isEmpty) return;
    await _saveProfile(profile.copyWith(name: name.trim()));
  }

  Future<void> _editGoal() async {
    final profile = _profile;
    if (profile == null) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var selected = profile.goal;
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
                              'Objetivo principal',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final g in _goals) ...[
                        Card(
                          child: ListTile(
                            title: Text(g),
                            leading: Icon(
                              selected == g
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selected == g
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            onTap: () => setSheetState(() => selected = g),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
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

    if (picked == null || picked.trim().isEmpty) return;
    await _saveProfile(profile.copyWith(goal: picked.trim()));
  }

  Future<void> _editSex() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.pickEnum<UserSex>(
      context,
      title: 'Sexo',
      initialValue: profile.sex,
      values: UserSex.values,
      label: (v) => v.label,
    );
    if (picked == null) return;
    await _saveProfile(profile.copyWith(sex: picked));
  }

  Future<void> _editAge() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.editInt(
      context,
      title: 'Edad',
      label: 'Edad',
      initialValue: profile.age,
      suffix: 'años',
    );
    if (picked == null) return;
    await _saveProfile(profile.copyWith(age: picked));
  }

  Future<void> _editHeight() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.editDouble(
      context,
      title: 'Altura',
      label: 'Altura',
      initialValue: profile.heightCm,
      fractionDigits: 0,
      suffix: 'cm',
    );
    if (picked == null) return;
    await _saveProfile(profile.copyWith(heightCm: picked));
  }

  Future<void> _editWeight() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.editDouble(
      context,
      title: 'Peso actual',
      label: 'Peso',
      initialValue: profile.currentWeightKg,
      fractionDigits: 1,
      suffix: 'kg',
    );
    if (picked == null || picked <= 0) return;
    await _weightService.upsertToday(picked);
    await _saveProfile(profile.copyWith(currentWeightKg: picked));
  }

  Future<void> _editLevel() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.pickEnum<UserLevel>(
      context,
      title: 'Nivel deportivo',
      initialValue: profile.level,
      values: UserLevel.values,
      label: (v) => v.label,
    );
    if (picked == null) return;
    await _saveProfile(profile.copyWith(level: picked));
  }

  Future<void> _editAvailableMinutes() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.editInt(
      context,
      title: 'Tiempo disponible',
      label: 'Minutos por día',
      initialValue: profile.availableMinutes,
      suffix: 'min',
    );
    if (picked == null) return;
    await _saveProfile(profile.copyWith(availableMinutes: picked));
  }

  Future<void> _editAvailabilityRange() async {
    final profile = _profile;
    if (profile == null) return;

    TimeOfDay? start;
    if (profile.availableTimeStartMinutes != null) {
      final v = profile.availableTimeStartMinutes!;
      start = TimeOfDay(hour: v ~/ 60, minute: v % 60);
    }

    TimeOfDay? end;
    if (profile.availableTimeEndMinutes != null) {
      final v = profile.availableTimeEndMinutes!;
      end = TimeOfDay(hour: v ~/ 60, minute: v % 60);
    }

    final picked = await ProfileEditSheets.pickTimeRange(
      context,
      title: 'Rango horario',
      initialStart: start,
      initialEnd: end,
    );
    if (picked == null) return;

    int? startMins;
    if (picked.start != null) {
      startMins = picked.start!.hour * 60 + picked.start!.minute;
    }
    int? endMins;
    if (picked.end != null) {
      endMins = picked.end!.hour * 60 + picked.end!.minute;
    }

    await _saveProfile(
      profile.copyWith(
        availableTimeStartMinutes: startMins,
        availableTimeEndMinutes: endMins,
      ),
    );
  }

  Future<void> _editUsualPlace() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.pickSingleString(
      context,
      title: 'Lugar habitual de entrenamiento',
      options: _trainingPlaces,
      initialValue: profile.usualTrainingPlace,
      allowEmpty: false,
    );
    if (picked == null) return;
    await _saveProfile(profile.copyWith(usualTrainingPlace: picked));
  }

  Future<void> _editDays() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.pickDays(
      context,
      title: 'Días disponibles',
      selected: profile.availableDays.toSet(),
    );
    if (picked == null) return;
    await _saveProfile(profile.copyWith(availableDays: picked));
  }

  Future<void> _editPreferences() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.pickMultiString(
      context,
      title: 'Preferencias deportivas',
      options: _sportPreferences,
      selected: profile.preferences.toSet(),
      allowEmpty: true,
    );
    if (picked == null) return;
    await _saveProfile(profile.copyWith(preferences: picked));
  }

  Future<void> _editInjuries() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.pickMultiString(
      context,
      title: 'Lesiones comunes',
      options: _injuryOptions,
      selected: profile.injuries.toSet(),
      allowEmpty: true,
    );
    if (picked == null) return;
    final cleaned = picked.contains('Ninguna') ? <String>['Ninguna'] : picked;
    await _saveProfile(profile.copyWith(injuries: cleaned));
  }

  Future<void> _editHealthConditions() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.pickMultiString(
      context,
      title: 'Condición médica',
      options: _healthConditionOptions,
      selected: profile.healthConditions.toSet(),
      allowEmpty: true,
    );
    if (picked == null) return;
    final cleaned = picked.contains('Ninguna') ? <String>['Ninguna'] : picked;
    await _saveProfile(profile.copyWith(healthConditions: cleaned));
  }

  Future<void> _editWorkType() async {
    final profile = _profile;
    if (profile == null) return;
    final picked = await ProfileEditSheets.pickEnum<WorkType>(
      context,
      title: 'Tipo de trabajo',
      initialValue: profile.workType,
      values: WorkType.values,
      label: (v) => v.label,
    );
    if (picked == null) return;
    await _saveProfile(profile.copyWith(workType: picked));
  }

  Future<void> _editNotificationTime() async {
    final profile = _profile;
    final settings = _settings;
    if (profile == null || settings == null) return;

    TimeOfDay? initial;
    if (profile.notificationMinutes != null) {
      final mins = profile.notificationMinutes!;
      initial = TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
    } else {
      initial = TimeOfDay(
        hour: settings.notificationMinutes ~/ 60,
        minute: settings.notificationMinutes % 60,
      );
    }

    final picked = await ProfileEditSheets.pickTime(
      context,
      title: 'Hora notificaciones',
      initial: initial,
    );
    if (picked == null) return;

    final mins = picked.hour * 60 + picked.minute;
    await _saveProfile(profile.copyWith(notificationMinutes: mins));
    await _saveSettings(settings.copyWith(notificationMinutes: mins));
  }

  Future<void> _editStreakPreferences() async {
    final profile = _profile;
    if (profile == null) return;

    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => StreakPreferencesSetupScreen(initialProfile: profile),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _profile = updated);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final settings = _settings;
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;

    if (user != null) {
      _ensureIdentityOnce(user);
    }

    return Scaffold(
      appBar: AppBar(title: const SizedBox.shrink()),
      body: SafeArea(
        child: _loading || profile == null || settings == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (Firebase.apps.isNotEmpty && user != null)
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .snapshots(),
                        builder: (context, snap) {
                          final data = snap.data?.data();
                          final uniqueTag =
                              (data?['uniqueTag'] as String?)?.trim() ?? '';
                          final username =
                              (data?['username'] as String?)?.trim() ?? '';
                          final tag = (data?['tag'] as String?)?.trim() ?? '';
                          final visibleName = profile.name.trim();
                          final display = tag.isNotEmpty
                              ? '${visibleName.isNotEmpty ? visibleName : (uniqueTag.isNotEmpty ? uniqueTag.split('#').first : (username.isNotEmpty ? username : 'user'))}#$tag'
                              : (uniqueTag.isNotEmpty ? uniqueTag : '');

                          return ProfileHeaderCard(
                            profile: profile,
                            onEditAvatar: _editAvatar,
                            onEditName: _editName,
                            onEditPressed: _editName,
                            achievementsLevel: _achievementsLevel,
                            identityTag: display,
                            onCopyIdentityTag: display.isEmpty
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: display),
                                    );
                                    if (!mounted) return;
                                    _toast('Copiado');
                                  },
                            onPremiumPressed: _openPremium,
                          );
                        },
                      )
                    else
                      ProfileHeaderCard(
                        profile: profile,
                        onEditAvatar: _editAvatar,
                        onEditName: _editName,
                        onEditPressed: _editName,
                        achievementsLevel: _achievementsLevel,
                        onPremiumPressed: _openPremium,
                      ),
                    const SizedBox(height: 14),
                    ProgressSectionCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tu perfil deportivo',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          _summaryRow(
                            context,
                            label: 'Objetivo',
                            value: profile.goal,
                          ),
                          const SizedBox(height: 10),
                          _summaryRow(
                            context,
                            label: 'Nivel',
                            value: profile.level.label,
                          ),
                          const SizedBox(height: 10),
                          _summaryRow(
                            context,
                            label: 'Disponibilidad',
                            value: _formatAvailabilitySummary(context, profile),
                          ),
                          const SizedBox(height: 10),
                          _summaryRow(
                            context,
                            label: 'Lugar',
                            value: profile.usualTrainingPlace ?? '—',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Perfil deportivo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ProgressSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _groupLabel(context, 'Objetivo y nivel'),
                          ProfileActionTile(
                            icon: Icons.flag_outlined,
                            title: 'Objetivo',
                            subtitle: profile.goal,
                            onTap: _editGoal,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.school_outlined,
                            title: 'Nivel deportivo',
                            subtitle: profile.level.label,
                            onTap: _editLevel,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.local_fire_department_outlined,
                            title: 'Racha personalizada',
                            subtitle: profile.streakPreferencesSummary,
                            onTap: _editStreakPreferences,
                          ),
                          const SizedBox(height: 10),
                          _groupLabel(context, 'Disponibilidad'),
                          ProfileActionTile(
                            icon: Icons.schedule,
                            title: 'Tiempo disponible',
                            subtitle: profile.availableMinutes == null
                                ? '—'
                                : '${profile.availableMinutes} min/día',
                            onTap: _editAvailableMinutes,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.access_time,
                            title: 'Rango horario',
                            subtitle: _formatAvailabilityRange(
                              context,
                              profile,
                            ),
                            onTap: _editAvailabilityRange,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.calendar_today_outlined,
                            title: 'Días disponibles',
                            subtitle: _formatDays(profile.availableDays),
                            onTap: _editDays,
                          ),
                          const SizedBox(height: 10),
                          _groupLabel(context, 'Preferencias'),
                          ProfileActionTile(
                            icon: Icons.place_outlined,
                            title: 'Lugar habitual de entrenamiento',
                            subtitle: profile.usualTrainingPlace ?? '—',
                            onTap: _editUsualPlace,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.favorite_border,
                            title: 'Preferencias deportivas',
                            subtitle: profile.preferences.isEmpty
                                ? '—'
                                : profile.preferences.join(' · '),
                            onTap: _editPreferences,
                          ),
                          const SizedBox(height: 10),
                          _groupLabel(context, 'Salud'),
                          ProfileActionTile(
                            icon: Icons.healing_outlined,
                            title: 'Lesiones',
                            subtitle: profile.injuries.isEmpty
                                ? '—'
                                : profile.injuries.join(' · '),
                            onTap: _editInjuries,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.health_and_safety_outlined,
                            title: 'Condición médica',
                            subtitle: profile.healthConditions.isEmpty
                                ? '—'
                                : profile.healthConditions.join(' · '),
                            onTap: _editHealthConditions,
                          ),
                          const SizedBox(height: 10),
                          _groupLabel(context, 'Trabajo'),
                          ProfileActionTile(
                            icon: Icons.work_outline,
                            title: 'Tipo de trabajo',
                            subtitle: profile.workType?.label ?? '—',
                            onTap: _editWorkType,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Datos físicos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ProgressSectionCard(
                      child: Column(
                        children: [
                          ProfileActionTile(
                            icon: Icons.cake_outlined,
                            title: 'Edad',
                            subtitle: profile.age == null
                                ? '—'
                                : '${profile.age} años',
                            onTap: _editAge,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.person_outline,
                            title: 'Sexo',
                            subtitle: profile.sex?.label ?? '—',
                            onTap: _editSex,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.height,
                            title: 'Altura',
                            subtitle: profile.heightCm == null
                                ? '—'
                                : '${profile.heightCm!.round()} cm',
                            onTap: _editHeight,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.monitor_weight_outlined,
                            title: 'Peso actual',
                            subtitle: profile.currentWeightKg == null
                                ? '—'
                                : '${profile.currentWeightKg!.toStringAsFixed(1)} kg',
                            onTap: _editWeight,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Preferencias',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ProgressSectionCard(
                      child: Column(
                        children: [
                          ProfileActionTile(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Mostrar mi perfil en Comunidad',
                            subtitle: settings.privacyMode
                                ? 'No visible'
                                : 'Visible',
                            trailing: Switch(
                              value: !settings.privacyMode,
                              activeThumbColor: CFColors.primary,
                              onChanged: (v) async {
                                await _saveSettings(
                                  settings.copyWith(privacyMode: !v),
                                );
                                if (Firebase.apps.isEmpty) return;
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) return;
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('user_public')
                                      .doc(user.uid)
                                      .set({
                                        'visible': v,
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));
                                } catch (_) {
                                  // best-effort
                                }
                              },
                            ),
                            onTap: () async {
                              final nextVisible = settings.privacyMode;
                              await _saveSettings(
                                settings.copyWith(
                                  privacyMode: !settings.privacyMode,
                                ),
                              );
                              if (Firebase.apps.isEmpty) return;
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return;
                              try {
                                await FirebaseFirestore.instance
                                    .collection('user_public')
                                    .doc(user.uid)
                                    .set({
                                      'visible': nextVisible,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));
                              } catch (_) {
                                // best-effort
                              }
                            },
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.restaurant_menu,
                            title: 'Mostrar valor nutricional',
                            subtitle: settings.showNutritionValues
                                ? 'Visible'
                                : 'Oculto',
                            trailing: Switch(
                              value: settings.showNutritionValues,
                              activeThumbColor: CFColors.primary,
                              onChanged: (v) => _saveSettings(
                                settings.copyWith(showNutritionValues: v),
                              ),
                            ),
                            onTap: () => _saveSettings(
                              settings.copyWith(
                                showNutritionValues:
                                    !settings.showNutritionValues,
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.brightness_6_outlined,
                            title: 'Apariencia',
                            subtitle: settings.appThemeMode.label,
                            onTap: _editThemeMode,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.language_outlined,
                            title: 'Idioma',
                            subtitle: 'Español · Inglés (próximamente)',
                            trailing: const Icon(
                              Icons.lock_outline,
                              color: CFColors.textSecondary,
                            ),
                            onTap: () => _toast('Inglés: próximamente'),
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.notifications_active_outlined,
                            title: 'Notificaciones',
                            subtitle: _formatNotificationTime(
                              context,
                              profile,
                              settings,
                            ),
                            onTap: _editNotificationTime,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.volume_up_outlined,
                            title: 'Sonido al terminar ejercicio',
                            subtitle: settings.workoutEndSoundEnabled
                                ? 'Activado'
                                : 'Desactivado',
                            trailing: Switch(
                              value: settings.workoutEndSoundEnabled,
                              activeThumbColor: CFColors.primary,
                              onChanged: (v) => _saveSettings(
                                settings.copyWith(workoutEndSoundEnabled: v),
                              ),
                            ),
                            onTap: () => _saveSettings(
                              settings.copyWith(
                                workoutEndSoundEnabled:
                                    !settings.workoutEndSoundEnabled,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Cuenta',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ProgressSectionCard(
                      child: Column(
                        children: [
                          ProfileActionTile(
                            icon: Icons.logout,
                            title: 'Cerrar sesión',
                            subtitle: 'Desconectar de tu cuenta',
                            onTap: _signOut,
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.delete_forever_outlined,
                            title: 'Eliminar cuenta',
                            subtitle: 'Eliminar tu cuenta y todos tus datos',
                            enabled: Firebase.apps.isNotEmpty && user != null,
                            accentColor: Theme.of(context).colorScheme.error,
                            onTap: _deleteAccount,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Soporte y legal',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ProgressSectionCard(
                      child: Column(
                        children: [
                          ProfileActionTile(
                            icon: Icons.support_agent_outlined,
                            title: 'Contacto',
                            subtitle: 'Email, teléfono y redes',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ContactScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.quiz_outlined,
                            title: 'Preguntas frecuentes',
                            subtitle: 'Respuestas rápidas',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FaqScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.description_outlined,
                            title: 'Términos de uso',
                            subtitle: 'Texto informativo',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TermsScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ProfileActionTile(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Política de privacidad',
                            subtitle: 'RGPD y eliminación de datos',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrivacyScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _groupLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.cfTextSecondary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: context.cfSoftSurface,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: context.cfBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.cfTextSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: context.cfTextPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAvailabilitySummary(BuildContext context, UserProfile profile) {
    final parts = <String>[];

    if (profile.availableMinutes != null) {
      parts.add('${profile.availableMinutes} min/día');
    }

    final days = _formatDays(profile.availableDays);
    if (days != '—') {
      parts.add(days);
    }

    final range = _formatAvailabilityRange(context, profile);
    if (range != '—') {
      parts.add(range);
    }

    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}

String _formatDays(List<int> days) {
  if (days.isEmpty) return '—';
  final labels = <String>[];
  for (final d in days) {
    labels.add(switch (d) {
      1 => 'L',
      2 => 'M',
      3 => 'X',
      4 => 'J',
      5 => 'V',
      6 => 'S',
      _ => 'D',
    });
  }
  return labels.join(' · ');
}

String _formatAvailabilityRange(BuildContext context, UserProfile profile) {
  final s = profile.availableTimeStartMinutes;
  final e = profile.availableTimeEndMinutes;
  if (s == null || e == null) return '—';
  final start = TimeOfDay(hour: s ~/ 60, minute: s % 60).format(context);
  final end = TimeOfDay(hour: e ~/ 60, minute: e % 60).format(context);
  return '$start – $end';
}

String _formatNotificationTime(
  BuildContext context,
  UserProfile profile,
  UserSettings settings,
) {
  final mins = profile.notificationMinutes ?? settings.notificationMinutes;
  final t = TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  return t.format(context);
}
