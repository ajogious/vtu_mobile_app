class DataPlan {
  final String id; // ← ADD THIS
  final String name;
  final String type;
  final double price;
  final String validity;
  final String network;

  DataPlan({
    required this.id, // ← ADD THIS
    required this.name,
    required this.type,
    required this.price,
    required this.validity,
    required this.network,
  });

  // Update fromJson
  factory DataPlan.fromJson(Map<String, dynamic> json) {
    return DataPlan(
      id: json['id']?.toString() ?? '', // ← ADD THIS
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      validity: json['validity'] ?? '',
      network: json['network'] ?? '',
    );
  }

  // Update toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id, // ← ADD THIS
      'name': name,
      'type': type,
      'price': price,
      'validity': validity,
      'network': network,
    };
  }
}
