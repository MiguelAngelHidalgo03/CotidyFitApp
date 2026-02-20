import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/progress/progress_section_card.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Política de privacidad',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Este texto es un placeholder profesional.\n\n'
                'RGPD: tratamos los datos con un enfoque de minimización y finalidad.\n\n'
                'Datos locales: en esta versión, la información se guarda localmente en tu dispositivo (sin Firebase).\n\n'
                'Eliminación: puedes solicitar eliminación de datos. Si la información está solo en el dispositivo, podrás borrarla limpiando los datos de la app o mediante la opción disponible cuando exista backend.\n\n'
                'Uso responsable: no compartas información sensible innecesaria.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
