import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isInitialized = false;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _refresh();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _setOnline(_hasReachableNetwork(results));
    });
  }

  Future<void> _refresh() async {
    final results = await _connectivity.checkConnectivity();
    _setOnline(_hasReachableNetwork(results));
  }

  bool _hasReachableNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    for (final result in results) {
      if (result != ConnectivityResult.none) return true;
    }
    return false;
  }

  void _setOnline(bool nextValue) {
    if (_isOnline == nextValue) return;
    _isOnline = nextValue;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
