import 'dart:math';

import '../../config/api_result.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
import '../../models/virtual_account_model.dart';
import '../../models/exam_type_model.dart';
import '../../models/referral_model.dart';
import '../../models/atc_request_model.dart';
import 'api_service.dart';

class MockApiService implements ApiService {
  // Simulated delay
  Future<void> _delay([int milliseconds = 800]) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  // Mock storage
  User? _currentUser;
  double _walletBalance = 5000.0;
  final List<Transaction> _transactions = [];
  final List<VirtualAccount> _virtualAccounts = [];
  // ignore: unused_field
  bool _hasPin = false;
  String? _savedPin;
  final List<ATCRequest> _atcRequests = [];
  double _referralEarnings = 1500.0;
  final double _totalReferralEarnings = 5000.0;
  final int _totalReferrals = 10;

  // ========== AUTHENTICATION ==========

  @override
  Future<ApiResult<Map<String, dynamic>>> register({
    required String firstname,
    required String lastname,
    required String username,
    required String email,
    required String phone,
    required String password,
    String? refer,
  }) async {
    await _delay();

    _currentUser = User(
      id: 1,
      username: username,
      email: email,
      firstname: firstname,
      lastname: lastname,
      phone: phone,
      balance: 0.0,
      referralCode: 'REF${username.toUpperCase()}',
      createdAt: DateTime.now(),
    );

    return ApiResult.success({
      'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      'expires_at': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
      'user': _currentUser!.toJson(),
    }, message: 'Registration successful');
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> login({
    required String username,
    required String password,
  }) async {
    await _delay();

    _currentUser = User(
      id: 1,
      username: username,
      email: 'test@example.com',
      firstname: 'Test',
      lastname: 'User',
      phone: '08012345678',
      balance: _walletBalance,
      kycVerified: false,
      referralCode: 'REFTEST123',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );

    // FORCE generate transactions
    _transactions.clear();
    _generateMockTransactions();

    print('After login, transaction count: ${_transactions.length}'); // Debug

    if (_virtualAccounts.isEmpty && _currentUser!.kycVerified) {
      _generateVirtualAccounts();
    }

    return ApiResult.success({
      'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      'expires_at': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
      'user': _currentUser!.toJson(),
    }, message: 'Login successful');
  }

  @override
  Future<ApiResult<String>> forgotPassword({required String email}) async {
    await _delay();
    return ApiResult.success(
      'OTP sent to $email',
      message: 'Password reset OTP sent successfully',
    );
  }

  @override
  Future<ApiResult<String>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    await _delay();
    return ApiResult.success(
      'OTP verified',
      message: 'OTP verification successful',
    );
  }

