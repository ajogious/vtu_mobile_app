import 'dart:async';
import 'package:flutter/material.dart';

class PerformanceUtils {
  /// Debounce for search fields — prevents rebuilds on every keystroke.
  static Timer? _debounceTimer;

  static void debounce(
    VoidCallback action, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, action);
  }

  /// Cancel any pending debounce timer (e.g. on dispose).
  static void cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
