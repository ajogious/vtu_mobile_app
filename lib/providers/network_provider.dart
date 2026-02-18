// ignore_for_file: unused_field

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _wasOffline = false;
  bool _justReconnected = false;
  ConnectivityResult _connectionType = ConnectivityResult.none;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final Connectivity _connectivity = Connectivity();

  // Reconnect callbacks
  final List<VoidCallback> _reconnectCallbacks = [];

  bool get isOnline => _isOnline;
  bool get justReconnected => _justReconnected;
  ConnectivityResult get connectionType => _connectionType;

  String get connectionLabel {
    switch (_connectionType) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      default:
        return 'No Connection';
    }
  }

  NetworkProvider() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    try {
      // Get initial state
      final results = await _connectivity.checkConnectivity();
      _updateStatus(
        results.isNotEmpty ? results.first : ConnectivityResult.none,
      );

      // Listen for changes
      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        _updateStatus(
          results.isNotEmpty ? results.first : ConnectivityResult.none,
        );
      });
    } catch (e) {
      // Assume online if check fails
      _isOnline = true;
      _connectionType = ConnectivityResult.wifi;
      notifyListeners();
    }
  }

  void _updateStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _connectionType = result;
    _isOnline = result != ConnectivityResult.none;

    // Detect reconnection
    if (!wasOnline && _isOnline) {
      _wasOffline = false;
      _justReconnected = true;
      _triggerReconnectCallbacks();

      // Clear reconnected flag after a short delay
      Future.delayed(const Duration(seconds: 3), () {
        _justReconnected = false;
        notifyListeners();
      });
    } else if (wasOnline && !_isOnline) {
      _wasOffline = true;
      _justReconnected = false;
    }

    notifyListeners();
  }

  /// Register a callback to run when connection is restored
  void onReconnect(VoidCallback callback) {
    _reconnectCallbacks.add(callback);
  }

  /// Remove a callback
  void removeReconnectCallback(VoidCallback callback) {
    _reconnectCallbacks.remove(callback);
  }

  void _triggerReconnectCallbacks() {
    for (final callback in _reconnectCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Reconnect callback error: $e');
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
