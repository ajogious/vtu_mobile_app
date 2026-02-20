class CablePlan {
  final String id;
  final String provider;
  final String name;
  final double price;
  final String duration;

  CablePlan({
    required this.id,
    required this.provider,
    required this.name,
    required this.price,
    required this.duration,
  });

  factory CablePlan.fromJson(Map<String, dynamic> json, String provider) {
    return CablePlan(
      id: json['id'].toString(),
      provider: json['cable_type']?.toString() ?? provider,
      name: (json['cable_plan'] ?? json['name'] ?? '').toString().trim(),
      price: double.parse((json['amount'] ?? json['price'] ?? '0').toString()),
      duration: (json['duration'] ?? '1 month').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider': provider,
      'name': name,
      'price': price,
      'duration': duration,
    };
  }
}
