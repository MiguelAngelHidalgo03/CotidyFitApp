import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:shared_preferences/shared_preferences.dart';

import 'health_service.dart';

enum AppPermissionStatus { granted, notRequested, denied, unavailable }

class AppPermissionsSnapshot {
  const AppPermissionsSnapshot({
    required this.notifications,
    required this.location,
    required this.steps,
  });

  final AppPermissionStatus notifications;
  final AppPermissionStatus location;
  final AppPermissionStatus steps;

  bool get hasMissingRequiredPermissions =>
      _isMissingRequiredPermission(notifications) ||
      _isMissingRequiredPermission(location);
}

class AppPermissionsService {
  AppPermissionsService({
    FirebaseMessaging? messaging,
    Future<SharedPreferences> Function()? prefsLoader,
    HealthService? healthService,
  }) : _messagingOverride = messaging,
       _prefsLoader = prefsLoader,
       _healthServiceOverride = healthService;

  static const _kStartupPromptHandledKey =
      'cf_startup_permissions_prompt_handled_v1';

  final FirebaseMessaging? _messagingOverride;
  final Future<SharedPreferences> Function()? _prefsLoader;
  final HealthService? _healthServiceOverride;

  HealthService get _healthService => _healthServiceOverride ?? HealthService();

  FirebaseMessaging? get _messaging {
    final override = _messagingOverride;
    if (override != null) return override;
    if (Firebase.apps.isEmpty) return null;
    return FirebaseMessaging.instance;
  }

  Future<SharedPreferences> _prefs() {
    final loader = _prefsLoader;
    if (loader != null) return loader();
    return SharedPreferences.getInstance();
  }

  Future<AppPermissionsSnapshot> getSnapshot() async {
    final notifications = await _notificationStatus();
    final location = await _locationStatus();
    final steps = await _stepsStatus();
    return AppPermissionsSnapshot(
      notifications: notifications,
      location: location,
      steps: steps,
    );
  }

  Future<AppPermissionsSnapshot> requestStartupPermissions() async {
    await requestNotificationPermission();
    await requestLocationPermission();
    await requestStepsPermission();
    await markStartupPromptHandled();
    return getSnapshot();
  }

  Future<bool> shouldShowStartupPrompt() async {
    if (!_supportsMobilePermissionPrompts) {
      return false;
    }

    final prefs = await _prefs();
    final handled = prefs.getBool(_kStartupPromptHandledKey) ?? false;
    if (handled) return false;

    final snapshot = await getSnapshot();
    return snapshot.hasMissingRequiredPermissions;
  }

  Future<void> markStartupPromptHandled() async {
    if (!_supportsMobilePermissionPrompts) return;
    final prefs = await _prefs();
    await prefs.setBool(_kStartupPromptHandledKey, true);
  }

