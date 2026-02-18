import 'package:flutter/material.dart';
import '../services/storage_service.dart';

enum AutoLockDuration { immediate, oneMinute, fiveMinutes, never }

class AppLockProvider with ChangeNotifier {
  bool _isLocked = false;
  DateTime? _backgroundedAt;
  AutoLockDuration _autoLockDuration = AutoLockDuration.oneMinute;
  DateTime? _lastActivityTime;
  static const Duration _sessionTimeout = Duration(minutes: 30);

  bool get isLocked => _isLocked;
  AutoLockDuration get autoLockDuration => _autoLockDuration;

  AppLockProvider() {
    _loadSettings();
    _lastActivityTime = DateTime.now();
  }

  void _loadSettings() {
    final storage = StorageService();
    final durationIndex = storage.getAutoLockDuration();
    _autoLockDuration = AutoLockDuration.values[durationIndex];
  }

  Future<void> setAutoLockDuration(AutoLockDuration duration) async {
    _autoLockDuration = duration;
    final storage = StorageService();
    await storage.saveAutoLockDuration(duration.index);
    notifyListeners();
  }

  // Called when app goes to background
  void onAppBackground() {
    _backgroundedAt = DateTime.now();
  }

  // Called when app comes to foreground
  void onAppForeground() {
    if (_backgroundedAt == null) return;
    if (_autoLockDuration == AutoLockDuration.never) return;

    final now = DateTime.now();
    final backgroundDuration = now.difference(_backgroundedAt!);

    bool shouldLock = false;

    switch (_autoLockDuration) {
      case AutoLockDuration.immediate:
        shouldLock = true;
        break;
      case AutoLockDuration.oneMinute:
        shouldLock = backgroundDuration.inMinutes >= 1;
        break;
      case AutoLockDuration.fiveMinutes:
        shouldLock = backgroundDuration.inMinutes >= 5;
        break;
      case AutoLockDuration.never:
        shouldLock = false;
        break;
    }

    if (shouldLock) {
      lock();
    }

    _backgroundedAt = null;
  }

  // Update activity time
  void updateActivity() {
    _lastActivityTime = DateTime.now();
  }

  // Check for session timeout
  bool checkSessionTimeout() {
    if (_lastActivityTime == null) return false;
    if (_autoLockDuration == AutoLockDuration.never) return false;

    final now = DateTime.now();
    final inactivity = now.difference(_lastActivityTime!);

    if (inactivity >= _sessionTimeout) {
      lock();
      return true;
    }

    return false;
  }

  void lock() {
    _isLocked = true;
    notifyListeners();
  }

  void unlock() {
    _isLocked = false;
    _lastActivityTime = DateTime.now();
    notifyListeners();
  }

  String getAutoLockLabel(AutoLockDuration duration) {
    switch (duration) {
      case AutoLockDuration.immediate:
        return 'Immediately';
      case AutoLockDuration.oneMinute:
        return 'After 1 minute';
      case AutoLockDuration.fiveMinutes:
        return 'After 5 minutes';
      case AutoLockDuration.never:
        return 'Never';
    }
  }
}
