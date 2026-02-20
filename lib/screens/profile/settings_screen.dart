import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/user_settings.dart';
import '../../services/settings_service.dart';
import 'blocked_contacts_screen.dart';
import '../../widgets/profile/profile_action_tile.dart';
import '../../widgets/progress/progress_section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = SettingsService();
  UserSettings? _settings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await _service.getSettings();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _loading = false;
    });
  }

  Future<void> _save(UserSettings s) async {
    await _service.saveSettings(s);
    if (!mounted) return;
    setState(() => _settings = s);
  }

  Future<void> _pickNotificationTime() async {
    final settings = _settings;
    if (settings == null) return;
    final initial = TimeOfDay(
      hour: settings.notificationMinutes ~/ 60,
      minute: settings.notificationMinutes % 60,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    await _save(
      settings.copyWith(notificationMinutes: picked.hour * 60 + picked.minute),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: _loading || s == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
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
                          subtitle: s.privacyMode ? 'No visible' : 'Visible',
                          trailing: Switch(
                            value: !s.privacyMode,
                            activeThumbColor: CFColors.primary,
                            onChanged: (v) =>
                                _save(s.copyWith(privacyMode: !v)),
                          ),
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        ProfileActionTile(
                          icon: Icons.block_outlined,
                          title: 'Contactos bloqueados',
                          subtitle: 'Gestiona a quién bloqueaste',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const BlockedContactsScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ProfileActionTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'Hora notificaciones',
                          subtitle: TimeOfDay(
                            hour: s.notificationMinutes ~/ 60,
                            minute: s.notificationMinutes % 60,
                          ).format(context),
                          onTap: _pickNotificationTime,
                        ),
                        const Divider(height: 1),
                        ProfileActionTile(
                          icon: Icons.volume_up_outlined,
                          title: 'Sonido entrenamiento',
                          subtitle: s.workoutEndSoundEnabled
                              ? 'Activado'
                              : 'Desactivado',
                          trailing: Switch(
                            value: s.workoutEndSoundEnabled,
                            activeThumbColor: CFColors.primary,
                            onChanged: (v) =>
                                _save(s.copyWith(workoutEndSoundEnabled: v)),
                          ),
                          onTap: () => _save(
                            s.copyWith(
                              workoutEndSoundEnabled: !s.workoutEndSoundEnabled,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ProfileActionTile(
                          icon: Icons.language_outlined,
                          title: 'Idioma',
                          subtitle: s.language == AppLanguage.es
                              ? 'Español'
                              : 'English',
                          onTap: () => _toast('Inglés: próximamente'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
