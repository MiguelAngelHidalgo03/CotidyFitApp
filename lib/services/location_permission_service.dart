import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionService {
  static Future<LocationPermission>? _inFlight;

  /// Checks current location permission and requests it if needed.
  ///
  /// This method serializes permission prompts to avoid overlapping dialogs
  /// when multiple parts of the app request permissions at startup.
  static Future<LocationPermission> ensurePermission() {
    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _ensurePermissionInternal();
    _inFlight = future.whenComplete(() {
      _inFlight = null;
    });
    return _inFlight!;
  }

  static Future<LocationPermission> _ensurePermissionInternal() async {
    if (kIsWeb) {
      // On web, browser handles permissions.
      return Geolocator.checkPermission();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }
}
