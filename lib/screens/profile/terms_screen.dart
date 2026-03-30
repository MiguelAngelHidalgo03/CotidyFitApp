import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/progress/progress_section_card.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sections = <({String title, String body})>[
      (
        title: '1. Objeto del servicio',
        body:
            'CotidyFit es una app orientada a organización personal, hábitos, seguimiento de progreso, contenido de entrenamiento, nutrición y comunidad. Su finalidad es ayudarte a mantener constancia y ordenar tu rutina, no sustituir atención profesional individualizada.',
      ),
      (
        title: '2. Uso permitido',
        body:
            'Debes utilizar la app de forma personal, lícita y respetuosa. No está permitido manipular el servicio, acceder sin autorización a datos ajenos, automatizar abusivamente acciones, compartir contenido ilícito o usar la comunidad para acoso, spam o suplantación.',
      ),
      (
        title: '3. Cuenta y acceso',
        body:
            'Eres responsable de la seguridad de tu cuenta, del dispositivo desde el que accedes y de mantener actualizados tus datos básicos cuando sean necesarios para el correcto funcionamiento de la app.',
      ),
      (
        title: '4. Salud y responsabilidad personal',
        body:
            'La información ofrecida en CotidyFit es general y no equivale a diagnóstico médico, prescripción sanitaria ni tratamiento nutricional personalizado. Si tienes dolor, lesión, enfermedad, embarazo, limitaciones físicas o dudas relevantes, debes consultar con un profesional sanitario antes de seguir recomendaciones de ejercicio o alimentación.',
      ),
      (
        title: '5. Recordatorios y notificaciones',
        body:
            'La app puede programar recordatorios locales y enviar comunicaciones relacionadas con el uso del servicio. La recepción efectiva depende de que el usuario mantenga activos los permisos de notificación y de las restricciones del sistema operativo del dispositivo.',
      ),
      (
        title: '6. Comunidad y contenido generado por usuarios',
        body:
            'Si publicas mensajes, sugerencias o contenido en áreas sociales, sigues siendo responsable de lo que compartes. CotidyFit podrá moderar, ocultar o eliminar contenido cuando detecte incumplimientos, abuso, riesgo para otros usuarios o uso contrario a estas condiciones.',
      ),
      (
        title: '7. Propiedad intelectual',
        body:
            'El diseño de la app, la marca CotidyFit, los textos, la estructura, las imágenes propias y el contenido desarrollado para el servicio están protegidos por la normativa aplicable. No puedes copiar, revender, redistribuir ni explotar el servicio o su contenido sin autorización previa.',
      ),
      (
        title: '8. Funciones de pago o Premium',
        body:
            'CotidyFit puede incorporar funciones Premium o de pago en versiones futuras. En ese caso, las condiciones económicas, duración, renovación y cancelación se informarán de forma clara antes de la contratación. Mientras no exista contratación efectiva, la mera presencia de elementos visuales de Premium no implica acceso garantizado.',
      ),
      (
        title: '9. Disponibilidad y cambios',
        body:
            'CotidyFit puede actualizar, mejorar, limitar o retirar funciones cuando resulte necesario por motivos técnicos, operativos, legales o de seguridad. Se intentará evitar interrupciones innecesarias, pero no se garantiza disponibilidad absoluta e ininterrumpida.',
      ),
      (
        title: '10. Suspensión o baja',
        body:
            'CotidyFit podrá suspender o limitar el acceso si detecta incumplimientos, fraude, uso abusivo, riesgos de seguridad o conductas que perjudiquen a otros usuarios o al servicio. El usuario puede dejar de utilizar la app en cualquier momento y solicitar la eliminación de cuenta cuando esté disponible esa opción o por contacto directo.',
      ),
      (
        title: '11. Contacto',
        body:
            'Para dudas sobre uso, condiciones, incidencias o ejercicio de derechos relacionados con la cuenta puedes escribir a cotidyfit@gmail.com.',
      ),
    ];

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
            Text(
              'Última actualización: 27/03/2026',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CFColors.textSecondary),
            ),
            const SizedBox(height: 12),
            for (final section in sections) ...[
              ProgressSectionCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section.body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CFColors.textSecondary,
                        height: 1.45,
                      ),
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
