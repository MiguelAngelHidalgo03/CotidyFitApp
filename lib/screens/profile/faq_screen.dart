import 'package:flutter/material.dart';

import '../../widgets/progress/progress_section_card.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = const <({String q, String a})>[
      (
        q: '¿Para qué sirve CotidyFit?',
        a: 'CotidyFit te ayuda a sostener hábitos de entrenamiento, nutrición y constancia desde una sola app. Puedes organizar tu semana, registrar progreso, seguir metas y mantener el foco sin depender de hojas sueltas o varias apps separadas.',
      ),
      (
        q: '¿Necesito experiencia previa o gimnasio?',
        a: 'No. La app está pensada tanto para quien empieza como para quien ya entrena. Puedes usarla si entrenas en casa, en gimnasio o combinando ambos, y adaptar objetivos según el tiempo real que tienes.',
      ),
      (
        q: '¿Qué puedo registrar dentro de la app?',
        a: 'Puedes llevar seguimiento de hábitos, tareas, progreso semanal, logros, recetas, plantillas nutricionales y actividad general. La idea es que tengas una visión práctica de tu rutina y no solo números aislados.',
      ),
      (
        q: '¿Cómo funcionan las notificaciones?',
        a: 'La hora de notificaciones programa un recordatorio diario en tu móvil para que vuelvas a la app y revises tus hábitos del día. Además, las tareas con fecha y hora pueden generar avisos propios si los permisos del dispositivo están concedidos.',
      ),
      (
        q: '¿Mis datos y mi perfil son públicos?',
        a: 'No por defecto. Puedes decidir si tu perfil se muestra en Comunidad y también gestionar contactos bloqueados. CotidyFit intenta mantener separados los datos de uso interno y la parte social visible dentro de la app.',
      ),
      (
        q: '¿Qué puedo hacer en Comunidad?',
        a: 'En Comunidad puedes participar en grupos temáticos, leer novedades, compartir mensajes y mantener contacto con otras personas de la app, siempre dentro de las normas de respeto y uso responsable.',
      ),
      (
        q: '¿CotidyFit sustituye a un profesional sanitario?',
        a: 'No. CotidyFit no sustituye diagnóstico, tratamiento ni seguimiento médico, nutricional o psicológico individual. Si tienes lesión, dolor, embarazo, patología o una condición relevante, debes consultar con un profesional cualificado antes de seguir recomendaciones físicas o nutricionales.',
      ),
      (
        q: '¿Qué pasa con Premium?',
        a: 'La app puede mostrar apartados o referencias a funciones Premium, pero su disponibilidad real puede variar según la versión publicada. Si en el futuro se activa una suscripción, se informará de sus condiciones antes de contratar.',
      ),
      (
        q: '¿Puedo borrar mi cuenta o pedir que eliminen mis datos?',
        a: 'Sí. Puedes usar las opciones disponibles dentro de la app o escribir a cotidyfit@gmail.com para solicitar ayuda con la eliminación de cuenta, acceso, rectificación o supresión de datos, según corresponda.',
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
