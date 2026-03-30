import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class DailyNotificationMessage {
  const DailyNotificationMessage({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.order,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool isActive;
  final int order;
}

class NotificationMessageService {
  const NotificationMessageService();

  static const _collection = 'daily_notifications_messages';

  static const DailyNotificationMessage fallbackDailyMessage =
      DailyNotificationMessage(
        id: 'fallback_daily_notification',
        title: 'Tu día te espera',
        subtitle: 'Entra en CotidyFit y deja marcado tu progreso.',
        isActive: true,
        order: 1,
      );

  static const List<String> taskTodaySubtitles = [
    'Te lo dejaste listo para hoy.',
    'Un momento ahora y te lo quitas.',
    'Tu tarea de CotidyFit te espera.',
    'Es un buen rato para empezar.',
    'No la dejes para más tarde.',
    'Un paso más y la dejas hecha.',
    'Tu plan de hoy sigue aquí.',
    'Vamos a cerrar esto hoy.',
  ];

  static const List<String> taskOverdueSubtitles = [
    'Se movió el día, no el objetivo.',
    'Todavía puedes cerrarlo hoy.',
    'Retómalo ahora y vuelves al ritmo.',
    'Llegas a tiempo de dejarlo hecho.',
  ];

  Future<List<DailyNotificationMessage>> loadActiveDailyMessages() async {
    if (Firebase.apps.isEmpty) {
      return const [fallbackDailyMessage];
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .orderBy('order')
          .get();
      final items = snap.docs
          .map((doc) => _fromMap(doc.id, doc.data()))
          .whereType<DailyNotificationMessage>()
          .where((item) => item.isActive)
          .toList(growable: false);
      if (items.isNotEmpty) return items;
    } catch (_) {
      // fallback below
    }

    return const [fallbackDailyMessage];
  }

  DailyNotificationMessage pickRandomDailyMessage(
    List<DailyNotificationMessage> items, {
    Random? random,
  }) {
    final safeItems = items.where((item) => item.isActive).toList(growable: false);
    if (safeItems.isEmpty) return fallbackDailyMessage;
    final generator = random ?? Random();
    return safeItems[generator.nextInt(safeItems.length)];
  }

  String pickTaskSubtitle({
    required DateTime dueDate,
    DateTime? now,
    Random? random,
  }) {
    final today = DateTime.now();
    final baseNow = now ?? today;
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final todayOnly = DateTime(baseNow.year, baseNow.month, baseNow.day);
    final pool = dueDateOnly.isBefore(todayOnly)
        ? taskOverdueSubtitles
        : taskTodaySubtitles;
    final generator = random ?? Random();
    return pool[generator.nextInt(pool.length)];
  }

  DailyNotificationMessage? _fromMap(String id, Map<String, dynamic>? raw) {
    final data = raw ?? const <String, dynamic>{};
    final title = _trimAndLimit(data['title'], 40);
    final subtitle = _trimAndLimit(data['subtitle'], 90);
    if (title.isEmpty || subtitle.isEmpty) return null;
    final order = _asInt(data['order'], fallback: 9999);
    final isActive = data['is_active'] == true || data['isActive'] == true;
    return DailyNotificationMessage(
      id: id,
      title: title,
      subtitle: subtitle,
      isActive: isActive,
      order: order,
    );
  }

  int _asInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _trimAndLimit(Object? value, int maxChars) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return '';
    return text.length <= maxChars ? text : text.substring(0, maxChars).trim();
  }
}