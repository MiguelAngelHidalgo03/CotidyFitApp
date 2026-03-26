import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class TaskReminderService {
  TaskReminderService._();

  static final TaskReminderService instance = TaskReminderService._();

  static const _channelId = 'task_reminders';
  static const _channelName = 'Recordatorios de tareas';
  static const _channelDescription =
      'Avisos para tareas con fecha y hora asignadas';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Future<void>? _initializeFuture;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializeFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    tz.initializeTimeZones();
    await _configureLocalTimezone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> syncTaskReminder({
    required String taskId,
    required String title,
    required DateTime? dueDate,
    required bool enabled,
    required bool completed,
  }) async {
    if (kIsWeb) return;

    await initialize();

    final notificationId = _notificationId(taskId);
    if (!enabled || completed || dueDate == null) {
      await _plugin.cancel(notificationId);
      return;
    }

    final scheduledFor = dueDate;
    final minimumLead = DateTime.now().add(const Duration(minutes: 1));
    if (!scheduledFor.isAfter(minimumLead)) {
      await _plugin.cancel(notificationId);
      return;
    }

    final localDate = tz.TZDateTime.from(scheduledFor, tz.local);
    final notificationTitle = _notificationTitle(title);
    final notificationBody = _notificationBody(scheduledFor);
    final expandedBody = _expandedNotificationBody(title, scheduledFor);

    await _plugin.zonedSchedule(
      notificationId,
      notificationTitle,
      notificationBody,
      localDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          ticker: notificationTitle,
          styleInformation: BigTextStyleInformation(
            expandedBody,
            contentTitle: notificationTitle,
            summaryText: 'CotidyFit',
          ),
        ),
        iOS: DarwinNotificationDetails(
          subtitle: notificationBody,
          threadIdentifier: 'task-reminders',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: taskId,
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(_notificationId(taskId));
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  int _notificationId(String taskId) {
    var hash = 0;
    for (final codeUnit in taskId.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  String _notificationTitle(String title) {
    final safeTitle = title.trim();
    return safeTitle.isEmpty ? 'Tarea pendiente' : safeTitle;
  }

  String _notificationBody(DateTime dueDate) {
    final timeLabel = _timeLabel(dueDate);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final tomorrowDate = todayDate.add(const Duration(days: 1));
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDateOnly == todayDate) {
      return 'Recordatorio de tarea · Hoy a las $timeLabel';
    }
    if (dueDateOnly == tomorrowDate) {
      return 'Recordatorio de tarea · Mañana a las $timeLabel';
    }
    return 'Recordatorio de tarea · ${_dateLabel(dueDate)} a las $timeLabel';
  }

  String _expandedNotificationBody(String title, DateTime dueDate) {
    final safeTitle = title.trim();
    final lead = safeTitle.isEmpty
        ? 'Tienes una tarea pendiente en CotidyFit.'
        : 'No olvides: $safeTitle.';
    return '$lead\n${_notificationBody(dueDate)}';
  }

  String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _timeLabel(DateTime value) {
    final hours = value.hour.toString().padLeft(2, '0');
    final minutes = value.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}
