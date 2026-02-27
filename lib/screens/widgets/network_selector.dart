import 'package:flutter/material.dart';
import '../../models/airtime_network_model.dart';

class NetworkSelector extends StatelessWidget {
  final String? selectedNetwork;
  final Function(AirtimeNetwork) onNetworkSelected;
  final List<AirtimeNetwork> networks;
  final bool showDiscount;

  const NetworkSelector({
    super.key,
    this.selectedNetwork,
    required this.onNetworkSelected,
    this.networks = const [],
    this.showDiscount = true,
  });

  Color _getNetworkColor(String network) {
    switch (network.toUpperCase()) {
      case 'MTN':
        return const Color(0xFFFFCC00);
      case 'GLO':
        return const Color(0xFF00A95C);
      case 'AIRTEL':
        return const Color(0xFFED1C24);
      case '9MOBILE':
        return const Color(0xFF006F3F);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Network',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: networks.map((airtimeNetwork) {
            final isSelected = selectedNetwork == airtimeNetwork.network;
            final color = _getNetworkColor(airtimeNetwork.network);

            return Expanded(
              child: GestureDetector(
                onTap: () => onNetworkSelected(airtimeNetwork),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.1)
                        : Colors.grey[100],
                    border: Border.all(
                      color: isSelected ? color : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            airtimeNetwork.network[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        airtimeNetwork.network,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? color : Colors.grey[700],
                        ),
                      ),
                      // Discount badge — only shown for airtime (showDiscount: true)
                      if (showDiscount && airtimeNetwork.hasDiscount) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(airtimeNetwork.ratePercent * 100).toStringAsFixed(0)}% off',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
