class ExamType {
  final String examType;
  final double price;

  ExamType({required this.examType, required this.price});

  factory ExamType.fromJson(Map<String, dynamic> json) {
    return ExamType(
      examType: json['exam_type'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'exam_type': examType, 'price': price};
  }
}
