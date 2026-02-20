import 'package:flutter/services.dart';

import '../models/workout_sound_model.dart';
import 'settings_service.dart';

class WorkoutSoundService {
  WorkoutSoundService({SettingsService? settings})
    : _settings = settings ?? SettingsService();

  final SettingsService _settings;

  static const List<WorkoutSoundModel> availableSounds = [
    WorkoutSoundModel(
      id: 'mute',
      nombre: 'Silencio',
      sourceType: WorkoutSoundSourceType.system,
    ),
    WorkoutSoundModel(
      id: 'system_click',
      nombre: 'Click (sistema)',
      sourceType: WorkoutSoundSourceType.system,
    ),
    WorkoutSoundModel(
      id: 'system_alert',
      nombre: 'Alerta (sistema)',
      sourceType: WorkoutSoundSourceType.system,
    ),
  ];

  WorkoutSoundModel getById(String id) {
    for (final s in availableSounds) {
      if (s.id == id) return s;
    }
    return availableSounds.last;
  }

  Future<String> getSelectedSoundId() async {
    final settings = await _settings.getSettings();
    return settings.workoutEndSoundId;
  }

  Future<void> setSelectedSoundId(String id) async {
    final settings = await _settings.getSettings();
    await _settings.saveSettings(settings.copyWith(workoutEndSoundId: id));
  }

  Future<void> playSelectedEndSound() async {
    final id = await getSelectedSoundId();
    await playById(id);
  }

  Future<void> playById(String id) async {
    switch (id) {
      case 'mute':
        return;
      case 'system_click':
        SystemSound.play(SystemSoundType.click);
        return;
      case 'system_alert':
      default:
        SystemSound.play(SystemSoundType.alert);
        return;
    }
  }
}
