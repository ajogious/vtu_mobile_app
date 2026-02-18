import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/network_provider.dart';

class OfflineBanner extends StatelessWidget {
  /// Optional override — when provided, this value is used instead of
  /// reading from [NetworkProvider].  Keeps the widget usable both as
  /// `const OfflineBanner()` (self-contained) and as
  /// `OfflineBanner(isOffline: !networkProvider.isOnline)`.
  final bool? isOffline;

  const OfflineBanner({super.key, this.isOffline});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, network, child) {
        final offline = isOffline ?? !network.isOnline;
        if (!offline && !network.justReconnected) {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          color: network.isOnline ? Colors.green : Colors.red[700],
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(
                  network.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    network.isOnline
                        ? 'Back online! Syncing data...'
                        : 'No internet connection',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!network.isOnline)
                  Text(
                    network.connectionLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Wrap any screen body with this to get the offline banner at top
class WithOfflineBanner extends StatelessWidget {
  final Widget child;

  const WithOfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(child: child),
      ],
    );
  }
}
