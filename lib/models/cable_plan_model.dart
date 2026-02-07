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
      provider: provider,
      name: json['name'] ?? '',
      price: double.parse(json['price']?.toString() ?? '0'),
      duration: json['duration'] ?? '1 month',
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
