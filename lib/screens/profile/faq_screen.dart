import 'package:flutter/material.dart';

import '../../widgets/progress/progress_section_card.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = const <({String q, String a})>[
      (
        q: '¿Qué es CotidyFit?',
        a: 'CotidyFit es una app de hábitos y entrenamiento que te ayuda a planificar tu semana, registrar tu progreso y mantener consistencia con un enfoque profesional y minimalista.',
      ),
      (
        q: '¿Necesito gimnasio?',
        a: 'No. Puedes entrenar en casa o en gimnasio. En tu perfil puedes indicar el lugar habitual y el tiempo disponible para adaptar el plan.',
      ),
      (
        q: '¿Cómo se calcula el Índice CF?',
        a: 'El Índice CF es un indicador interno de consistencia y cumplimiento. Se calcula a partir de tus registros y objetivos. La fórmula exacta puede evolucionar para mejorar su precisión.',
      ),
      (
        q: '¿Qué incluye Premium?',
        a: 'Premium añade funcionalidades avanzadas y acceso a herramientas extra. En esta versión, la suscripción se muestra a nivel UI y puede activarse más adelante sin cambiar tu historial.',
      ),
      (
        q: '¿Puedo cancelar Premium?',
        a: 'Sí. Cuando Premium esté disponible, podrás cancelarlo desde la tienda correspondiente. La app mantendrá tu información local y tu perfil.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Preguntas frecuentes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            for (final it in items) ...[
              ProgressSectionCard(
                padding: const EdgeInsets.all(0),
                child: ExpansionTile(
                  title: Text(
                    it.q,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(it.a, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
