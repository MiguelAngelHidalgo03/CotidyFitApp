import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../widgets/profile/profile_action_tile.dart';
import '../../widgets/progress/progress_section_card.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacto')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Estamos aquí para ayudarte',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Horario (orientativo): L–V 10:00–18:00',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            ProgressSectionCard(
              child: Column(
                children: [
                  ProfileActionTile(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: 'cotidyfit@gmail.com',
                    onTap: () => _launch(context, Uri.parse('mailto:cotidyfit@gmail.com')),
                  ),
                  const Divider(height: 1),
                  ProfileActionTile(
                    icon: Icons.phone_outlined,
                    title: 'Teléfono',
                    subtitle: '+34 644 595 576',
                    onTap: () => _launch(context, Uri.parse('tel:+34644595576')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Redes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            ProgressSectionCard(
              child: Column(
                children: [
                  ProfileActionTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'Instagram',
                    subtitle: 'Abrir perfil',
                    onTap: () => _launch(context, Uri.parse('https://www.instagram.com/cotidyfit/')),
                  ),
                  const Divider(height: 1),
                  ProfileActionTile(
                    icon: Icons.work_outline,
                    title: 'LinkedIn',
                    subtitle: 'Abrir perfil',
                    onTap: () => _launch(context, Uri.parse('https://www.linkedin.com/company/cotidyfit/')),
                  ),
                  const Divider(height: 1),
                  ProfileActionTile(
                    icon: Icons.ondemand_video_outlined,
                    title: 'YouTube',
                    subtitle: 'Abrir canal',
                    onTap: () => _launch(context, Uri.parse('https://www.youtube.com/channel/UCDqiJDY9mbyR-KXjl0esgXg')),
                  ),
                  const Divider(height: 1),
                  ProfileActionTile(
                    icon: Icons.play_circle_outline,
                    title: 'TikTok',
                    subtitle: 'Abrir perfil',
                    onTap: () => _launch(context, Uri.parse('https://www.tiktok.com/@cotidyfit?lang=es-419')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Si algo no funciona como esperas, incluye capturas y el modelo de tu dispositivo. Responderemos lo antes posible.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
