class AirtimeNetwork {
  final String network;
  final String serviceKey;
  final double ratePercent;
  final String server;

  const AirtimeNetwork({
    required this.network,
    required this.serviceKey,
    this.ratePercent = 0,
    this.server = '',
  });

  factory AirtimeNetwork.fromJson(Map<String, dynamic> json) {
    return AirtimeNetwork(
      network: json['network']?.toString() ?? '',
      serviceKey: json['service_key']?.toString() ?? '',
      ratePercent: (json['rate_percent'] as num?)?.toDouble() ?? 0,
      server: json['server']?.toString() ?? '',
    );
  }

  /// Returns true if this network has a discount/cashback
  bool get hasDiscount => ratePercent > 0;

  @override
  String toString() => network;
}
