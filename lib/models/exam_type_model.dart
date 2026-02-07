class ExamType {
  final String id;
  final String name;
  final double price;

  ExamType({required this.id, required this.name, required this.price});

  factory ExamType.fromJson(Map<String, dynamic> json) {
    return ExamType(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      price: double.parse(json['price']?.toString() ?? '0'),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'price': price};
  }
}
