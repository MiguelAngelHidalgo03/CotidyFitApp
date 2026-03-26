import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/onboarding_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/profile/streak_preferences_editor.dart';
import '../../widgets/progress/progress_section_card.dart';
import '../main_navigation.dart';

class StreakPreferencesSetupScreen extends StatefulWidget {
  const StreakPreferencesSetupScreen({
    super.key,
    this.initialProfile,
    this.requireCompletion = false,
  });

  final UserProfile? initialProfile;
  final bool requireCompletion;

  @override
  State<StreakPreferencesSetupScreen> createState() =>
      _StreakPreferencesSetupScreenState();
}

class _StreakPreferencesSetupScreenState
    extends State<StreakPreferencesSetupScreen> {
  final _profileService = ProfileService();
  final _onboardingService = OnboardingService();

  UserProfile? _profile;
  UserStreakPreferences _preferences = UserStreakPreferences();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = widget.initialProfile ?? await _profileService.getOrCreateProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _preferences = profile.streakPreferences ?? UserStreakPreferences();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final profile = _profile;
    if (profile == null || !_preferences.isConfigured || _saving) return;

    setState(() => _saving = true);
    final next = profile.copyWith(streakPreferences: _preferences);
    await _profileService.saveProfile(next);
    await _onboardingService.syncProfileToFirestore(next);

    if (!mounted) return;

    if (widget.requireCompletion) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.requireCompletion,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.requireCompletion,
          title: Text(
            widget.requireCompletion ? 'Personaliza tu racha' : 'Racha personalizada',
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      widget.requireCompletion
                          ? 'Antes de entrar, elige que quieres mantener en racha.'
                          : 'Define que acciones cuentan para tu racha diaria.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Asi cada usuario tiene una constancia distinta: nutricion, entreno, agua, pasos, retos o un mix.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    ProgressSectionCard(
                      child: StreakPreferencesEditor(
                        value: _preferences,
                        enabled: !_saving,
                        title: 'Que quieres que cuente',
                        subtitle: 'Puedes elegir una sola area o combinar varias.',
                        onChanged: (value) => setState(() => _preferences = value),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_preferences.isConfigured && !_saving)
                            ? _save
                            : null,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.requireCompletion
                                    ? 'Guardar y entrar'
                                    : 'Guardar cambios',
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
