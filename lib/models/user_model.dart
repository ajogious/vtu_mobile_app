class User {
  final int id;
  final String username;
  final String email;
  final String firstname;
  final String lastname;
  final String phone;
  final double balance;
  final bool kycVerified;
  final String? referralCode;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstname,
    required this.lastname,
    required this.phone,
    required this.balance,
    this.kycVerified = false,
    this.referralCode,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.parse(json['id'].toString()),
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
      phone: json['phone'] ?? '',
      balance: double.parse(json['balance']?.toString() ?? '0'),
      kycVerified: json['kyc_verified'] == true || json['kyc_verified'] == 1,
      referralCode: json['referral_code'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'firstname': firstname,
      'lastname': lastname,
      'phone': phone,
      'balance': balance,
      'kyc_verified': kycVerified,
      'referral_code': referralCode,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get fullName => '$firstname $lastname';

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? firstname,
    String? lastname,
    String? phone,
    double? balance,
    bool? kycVerified,
    String? referralCode,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      phone: phone ?? this.phone,
      balance: balance ?? this.balance,
      kycVerified: kycVerified ?? this.kycVerified,
      referralCode: referralCode ?? this.referralCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