  @override
  Future<ApiResult<String>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _delay();
    return ApiResult.success(
      'Password reset successful',
      message: 'Your password has been reset successfully',
    );
  }

  @override
  Future<ApiResult<String>> logout() async {
    await _delay(300);
    _currentUser = null;
    return ApiResult.success('Logged out successfully');
  }

  // ========== USER ==========

  @override
  Future<ApiResult<User>> getMe() async {
    await _delay();

    if (_currentUser == null) {
      return ApiResult.failure('Not authenticated');
    }

    // Return current user with updated balance
    _currentUser = _currentUser!.copyWith(balance: _walletBalance);

    return ApiResult.success(_currentUser!);
  }

  @override
  Future<ApiResult<User>> updateProfile({
    required String firstname,
    required String lastname,
    required String email,
    required String phone,
  }) async {
    await _delay();

    if (_currentUser == null) {
      return ApiResult.failure('Not authenticated');
    }

    _currentUser = _currentUser?.copyWith(
      firstname: firstname,
      lastname: lastname,
      email: email,
      phone: phone,
    );

    return ApiResult.success(
      _currentUser!,
      message: 'Your profile has been updated',
    );
  }

  @override
  Future<ApiResult<String>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _delay();
    return ApiResult.success(
      'Password changed successfully',
      message: 'Your password has been changed',
    );
  }

  @override
  Future<ApiResult<String>> setPin({required String pin}) async {
    await _delay();
    _hasPin = true;
    _savedPin = pin;
    return ApiResult.success(
      'PIN set successfully',
      message: 'Transaction PIN has been set',
    );
  }

  @override
  Future<ApiResult<String>> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    await _delay();

    if (_savedPin != oldPin) {
      return ApiResult.failure('Incorrect old PIN');
    }

    _savedPin = newPin;
    return ApiResult.success(
      'PIN changed successfully',
      message: 'Transaction PIN has been changed',
    );
  }

  // ========== KYC & WALLET ==========

  @override
  Future<ApiResult<List<VirtualAccount>>> verifyKyc({
    required String type,
    required String value,
  }) async {
    await _delay(1500);

    // Update current user's KYC status
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(kycVerified: true);
    }

    _generateVirtualAccounts();

    return ApiResult.success(
      _virtualAccounts,
      message: 'KYC verification successful',
    );
  }

  @override
  Future<ApiResult<double>> getWalletBalance() async {
    await _delay(300);
    return ApiResult.success(_walletBalance);
  }

  @override
  Future<ApiResult<List<VirtualAccount>>> getVirtualAccounts() async {
    await _delay();

    if (_virtualAccounts.isEmpty) {
      _generateVirtualAccounts();
    }

    return ApiResult.success(_virtualAccounts);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> initializePaystackPayment({
    required double amount,
  }) async {
    await _delay();

    return ApiResult.success({
      'authorization_url': 'https://checkout.paystack.com/mock123',
      'access_code': 'mock_access_code_123',
      'reference': 'REF_${DateTime.now().millisecondsSinceEpoch}',
    }, message: 'Payment initialized');
  }

  void _generateVirtualAccounts() {
    if (_currentUser == null) return;

    _virtualAccounts.clear();
    _virtualAccounts.addAll([
      VirtualAccount(
        bankName: 'Wema Bank',
        accountNumber: '7894561230',
        accountName: 'AZ VTU - ${_currentUser!.fullName}',
      ),
      VirtualAccount(
        bankName: 'Sterling Bank',
        accountNumber: '0123456789',
        accountName: 'AZ VTU - ${_currentUser!.fullName}',
      ),
      VirtualAccount(
        bankName: 'Moniepoint',
        accountNumber: '8012345678',
        accountName: 'AZ VTU - ${_currentUser!.fullName}',
      ),
    ]);
  }

  // ========== PLANS ==========

  @override
  Future<ApiResult<Map<String, dynamic>>> getDataPlans() async {
    await _delay();

    return ApiResult.success({
      'MTN': {
        'SME': [
          {'id': '1', 'name': '500MB', 'price': 150, 'validity': '30 days'},
          {'id': '2', 'name': '1GB', 'price': 280, 'validity': '30 days'},
          {'id': '3', 'name': '2GB', 'price': 560, 'validity': '30 days'},
          {'id': '4', 'name': '3GB', 'price': 840, 'validity': '30 days'},
          {'id': '5', 'name': '5GB', 'price': 1400, 'validity': '30 days'},
          {'id': '6', 'name': '10GB', 'price': 2800, 'validity': '30 days'},
        ],
        'GIFTING': [
          {'id': '7', 'name': '1GB', 'price': 300, 'validity': '30 days'},
          {'id': '8', 'name': '2GB', 'price': 600, 'validity': '30 days'},
          {'id': '9', 'name': '5GB', 'price': 1500, 'validity': '30 days'},
        ],
        'COUPON': [
          {'id': '10', 'name': '1.5GB', 'price': 1000, 'validity': '30 days'},
          {'id': '11', 'name': '4.5GB', 'price': 2000, 'validity': '30 days'},
        ],
      },
      'GLO': {
        'CG': [
          {'id': '12', 'name': '1GB', 'price': 250, 'validity': '30 days'},
          {'id': '13', 'name': '2GB', 'price': 500, 'validity': '30 days'},
          {'id': '14', 'name': '3GB', 'price': 750, 'validity': '30 days'},
          {'id': '15', 'name': '5GB', 'price': 1250, 'validity': '30 days'},
          {'id': '16', 'name': '10GB', 'price': 2500, 'validity': '30 days'},
        ],
      },
      'AIRTEL': {
        'CG': [
          {'id': '17', 'name': '1GB', 'price': 280, 'validity': '30 days'},
          {'id': '18', 'name': '2GB', 'price': 560, 'validity': '30 days'},
          {'id': '19', 'name': '5GB', 'price': 1400, 'validity': '30 days'},
          {'id': '20', 'name': '10GB', 'price': 2800, 'validity': '30 days'},
        ],
      },
      '9MOBILE': {
        'GIFTING': [
          {'id': '21', 'name': '1GB', 'price': 300, 'validity': '30 days'},
          {'id': '22', 'name': '2.5GB', 'price': 750, 'validity': '30 days'},
          {'id': '23', 'name': '5GB', 'price': 1500, 'validity': '30 days'},
        ],
      },
    });
  }

  @override
  Future<ApiResult<List<String>>> getAirtimeNetworks() async {
    await _delay(300);
    return ApiResult.success(['MTN', 'GLO', 'AIRTEL', '9MOBILE']);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getCablePlans() async {
    await _delay();

    return ApiResult.success({
      'DSTV': [
        {'id': '1', 'name': 'Compact', 'price': 10500, 'duration': '1 month'},
        {
          'id': '2',
          'name': 'Compact Plus',
          'price': 16200,
          'duration': '1 month',
        },
        {'id': '3', 'name': 'Premium', 'price': 24500, 'duration': '1 month'},
        {'id': '4', 'name': 'Padi', 'price': 2500, 'duration': '1 month'},
      ],
      'GOTV': [
        {'id': '5', 'name': 'Smallie', 'price': 1300, 'duration': '1 month'},
        {'id': '6', 'name': 'Jinja', 'price': 3300, 'duration': '1 month'},
        {'id': '7', 'name': 'Jolli', 'price': 4850, 'duration': '1 month'},
        {'id': '8', 'name': 'Max', 'price': 7200, 'duration': '1 month'},
      ],
      'STARTIMES': [
        {'id': '9', 'name': 'Basic', 'price': 2200, 'duration': '1 month'},
        {'id': '10', 'name': 'Smart', 'price': 3200, 'duration': '1 month'},
        {'id': '11', 'name': 'Classic', 'price': 4200, 'duration': '1 month'},
      ],
    });
  }

  @override
  Future<ApiResult<List<String>>> getElectricDiscos() async {
    await _delay(300);
    return ApiResult.success([
      'EKEDC',
      'IKEDC',
      'AEDC',
      'PHED',
      'IBEDC',
      'KEDCO',
      'EEDC',
      'JEDC',
    ]);
  }

  @override
  Future<ApiResult<List<ExamType>>> getExamTypes() async {
    await _delay();

    final types = [
      ExamType(id: '1', name: 'WAEC', price: 800),
      ExamType(id: '2', name: 'NECO', price: 800),
      ExamType(id: '3', name: 'NABTEB', price: 800),
    ];

    return ApiResult.success(types);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getDataCardPlans() async {
    await _delay();

    return ApiResult.success({
      'MTN': [
        {'id': '1', 'name': '1GB', 'price': 300},
        {'id': '2', 'name': '2GB', 'price': 600},
        {'id': '3', 'name': '5GB', 'price': 1500},
      ],
      'GLO': [
        {'id': '4', 'name': '1GB', 'price': 270},
        {'id': '5', 'name': '2GB', 'price': 540},
      ],
    });
  }

  // ========== VALIDATION ==========

  @override
  Future<ApiResult<Map<String, dynamic>>> validateMeter({
    required String disco,
    required String meterNumber,
    required String meterType,
  }) async {
    await _delay(1000);

    return ApiResult.success({
      'customer_name': 'John Doe',
      'address': '123 Main Street, Lagos',
      'meter_number': meterNumber,
      'disco': disco,
      'meter_type': meterType,
    }, message: 'Meter validated successfully');
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> validateSmartcard({
    required String provider,
    required String smartcard,
  }) async {
    await _delay(1000);

    return ApiResult.success({
      'customer_name': 'Jane Smith',
      'smartcard': smartcard,
      'provider': provider,
    }, message: 'Smartcard validated successfully');
  }

  // ========== PURCHASES ==========

  @override
  Future<ApiResult<Map<String, dynamic>>> buyAirtime({
    required String network,
    required String number,
    required double amount,
    required String pincode,
  }) async {
    await _delay(1200);

    // CRITICAL: Store balance before
    double balanceBefore = _walletBalance;

    // Deduct amount
    _walletBalance -= amount;

    // CRITICAL: Store balance after
    double balanceAfter = _walletBalance;

    // Create transaction
    final transaction = Transaction(
      id: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.airtime,
      network: network,
      amount: amount,
      status: TransactionStatus.success,
      createdAt: DateTime.now(),
      beneficiary: number,
      reference: 'REF${DateTime.now().millisecondsSinceEpoch}',
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
    );

    _transactions.insert(0, transaction);

    return ApiResult.success({
      'transaction_id': transaction.id,
      'reference': transaction.reference,
      'balance': _walletBalance,
    }, message: 'Airtime purchase successful');
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> buyData({
    required String network,
    required String type,
    required String dataBundle,
    required String number,
    required String pincode,
  }) async {
    await _delay(1200);

    double amount = 280.0;

    double balanceBefore = _walletBalance;
    _walletBalance -= amount;
    double balanceAfter = _walletBalance;

    final transaction = Transaction(
      id: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.data,
      network: network,
      amount: amount,
      status: TransactionStatus.success,
      createdAt: DateTime.now(),
      beneficiary: number,
      reference: 'REF${DateTime.now().millisecondsSinceEpoch}',
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      metadata: {'data_type': type, 'bundle': dataBundle},
    );

    _transactions.insert(0, transaction);

    return ApiResult.success({
      'transaction_id': transaction.id,
      'reference': transaction.reference,
      'balance': _walletBalance,
    }, message: 'Data purchase successful');
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> buyCable({
    required String provider,
    required String planId,
    required String smartcard,
    required String pincode,
  }) async {
    await _delay(1200);

    double amount = 3300.0;

    double balanceBefore = _walletBalance;
    _walletBalance -= amount;
    double balanceAfter = _walletBalance;

    final transaction = Transaction(
      id: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.cable,
      network: provider,
      amount: amount,
      status: TransactionStatus.success,
      createdAt: DateTime.now(),
      beneficiary: smartcard,
      reference: 'REF${DateTime.now().millisecondsSinceEpoch}',
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      metadata: {'plan_id': planId, 'provider': provider},
    );

    _transactions.insert(0, transaction);

    return ApiResult.success({
      'transaction_id': transaction.id,
      'reference': transaction.reference,
      'balance': _walletBalance,
    }, message: 'Cable subscription successful');
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> buyElectricity({
    required String disco,
    required String meter,
    required double amount,
    required String pincode,
  }) async {
    await _delay(1200);

    double balanceBefore = _walletBalance;
    _walletBalance -= amount;
    double balanceAfter = _walletBalance;

    // Generate mock token
    String token =
        '${Random().nextInt(9999)}-${Random().nextInt(9999)}-${Random().nextInt(9999)}-${Random().nextInt(9999)}';
    double units = amount * 1.2;

    final transaction = Transaction(
      id: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.electricity,
      network: disco,
      amount: amount,
      status: TransactionStatus.success,
      createdAt: DateTime.now(),
      beneficiary: meter,
      reference: 'REF${DateTime.now().millisecondsSinceEpoch}',
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      metadata: {'token': token, 'units': units, 'disco': disco},
    );

    _transactions.insert(0, transaction);

    return ApiResult.success({
      'transaction_id': transaction.id,
      'reference': transaction.reference,
      'token': token,
      'units': units,
      'balance': _walletBalance,
    }, message: 'Electricity purchase successful');
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> buyExamPin({
    required String examType,
    required int quantity,
    required String pincode,
  }) async {
    await _delay(1200);

    double amount = 800.0 * quantity;

    double balanceBefore = _walletBalance;
    _walletBalance -= amount;
    double balanceAfter = _walletBalance;

    // Generate mock pins
    List<Map<String, String>> pins = List.generate(
      quantity,
      (index) => {
        'serial': '${examType}${DateTime.now().millisecondsSinceEpoch}$index',
        'pin':
            '${Random().nextInt(999999).toString().padLeft(6, '0')}${Random().nextInt(999999).toString().padLeft(6, '0')}',
      },
    );

    final transaction = Transaction(
      id: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.examPin,
      network: examType,
      amount: amount,
      status: TransactionStatus.success,
      createdAt: DateTime.now(),
      beneficiary: '$quantity pins',
      reference: 'REF${DateTime.now().millisecondsSinceEpoch}',
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      metadata: {'pins': pins, 'quantity': quantity, 'exam_type': examType},
    );

    _transactions.insert(0, transaction);

    return ApiResult.success({
      'transaction_id': transaction.id,
      'reference': transaction.reference,
      'pins': pins,
      'balance': _walletBalance,
    }, message: 'Exam pins purchased successfully');
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> buyDataCard({
    required String cardId,
    required int quantity,
    required String pincode,
  }) async {
    await _delay(1200);

    double amount = 300.0 * quantity;

    double balanceBefore = _walletBalance;
    _walletBalance -= amount;
    double balanceAfter = _walletBalance;

    List<Map<String, String>> pins = List.generate(
      quantity,
      (index) => {
        'serial': 'DC${DateTime.now().millisecondsSinceEpoch}$index',
        'pin':
            '${Random().nextInt(99999).toString().padLeft(5, '0')}${Random().nextInt(99999).toString().padLeft(5, '0')}',
      },
    );

    final transaction = Transaction(
      id: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.dataCard,
      network: 'MTN',
      amount: amount,
      status: TransactionStatus.success,
      createdAt: DateTime.now(),
      beneficiary: '$quantity cards',
      reference: 'REF${DateTime.now().millisecondsSinceEpoch}',
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      metadata: {'pins': pins, 'quantity': quantity, 'card_id': cardId},
    );

    _transactions.insert(0, transaction);

    return ApiResult.success({
      'transaction_id': transaction.id,
      'reference': transaction.reference,
      'pins': pins,
      'balance': _walletBalance,
    }, message: 'Data cards purchased successfully');
  }

  // ========== TRANSACTIONS ==========

  @override
  Future<ApiResult<PaginatedTransactions>> getTransactions({
    int page = 1,
    int limit = 10,
    String? type,
    String? status,
    String? search,
  }) async {
    await _delay();

    print(
      'Getting transactions - current count: ${_transactions.length}',
    ); // Debug

    // If no transactions exist, generate them
    if (_transactions.isEmpty) {
      _generateMockTransactions();
    }

    List<Transaction> filtered = List.from(_transactions);

    // Apply filters
    if (type != null && type != 'all' && type.isNotEmpty) {
      filtered = filtered
          .where((t) => t.type.name.toLowerCase() == type.toLowerCase())
          .toList();
    }

    if (status != null && status != 'all' && status.isNotEmpty) {
      filtered = filtered
          .where((t) => t.status.name.toLowerCase() == status.toLowerCase())
          .toList();
    }

    if (search != null && search.isNotEmpty) {
      filtered = filtered
          .where(
            (t) =>
                (t.beneficiary?.contains(search) ?? false) ||
                (t.reference?.contains(search) ?? false) ||
                t.id.contains(search),
          )
          .toList();
    }

    print('Filtered transactions: ${filtered.length}'); // Debug

    // Pagination
    int totalRecords = filtered.length;
    int totalPages = totalRecords > 0 ? (totalRecords / limit).ceil() : 1;
    int start = (page - 1) * limit;
    int end = start + limit;

    List<Transaction> paginated = filtered.sublist(
      start,
      end > filtered.length ? filtered.length : end,
    );

    print('Paginated transactions: ${paginated.length}'); // Debug

    final result = PaginatedTransactions(
      transactions: paginated,
      currentPage: page,
      totalPages: totalPages,
      perPage: limit,
      totalRecords: totalRecords,
    );

    return ApiResult.success(result);
  }

  @override
  Future<ApiResult<Transaction>> getTransactionDetail(String id) async {
    await _delay();

    Transaction? transaction = _transactions.firstWhere(
      (t) => t.id == id,
      orElse: () => _transactions.isNotEmpty
          ? _transactions.first
          : throw Exception('No transactions'),
    );

    return ApiResult.success(transaction);
  }

  // ========== REFERRALS ==========

  @override
  Future<ApiResult<ReferralStats>> getReferralStats() async {
    await _delay();

    final stats = ReferralStats(
      totalEarnings: _totalReferralEarnings,
      availableBalance: _referralEarnings,
      totalReferrals: _totalReferrals,
      activeReferrals: 7,
    );

    return ApiResult.success(stats);
  }

  @override
  Future<ApiResult<List<ReferralEarning>>> getReferralHistory() async {
    await _delay();

    final history = [
      ReferralEarning(
        id: '1',
        amount: 50,
        source: 'User123',
        transactionId: 'TXN123',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ReferralEarning(
        id: '2',
        amount: 75,
        source: 'User456',
        transactionId: 'TXN456',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    return ApiResult.success(history);
  }

  @override
  Future<ApiResult<String>> withdrawReferralEarnings({
    required double amount,
    required String pincode,
  }) async {
    await _delay();

    if (amount > _referralEarnings) {
      return ApiResult.failure('Insufficient referral balance');
    }

    double balanceBefore = _walletBalance;
    _walletBalance += amount;
    _referralEarnings -= amount;
    double balanceAfter = _walletBalance;

    final transaction = Transaction(
      id: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.referralWithdrawal,
      network: 'Referral',
      amount: amount,
      status: TransactionStatus.success,
      createdAt: DateTime.now(),
      beneficiary: 'Wallet',
      reference: 'REF${DateTime.now().millisecondsSinceEpoch}',
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
    );

    _transactions.insert(0, transaction);

    return ApiResult.success(
      'Withdrawal successful',
      message: '₦$amount withdrawn to wallet',
    );
  }

  // ========== AIRTIME TO CASH ==========

  @override
  Future<ApiResult<String>> submitATCRequest({
    required String network,
    required double amount,
    required String number,
  }) async {
    await _delay();

    double receivable = amount * 0.85;

    final request = ATCRequest(
      id: 'ATC${DateTime.now().millisecondsSinceEpoch}',
      network: network,
      amount: amount,
      receivableAmount: receivable,
      conversionRate: 0.85,
      phoneNumber: number,
      status: ATCStatus.pending,
      createdAt: DateTime.now(),
    );

    _atcRequests.insert(0, request);

    final transaction = Transaction(
      id: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.atc,
      network: network,
      amount: amount,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
      beneficiary: number,
      reference: request.id,
      metadata: {'receivable_amount': receivable, 'conversion_rate': 0.85},
    );

    _transactions.insert(0, transaction);

    return ApiResult.success(
      'Request submitted successfully',
      message: 'You will be notified of updates',
    );
  }

  @override
  Future<ApiResult<List<ATCRequest>>> getATCHistory() async {
    await _delay();
    return ApiResult.success(_atcRequests);
  }

  // ========== HELPER METHODS ==========

  void _generateMockTransactions() {
    final now = DateTime.now();

    _transactions.addAll([
      // 1. AIRTIME
      Transaction(
        id: 'TXN001',
        type: TransactionType.airtime,
        network: 'MTN',
        amount: 200,
        status: TransactionStatus.success,
        createdAt: now.subtract(const Duration(hours: 2)),
        beneficiary: '08012345678',
        reference: 'REF001',
        balanceBefore: 5200,
        balanceAfter: 5000,
      ),
      // 2. DATA
      Transaction(
        id: 'TXN002',
        type: TransactionType.data,
        network: 'GLO',
        amount: 500,
        status: TransactionStatus.success,
        createdAt: now.subtract(const Duration(hours: 4)),
        beneficiary: '08087654321',
        reference: 'REF002',
        balanceBefore: 5700,
        balanceAfter: 5200,
        metadata: {'data_type': 'CG', 'bundle': '2GB'},
      ),
      // 3. CABLE
      Transaction(
        id: 'TXN003',
        type: TransactionType.cable,
        network: 'DSTV',
        amount: 10500,
        status: TransactionStatus.success,
        createdAt: now.subtract(const Duration(days: 1)),
        beneficiary: '1234567890',
        reference: 'REF003',
        balanceBefore: 16200,
        balanceAfter: 5700,
        metadata: {'plan': 'Compact', 'duration': '1 month'},
      ),
      // 4. ELECTRICITY
      Transaction(
        id: 'TXN004',
        type: TransactionType.electricity,
        network: 'IKEDC',
        amount: 5000,
        status: TransactionStatus.success,
        createdAt: now.subtract(const Duration(days: 2)),
        beneficiary: '12345678901',
        reference: 'REF004',
        balanceBefore: 21200,
        balanceAfter: 16200,
        metadata: {
          'token': '1234-5678-9012-3456',
          'units': 6000.0,
          'meter_type': 'Prepaid',
        },
      ),
      // 5. EXAM PIN
      Transaction(
        id: 'TXN005',
        type: TransactionType.examPin,
        network: 'WAEC',
        amount: 1600,
        status: TransactionStatus.success,
        createdAt: now.subtract(const Duration(days: 3)),
        beneficiary: '2 pins',
        reference: 'REF005',
        balanceBefore: 22800,
        balanceAfter: 21200,
        metadata: {
          'quantity': 2,
          'pins': [
            {'serial': 'WAEC001', 'pin': '123456789012'},
            {'serial': 'WAEC002', 'pin': '234567890123'},
          ],
        },
      ),
      // 6. DATA CARD
      Transaction(
        id: 'TXN006',
        type: TransactionType.dataCard,
        network: 'MTN',
        amount: 900,
        status: TransactionStatus.success,
        createdAt: now.subtract(const Duration(days: 4)),
        beneficiary: '3 cards',
        reference: 'REF006',
        balanceBefore: 23700,
        balanceAfter: 22800,
        metadata: {
          'quantity': 3,
          'pins': [
            {'serial': 'DC001', 'pin': '1234567890'},
            {'serial': 'DC002', 'pin': '2345678901'},
            {'serial': 'DC003', 'pin': '3456789012'},
          ],
        },
      ),
      // 7. WALLET FUNDING
      Transaction(
        id: 'TXN007',
        type: TransactionType.walletFunding,
        network: 'Paystack',
        amount: 10000,
        status: TransactionStatus.success,
        createdAt: now.subtract(const Duration(days: 5)),
        beneficiary: 'Wallet',
        reference: 'REF007',
        balanceBefore: 13700,
        balanceAfter: 23700,
      ),
      // 8. ATC (Airtime to Cash)
      Transaction(
        id: 'TXN008',
        type: TransactionType.atc,
        network: 'MTN',
        amount: 2000,
        status: TransactionStatus.pending,
        createdAt: now.subtract(const Duration(days: 6)),
        beneficiary: '08011112222',
        reference: 'ATC12345',
        metadata: {'receivable_amount': 1700.0, 'conversion_rate': 0.85},
      ),
      // 9. REFERRAL WITHDRAWAL
      Transaction(
        id: 'TXN009',
        type: TransactionType.referralWithdrawal,
        network: 'Referral',
        amount: 1500,
        status: TransactionStatus.success,
        createdAt: now.subtract(const Duration(days: 7)),
        beneficiary: 'Wallet',
        reference: 'REF009',
        balanceBefore: 12200,
        balanceAfter: 13700,
      ),
      // 10. FAILED TRANSACTION (to test all statuses)
      Transaction(
        id: 'TXN010',
        type: TransactionType.data,
        network: 'AIRTEL',
        amount: 1000,
        status: TransactionStatus.failed,
        createdAt: now.subtract(const Duration(days: 8)),
        beneficiary: '08099998888',
        reference: 'REF010',
        metadata: {'error': 'Insufficient balance'},
      ),
      // 11. REFERRAL BONUS
      Transaction(
        id: 'TXN011',
        type: TransactionType.referralBonus,
        network: 'Referral',
        amount: 500,
        status: TransactionStatus.success,
        createdAt: DateTime.now().subtract(const Duration(days: 9)),
        beneficiary: 'Wallet',
        reference: 'REF011',
        balanceBefore: 11000,
        balanceAfter: 11500,
      ),
    ]);
  }
}
