import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ErrorHandler {
  // ... existing code ...

  static void handleApiError(BuildContext context, String? error) {
    final message = _getFriendlyErrorMessage(error);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 12),
            const Expanded(child: Text('Transaction Failed')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(color: Colors.grey[700], fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'If this persists, please try again later or contact support.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static String _getFriendlyErrorMessage(String? error) {
    if (error == null || error.isEmpty) {
      return 'Something went wrong. Please try again.';
    }

    // Network errors
    if (error.toLowerCase().contains('network') ||
        error.toLowerCase().contains('connection')) {
      return 'Network error. Please check your internet connection.';
    }

    // Timeout errors
    if (error.toLowerCase().contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    // Insufficient balance
    if (error.toLowerCase().contains('insufficient') ||
        error.toLowerCase().contains('balance')) {
      return 'Insufficient wallet balance. Please fund your wallet.';
    }

    // Invalid inputs
    if (error.toLowerCase().contains('invalid')) {
      return 'Invalid input. Please check your details and try again.';
    }

    // Server errors
    if (error.toLowerCase().contains('server') ||
        error.toLowerCase().contains('500')) {
      return 'Server error. Please try again later.';
    }

    // Not found
    if (error.toLowerCase().contains('not found') ||
        error.toLowerCase().contains('404')) {
      return 'Service not found. Please contact support.';
    }

    // Unauthorized
    if (error.toLowerCase().contains('unauthorized') ||
        error.toLowerCase().contains('401')) {
      return 'Session expired. Please login again.';
    }

    // Default: return original error if it's user-friendly
    if (error.length < 100) {
      return error;
    }

    return 'An error occurred. Please try again.';
  }

  static void handleInsufficientBalance(
    BuildContext context,
    double balance,
    double required,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.red[700]),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Insufficient Balance',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You don\'t have enough balance to complete this transaction.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildBalanceRow('Current Balance', balance, Colors.red),
                  const SizedBox(height: 8),
                  _buildBalanceRow('Required Amount', required, Colors.orange),
                  const Divider(height: 16),
                  _buildBalanceRow('You Need', required - balance, Colors.blue),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to fund wallet
              Navigator.pushNamed(context, '/fund-wallet');
            },
            child: const Text('Fund Wallet'),
          ),
        ],
      ),
    );
  }

  static Widget _buildBalanceRow(String label, double amount, Color? color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: color ?? Colors.grey[700], fontSize: 14),
        ),
        Text(
          '₦${NumberFormat('#,##0.00').format(amount)}',
          style: TextStyle(
            color: color ?? Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  static void handleOfflineMode(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red[700]),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No Internet Connection',
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are currently offline. Please check your internet connection and try again.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'All transactions require an active internet connection.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<bool> confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Continue',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: confirmColor != null
                ? ElevatedButton.styleFrom(backgroundColor: confirmColor)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
