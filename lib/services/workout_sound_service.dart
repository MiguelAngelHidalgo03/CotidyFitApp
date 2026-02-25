import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/workout_sound_model.dart';
import 'settings_service.dart';

class WorkoutSoundService {
  WorkoutSoundService({SettingsService? settings})
    : _settings = settings ?? SettingsService();

  final SettingsService _settings;
  static final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.release);

  static const List<WorkoutSoundModel> availableSounds = [
    WorkoutSoundModel(
      id: 'training_bell',
      nombre: 'Training bell',
      sourceType: WorkoutSoundSourceType.asset,
      assetPath: 'sounds/training_bell.wav',
    ),
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
    final settings = await _settings.getSettings();
    if (!settings.workoutEndSoundEnabled) return;
    final id = settings.workoutEndSoundId;
    await playById(id);
  }

  Future<void> playById(String id) async {
    switch (id) {
      case 'training_bell':
        await _player.stop();
        await _player.play(AssetSource('sounds/training_bell.wav'));
        return;
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
