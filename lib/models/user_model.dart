class User {
  final int id;
  final String username;
  final String email;
  final String firstname;
  final String lastname;
  final String phone;
  final double balance;
  final bool kycVerified;
  final bool emailVerified;
  final bool accountSuspended;
  final String? referralCode;
  final double referralCredit;
  final String level;
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
    this.emailVerified = false,
    this.accountSuspended = false,
    this.referralCode,
    this.referralCredit = 0,
    this.level = 'free',
    this.createdAt,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // CORRECTED fromJson for real API
  // ═══════════════════════════════════════════════════════════════════════════

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.parse(json['id'].toString()),
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
      phone: json['phone'] ?? '',

      // ⚠️ Parse string numbers to double
      balance: _parseDouble(json['wallet_balance'] ?? json['balance']),
      referralCredit: _parseDouble(json['ref_credit']),

      // ⚠️ API uses "refer" not "referralCode"
      referralCode: json['refer'] ?? json['referral_code'],

      // ⚠️ Convert "YES"/"NO" strings to bool
      kycVerified: _parseBool(json['kyc_verify'] ?? json['kyc_verified']),
      emailVerified: _parseBool(json['email_verify'] ?? json['email_verified']),
      accountSuspended: _parseBool(json['account_suspended']),

      level: json['level'] ?? 'free',

      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  // Helper to parse string or number to double
  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  // Helper to parse "YES"/"NO" strings or booleans
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toUpperCase() == 'YES';
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'firstname': firstname,
      'lastname': lastname,
      'phone': phone,
      'wallet_balance': balance.toString(),
      'ref_credit': referralCredit.toString(),
      'kyc_verify': kycVerified ? 'YES' : 'NO',
      'email_verify': emailVerified ? 'YES' : 'NO',
      'account_suspended': accountSuspended ? 'YES' : 'NO',
      'refer': referralCode,
      'level': level,
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
    bool? emailVerified,
    bool? accountSuspended,
    String? referralCode,
    double? referralCredit,
    String? level,
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
      emailVerified: emailVerified ?? this.emailVerified,
      accountSuspended: accountSuspended ?? this.accountSuspended,
      referralCode: referralCode ?? this.referralCode,
      referralCredit: referralCredit ?? this.referralCredit,
      level: level ?? this.level,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
