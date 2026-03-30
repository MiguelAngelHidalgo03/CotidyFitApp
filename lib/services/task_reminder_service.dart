import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_message_service.dart';
import 'profile_service.dart';
import 'settings_service.dart';

class TaskReminderService {
  TaskReminderService._();

  static final TaskReminderService instance = TaskReminderService._();

  static const _channelId = 'task_reminders';
  static const _channelName = 'Recordatorios de tareas';
  static const _channelDescription =
      'Avisos para tareas con fecha y hora asignadas';
  static const _dailyReminderIdBase = 940100;
  static const _dailyReminderSlots = 45;

    final NotificationMessageService _messageService =
      const NotificationMessageService();
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

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<bool> syncStoredDailyCheckInReminder() async {
    if (kIsWeb) return false;

    final profile = await ProfileService().getProfile();
    final settings = await SettingsService().getSettings();
    final hasConfiguredProfile =
        profile != null &&
        (profile.onboardingCompleted || profile.notificationMinutes != null);

    if (!hasConfiguredProfile) {
      await cancelDailyCheckInReminder();
      return false;
    }

    return syncDailyCheckInReminder(
      minutesFromMidnight: settings.notificationMinutes,
      goal: profile.goal,
    );
  }

  Future<bool> syncDailyCheckInReminder({
    required int minutesFromMidnight,
    String? goal,
  }) async {
    if (kIsWeb) return false;

    await initialize();

    final granted = await _ensureNotificationPermission();
    if (!granted) {
      await cancelDailyCheckInReminder();
      return false;
    }

    final messages = await _messageService.loadActiveDailyMessages();

    await _cancelDailyReminderSeries();

    final first = _nextDailyOccurrence(minutesFromMidnight);
    for (var index = 0; index < _dailyReminderSlots; index++) {
      final scheduledFor = first.add(Duration(days: index));
      final selectedMessage = _messageService.pickRandomDailyMessage(messages);
      await _scheduleOneOffReminder(
        id: _dailyReminderIdBase + index,
        title: selectedMessage.title,
        body: selectedMessage.subtitle,
        scheduledFor: scheduledFor,
        summaryText: 'Recordatorio diario',
        threadIdentifier: 'daily-check-in',
        payload: 'daily-check-in-${scheduledFor.toIso8601String()}',
      );
    }

    final pending = await _plugin.pendingNotificationRequests();
    return pending.any(
      (request) =>
          request.id >= _dailyReminderIdBase &&
          request.id < _dailyReminderIdBase + _dailyReminderSlots,
    );
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

    await _scheduleOneOffReminder(
      id: notificationId,
      title: notificationTitle,
      body: notificationBody,
      scheduledFor: localDate,
      summaryText: expandedBody,
      threadIdentifier: 'task-reminders',
      payload: taskId,
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(_notificationId(taskId));
  }

  Future<void> cancelDailyCheckInReminder() async {
    if (kIsWeb) return;
    await initialize();
    await _cancelDailyReminderSeries();
  }

  Future<bool> _ensureNotificationPermission() async {
    if (kIsWeb) return false;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await android?.areNotificationsEnabled();
    if (androidGranted == false) {
      final requested = await android?.requestNotificationsPermission();
      if (requested == false) return false;
      final recheck = await android?.areNotificationsEnabled();
      if (recheck == false) return false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosGranted == false) return false;

    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final macosGranted = await macos?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (macosGranted == false) return false;

    return true;
  }

  Future<void> _cancelDailyReminderSeries() async {
    for (var index = 0; index < _dailyReminderSlots; index++) {
      await _plugin.cancel(_dailyReminderIdBase + index);
    }
  }

  Future<void> _scheduleOneOffReminder({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledFor,
    required String summaryText,
    required String threadIdentifier,
    required String payload,
  }) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledFor,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          ticker: title,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: summaryText,
          ),
        ),
        iOS: DarwinNotificationDetails(
          subtitle: body,
          threadIdentifier: threadIdentifier,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
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

  tz.TZDateTime _nextDailyOccurrence(int minutesFromMidnight) {
    final clampedMinutes = minutesFromMidnight.clamp(0, 24 * 60 - 1);
    final hour = clampedMinutes ~/ 60;
    final minute = clampedMinutes % 60;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now.add(const Duration(minutes: 1)))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _notificationTitle(String title) {
    final safeTitle = title.trim();
    return safeTitle.isEmpty ? 'Tarea pendiente' : safeTitle;
  }

  String _notificationBody(DateTime dueDate) {
    return _messageService.pickTaskSubtitle(dueDate: dueDate);
  }

  String _expandedNotificationBody(String title, DateTime dueDate) {
    final safeTitle = title.trim();
    return safeTitle.isEmpty
        ? _notificationBody(dueDate)
        : '$safeTitle\n${_notificationBody(dueDate)}';
  }
}