  Future<AppPermissionStatus> requestNotificationPermission() async {
    if (!_supportsMobilePermissionPrompts) {
      return AppPermissionStatus.unavailable;
    }

    final messaging = _messaging;
    if (messaging == null) return AppPermissionStatus.unavailable;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      return _mapNotificationStatus(settings.authorizationStatus);
    } catch (_) {
      return AppPermissionStatus.unavailable;
    }
  }

  Future<AppPermissionStatus> requestLocationPermission() async {
    if (!_supportsMobilePermissionPrompts) {
      return AppPermissionStatus.unavailable;
    }

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return _mapLocationPermission(permission);
    } catch (_) {
      return AppPermissionStatus.unavailable;
    }
  }

  Future<AppPermissionStatus> requestStepsPermission() async {
    if (!_supportsMobilePermissionPrompts) {
      return AppPermissionStatus.unavailable;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        var mappedActivityStatus = _mapActivityPermissionStatus(
          await permission_handler.Permission.activityRecognition.status,
        );
        if (mappedActivityStatus != AppPermissionStatus.granted) {
          final activityStatus = await permission_handler
              .Permission
              .activityRecognition
              .request();
          mappedActivityStatus = _mapActivityPermissionRequestStatus(
            activityStatus,
          );
        }
        if (mappedActivityStatus != AppPermissionStatus.granted) {
          return mappedActivityStatus;
        }

        final healthConnectAvailable = await _healthService
            .isHealthConnectAvailable();
        if (!healthConnectAvailable) {
          await _healthService.installHealthConnect();
          return AppPermissionStatus.unavailable;
        }
      }

      final existingPermission = await _healthService.hasStepsPermission();
      if (existingPermission == true) {
        return AppPermissionStatus.granted;
      }

      final granted = await _healthService.requestStepsPermission();
      return granted ? AppPermissionStatus.granted : AppPermissionStatus.denied;
    } catch (_) {
      return AppPermissionStatus.unavailable;
    }
  }

  bool get _supportsMobilePermissionPrompts {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  Future<AppPermissionStatus> _notificationStatus() async {
    if (!_supportsMobilePermissionPrompts) {
      return AppPermissionStatus.unavailable;
    }

    final messaging = _messaging;
    if (messaging == null) return AppPermissionStatus.unavailable;

    try {
      final settings = await messaging.getNotificationSettings();
      return _mapNotificationStatus(settings.authorizationStatus);
    } catch (_) {
      return AppPermissionStatus.unavailable;
    }
  }

  Future<AppPermissionStatus> _locationStatus() async {
    if (!_supportsMobilePermissionPrompts) {
      return AppPermissionStatus.unavailable;
    }

    try {
      final permission = await Geolocator.checkPermission();
      return _mapLocationPermission(permission);
    } catch (_) {
      return AppPermissionStatus.unavailable;
    }
  }

  Future<AppPermissionStatus> _stepsStatus() async {
    if (!_supportsMobilePermissionPrompts) {
      return AppPermissionStatus.unavailable;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final activityStatus =
            await permission_handler.Permission.activityRecognition.status;
        final mappedActivityStatus = _mapActivityPermissionStatus(
          activityStatus,
        );
        if (mappedActivityStatus != AppPermissionStatus.granted) {
          return mappedActivityStatus;
        }

        final healthConnectAvailable = await _healthService
            .isHealthConnectAvailable();
        if (!healthConnectAvailable) {
          return AppPermissionStatus.unavailable;
        }
      }

      final granted = await _healthService.hasStepsPermission();
      if (granted == null) {
        return defaultTargetPlatform == TargetPlatform.iOS
            ? AppPermissionStatus.notRequested
            : AppPermissionStatus.unavailable;
      }
      return granted
          ? AppPermissionStatus.granted
          : AppPermissionStatus.notRequested;
    } catch (_) {
      return AppPermissionStatus.unavailable;
    }
  }

  AppPermissionStatus _mapNotificationStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return AppPermissionStatus.granted;
      case AuthorizationStatus.denied:
        return AppPermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
        return AppPermissionStatus.notRequested;
    }
  }

  AppPermissionStatus _mapLocationPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return AppPermissionStatus.granted;
      case LocationPermission.denied:
        return AppPermissionStatus.notRequested;
      case LocationPermission.deniedForever:
        return AppPermissionStatus.denied;
      case LocationPermission.unableToDetermine:
        return AppPermissionStatus.unavailable;
    }
  }

  AppPermissionStatus _mapActivityPermissionStatus(
    permission_handler.PermissionStatus status,
  ) {
    if (status.isGranted) return AppPermissionStatus.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return AppPermissionStatus.denied;
    }
    return AppPermissionStatus.notRequested;
  }

  AppPermissionStatus _mapActivityPermissionRequestStatus(
    permission_handler.PermissionStatus status,
  ) {
    if (status.isGranted) return AppPermissionStatus.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return AppPermissionStatus.denied;
    }
    return AppPermissionStatus.denied;
  }
}

bool _isMissingRequiredPermission(AppPermissionStatus status) {
  switch (status) {
    case AppPermissionStatus.granted:
    case AppPermissionStatus.unavailable:
      return false;
    case AppPermissionStatus.notRequested:
    case AppPermissionStatus.denied:
      return true;
  }
}
