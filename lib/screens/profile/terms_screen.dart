import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/progress/progress_section_card.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Términos')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Términos de uso',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ProgressSectionCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Este texto es un placeholder profesional.\n\n'
                '1) CotidyFit no sustituye asesoramiento médico. Consulta con un profesional de la salud ante cualquier duda, lesión o condición preexistente.\n\n'
                '2) Uso responsable. Eres responsable de seguir las recomendaciones de forma segura, ajustar intensidades y detenerte si hay dolor o mareo.\n\n'
                '3) Contenido y cambios. La app puede actualizar funcionalidades y textos para mejorar la experiencia.\n\n'
                '4) Datos y solicitudes. Puedes solicitar la eliminación de tus datos según lo indicado en Política de privacidad.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
