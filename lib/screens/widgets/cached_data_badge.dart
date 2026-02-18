import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/network_provider.dart';
import '../../services/cache_service.dart';

/// Small badge to show "Cached • X mins ago" when offline
class CachedDataBadge extends StatelessWidget {
  final DateTime? cachedAt;
  final String? label;

  const CachedDataBadge({super.key, required this.cachedAt, this.label});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, network, child) {
        if (network.isOnline || cachedAt == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cached, size: 12, color: Colors.orange[800]),
              const SizedBox(width: 4),
              Text(
                '${label != null ? '$label • ' : ''}${CacheService.getLastUpdatedText(cachedAt)}',
                style: TextStyle(
                  color: Colors.orange[900],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Offline content indicator for lists
class OfflineContentBanner extends StatelessWidget {
  final DateTime? cachedAt;

  const OfflineContentBanner({super.key, this.cachedAt});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkProvider>(
      builder: (context, network, child) {
        if (network.isOnline) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.orange[700], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Showing cached data',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (cachedAt != null)
                      Text(
                        'Last synced: ${CacheService.getLastUpdatedText(cachedAt)}',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
