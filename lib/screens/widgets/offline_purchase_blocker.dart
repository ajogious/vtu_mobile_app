import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/network_provider.dart';

/// Wraps any purchase button - disables it when offline and shows dialog on tap
class OfflinePurchaseBlocker extends StatelessWidget {
  final Widget child;
  final String? serviceName;

  const OfflinePurchaseBlocker({
    super.key,
    required this.child,
    this.serviceName,
  });

  void _showOfflineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red[700]),
            const SizedBox(width: 12),
            const Text('No Internet Connection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Internet connection is required to ${serviceName != null ? 'purchase $serviceName' : 'complete this purchase'}.',
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
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'All transactions require an active internet connection for security.',
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

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, network, child2) {
        if (network.isOnline) {
          return child;
        }

        // When offline: wrap in GestureDetector to show dialog
        return GestureDetector(
          onTap: () => _showOfflineDialog(context),
          child: AbsorbPointer(child: Opacity(opacity: 0.5, child: child)),
        );
      },
    );
  }
}
