// ignore_for_file: unused_import

import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/notification_item.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  StreamSubscription? _subscription;

  NotificationProvider() {
    _loadNotifications();
    _subscription = NotificationService.onNotificationAdded.stream.listen((_) {
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _loadNotifications() {
    final data = _storageService.getNotifications();
    _notifications = data
        .map((json) => NotificationItem.fromJson(json))
        .toList();
    // Sort by newest first
    _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<void> _saveNotifications() async {
    final data = _notifications.map((n) => n.toJson()).toList();
    await _storageService.saveNotifications(data);
    notifyListeners();
  }

  Future<void> addNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final newItem = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      payload: payload,
      createdAt: DateTime.now(),
    );

    _notifications.insert(0, newItem);
    await _saveNotifications();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      await _saveNotifications();
    }
  }

  Future<void> markAllAsRead() async {
    bool changed = false;
    for (var n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      await _saveNotifications();
    }
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    await _saveNotifications();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _saveNotifications();
  }
}
