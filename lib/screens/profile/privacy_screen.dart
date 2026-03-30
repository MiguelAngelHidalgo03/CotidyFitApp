import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/progress/progress_section_card.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sections = <({String title, String body})>[
      (
        title: '1. Responsable y contacto',
        body:
            'CotidyFit trata los datos personales necesarios para prestar la app, mejorar la experiencia y mantener sus funciones operativas. Para consultas sobre privacidad o ejercicio de derechos puedes escribir a cotidyfit@gmail.com.',
      ),
      (
        title: '2. Qué datos puede tratar la app',
        body:
            'Según las funciones que utilices, CotidyFit puede tratar datos de cuenta e identificación, datos de perfil, objetivos, horarios, hábitos, progreso, mensajes en comunidad, contenido compartido, preferencias de app, permisos concedidos y datos técnicos mínimos de funcionamiento y seguridad.',
      ),
      (
        title: '3. Para qué se usan tus datos',
        body:
            'Se usan para crear y mantener tu perfil, guardar tu progreso, mostrar funciones personalizadas, programar recordatorios, ofrecer comunidad, sincronizar información entre dispositivos cuando corresponda, prevenir abusos y mejorar la estabilidad y seguridad del servicio.',
      ),
      (
        title: '4. Base jurídica',
        body:
            'El tratamiento se apoya, según el caso, en la ejecución del servicio que solicitas al usar la app, en tu consentimiento para permisos o funcionalidades opcionales y en el interés legítimo de mantener la seguridad, integridad y correcto funcionamiento de CotidyFit.',
      ),
      (
        title: '5. Con quién pueden compartirse',
        body:
            'Tus datos no se venden. Pueden intervenir proveedores tecnológicos necesarios para autenticación, base de datos, almacenamiento, notificaciones, hosting o soporte técnico, así como autoridades u organismos cuando exista obligación legal.',
      ),
      (
        title: '6. Conservación',
        body:
            'Los datos se conservan mientras exista relación activa con la app o mientras sean necesarios para la finalidad para la que fueron recogidos. Si solicitas baja o eliminación, se suprimirán o bloquearán cuando proceda, salvo obligaciones legales o necesidades de defensa ante reclamaciones.',
      ),
      (
        title: '7. Tus derechos',
        body:
            'Puedes solicitar acceso, rectificación, supresión, oposición, limitación del tratamiento y, cuando proceda, portabilidad. También puedes retirar permisos del dispositivo o dejar de usar funciones concretas. Para tramitarlo, contacta por email indicando tu solicitud y el contexto necesario para localizar tu cuenta.',
      ),
      (
        title: '8. Comunidad y visibilidad',
        body:
            'Si participas en espacios sociales, parte del contenido que publiques puede ser visible para otros usuarios según la configuración de privacidad y el tipo de sección. Evita compartir datos sensibles innecesarios en mensajes, grupos o publicaciones.',
      ),
      (
        title: '9. Seguridad',
        body:
            'CotidyFit aplica medidas técnicas y organizativas razonables para proteger la información frente a accesos no autorizados, pérdida, alteración o uso indebido. Aun así, ningún sistema conectado puede garantizar seguridad absoluta.',
      ),
      (
        title: '10. Menores y cambios',
        body:
            'La app no debe utilizarse sin supervisión adecuada cuando legalmente sea necesaria. Esta política puede actualizarse para reflejar cambios técnicos, funcionales o legales. Si el cambio es relevante, se informará dentro de la app o por los medios disponibles.',
      ),
    ];

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
            Text(
              'Última actualización: 27/03/2026',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.cfTextSecondary),
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
                        color: context.cfTextSecondary,
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
