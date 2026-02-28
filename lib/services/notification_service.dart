import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/transaction_model.dart';
import 'storage_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final StreamController<void> onNotificationAdded =
      StreamController<void>.broadcast();

  static bool _initialized = false;

  // Notification IDs
  static const int _transactionSuccessId = 1;
  static const int _transactionFailedId = 2;
  static const int _walletCreditedId = 3;
  static const int _lowBalanceId = 4;
  static const int _atcStatusId = 5;
  static const int _referralEarningId = 6;

  // Channel IDs
  static const String _transactionChannel = 'transaction_channel';
  static const String _walletChannel = 'wallet_channel';
  static const String _alertChannel = 'alert_channel';

  static Future<void> init() async {
    if (_initialized) return;

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels
    await _createChannels();

    _initialized = true;
  }

  static Future<void> _createChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return;

    // Transaction channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _transactionChannel,
        'Transactions',
        description: 'Purchase and transaction notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Wallet channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _walletChannel,
        'Wallet',
        description: 'Wallet funding and balance alerts',
        importance: Importance.high,
        playSound: true,
      ),
    );

    // Alert channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _alertChannel,
        'Alerts',
        description: 'Important account alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  static Future<bool> requestPermissions() async {
    // iOS
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    // Android 13+
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  // ─── Core Show Method ──────────────────────────────────────────────────────

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    String channelId = _transactionChannel,
    String? payload,
    bool isAlert = false,
  }) async {
    if (!_initialized) await init();

    // Check if notification type is enabled in settings
    final storage = StorageService();

    // Check preference for channel type
    if (channelId == _transactionChannel &&
        !storage.getNotificationPreference('transactions')) {
      return;
    }
    if (channelId == _walletChannel &&
        !storage.getNotificationPreference('wallet')) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _transactionChannel
          ? 'Transactions'
          : channelId == _walletChannel
          ? 'Wallet'
          : 'Alerts',
      channelDescription: 'VTU App notifications',
      importance: isAlert ? Importance.max : Importance.high,
      priority: isAlert ? Priority.max : Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(body),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );

    // Save to local storage for in-app display
    final data = storage.getNotifications();
    final newItem = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'body': body,
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': false,
      'payload': payload,
    };
    data.insert(0, newItem);
    await storage.saveNotifications(data);
    onNotificationAdded.add(null);
  }

  // ─── Transaction Notifications ─────────────────────────────────────────────

  static Future<void> transactionSuccess(Transaction transaction) async {
    final amount = NumberFormat('#,##0.00').format(transaction.amount);
    final title = _getSuccessTitle(transaction.type);
    final body = _getSuccessBody(transaction, amount);

    await _show(
      id: _transactionSuccessId,
      title: title,
      body: body,
      channelId: _transactionChannel,
      payload: 'transaction:${transaction.id}',
    );
  }

  static Future<void> transactionFailed({
    required TransactionType type,
    required String reason,
    double? amount,
  }) async {
    final title = '${_getTypeLabel(type)} Failed';
    final body = reason.isNotEmpty
        ? reason
        : 'Your transaction could not be completed. Please try again.';

    await _show(
      id: _transactionFailedId,
      title: title,
      body: body,
      channelId: _transactionChannel,
      isAlert: true,
    );
  }

  static Future<void> walletCredited(double amount, String source) async {
    final formatted = NumberFormat('#,##0.00').format(amount);
    await _show(
      id: _walletCreditedId,
      title: '💰 Wallet Credited',
      body: '₦$formatted has been added to your wallet from $source.',
      channelId: _walletChannel,
    );
  }

  static Future<void> lowBalance(double balance) async {
    // Only show if wallet alerts enabled
    final storage = StorageService();
    if (!storage.getNotificationPreference('wallet')) return;

    final formatted = NumberFormat('#,##0.00').format(balance);
    await _show(
      id: _lowBalanceId,
      title: '⚠️ Low Wallet Balance',
      body:
          'Your balance is ₦$formatted. Fund your wallet to continue making purchases.',
      channelId: _alertChannel,
      isAlert: true,
    );
  }

  static Future<void> atcStatusChanged({
    required String reference,
    required String status,
    double? amount,
  }) async {
    final isApproved = status.toLowerCase() == 'approved';
    final title = isApproved
        ? '✅ ATC Request Approved'
        : '❌ ATC Request Rejected';

    final amountText = amount != null
        ? ' ₦${NumberFormat('#,##0.00').format(amount)}'
        : '';

    final body = isApproved
        ? 'Your Airtime to Cash request$amountText has been approved and credited to your wallet.'
        : 'Your Airtime to Cash request (Ref: $reference) was rejected. Please contact support.';

    await _show(
      id: _atcStatusId,
      title: title,
      body: body,
      channelId: _alertChannel,
      payload: 'atc:$reference',
      isAlert: true,
    );
  }

  static Future<void> referralEarningCredited({
    required double amount,
    required String referredName,
  }) async {
    final storage = StorageService();
    if (!storage.getNotificationPreference('referrals')) return;

    final formatted = NumberFormat('#,##0.00').format(amount);
    await _show(
      id: _referralEarningId,
      title: '🎉 Referral Bonus Earned!',
      body:
          '$referredName joined using your referral code! ₦$formatted has been added to your referral earnings.',
      channelId: _walletChannel,
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static String _getSuccessTitle(TransactionType type) {
    switch (type) {
      case TransactionType.airtime:
        return '✅ Airtime Purchased';
      case TransactionType.data:
        return '✅ Data Purchased';
      case TransactionType.cable:
        return '✅ Cable TV Renewed';
      case TransactionType.electricity:
        return '✅ Electricity Token Generated';
      case TransactionType.examPin:
        return '✅ Exam Pins Generated';
      case TransactionType.dataCard:
        return '✅ Data Cards Generated';
      case TransactionType.walletFunding:
        return '✅ Wallet Funded';
      case TransactionType.atc:
        return '✅ ATC Request Submitted';
      case TransactionType.referralWithdrawal:
        return '✅ Referral Earnings Withdrawn';
      case TransactionType.referralBonus:
        return '✅ Referral Bonus Credited';
    }
  }

  static String _getSuccessBody(Transaction transaction, String amount) {
    switch (transaction.type) {
      case TransactionType.airtime:
        return '₦$amount ${transaction.network} airtime sent to ${transaction.beneficiary}.';
      case TransactionType.data:
        final bundle = transaction.metadata?['bundle'] ?? '';
        return '$bundle data sent to ${transaction.beneficiary}. Amount: ₦$amount.';
      case TransactionType.cable:
        final package = transaction.metadata?['package'] ?? '';
        return '${transaction.network} $package subscription renewed for ${transaction.metadata?['customer_name'] ?? ''}. Amount: ₦$amount.';
      case TransactionType.electricity:
        final token = transaction.metadata?['token'] ?? '';
        return 'Token: $token\nAmount: ₦$amount for ${transaction.beneficiary}.';
      case TransactionType.examPin:
        final qty = transaction.metadata?['quantity'] ?? '1';
        return '$qty ${transaction.network} pin${int.tryParse(qty.toString()) != null && int.parse(qty.toString()) > 1 ? 's' : ''} generated. Amount: ₦$amount.';
      case TransactionType.dataCard:
        final qty = transaction.metadata?['quantity'] ?? '1';
        final denom = transaction.metadata?['denomination'] ?? '';
        return '$qty × $denom ${transaction.network} data card${int.tryParse(qty.toString()) != null && int.parse(qty.toString()) > 1 ? 's' : ''} generated. Amount: ₦$amount.';
      case TransactionType.walletFunding:
        return '₦$amount has been added to your wallet via ${transaction.network}.';
      case TransactionType.atc:
        return 'Your ATC request of ₦$amount has been submitted. Ref: ${transaction.reference}.';
      case TransactionType.referralWithdrawal:
        return '₦$amount referral earnings have been withdrawn to your wallet.';
      case TransactionType.referralBonus:
        return '₦$amount referral bonus has been credited to your wallet.';
    }
  }

  static String _getTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.airtime:
        return 'Airtime Purchase';
      case TransactionType.data:
        return 'Data Purchase';
      case TransactionType.cable:
        return 'Cable TV';
      case TransactionType.electricity:
        return 'Electricity';
      case TransactionType.examPin:
        return 'Exam Pin';
      case TransactionType.dataCard:
        return 'Data Card';
      case TransactionType.walletFunding:
        return 'Wallet Funding';
      case TransactionType.atc:
        return 'ATC Request';
      case TransactionType.referralWithdrawal:
        return 'Referral Withdrawal';
      case TransactionType.referralBonus:
        return 'Referral Bonus';
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    // Navigation handled via a global key or notification stream
    debugPrint('Notification tapped: $payload');
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }
}
