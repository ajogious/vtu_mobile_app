class DataPlan {
  final String id;
  final String network;
  final String type;
  final String name;
  final double price;
  final String validity;
  final String? dataVolume;

  DataPlan({
    required this.id,
    required this.network,
    required this.type,
    required this.name,
    required this.price,
    required this.validity,
    this.dataVolume,
  });

  factory DataPlan.fromJson(
    Map<String, dynamic> json,
    String network,
    String type,
  ) {
    return DataPlan(
      id: json['id'].toString(),
      network: network,
      type: type,
      name: json['name'] ?? '',
      price: double.parse(json['price']?.toString() ?? '0'),
      validity: json['validity'] ?? '',
      dataVolume: json['data_volume'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'network': network,
      'type': type,
      'name': name,
      'price': price,
      'validity': validity,
      'data_volume': dataVolume,
    };
  }
}
