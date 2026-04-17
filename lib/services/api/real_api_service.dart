import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../../config/api_result.dart';
import '../../models/airtime_network_model.dart';
import '../../models/data_plan_model.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
import '../../models/virtual_account_model.dart';
import '../../models/exam_type_model.dart';
import '../../models/referral_model.dart';
import '../../models/atc_request_model.dart';
import '../../services/storage_service.dart';
import 'api_service.dart';

class RealApiService implements ApiService {
  late final Dio _dio;
  final StorageService _storage = StorageService();

  RealApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: ApiConfig.headers(),
      ),
    );

    // Add interceptors
    _dio.interceptors.add(_AuthInterceptor(_storage));
    _dio.interceptors.add(_ErrorInterceptor());
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ApiResult<Map<String, dynamic>>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.loginEndpoint,
        data: {'username': username, 'password': password},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'];

        final token = data['token'];
        if (token != null) {
          await _storage.saveToken(token);
        }

        return ApiResult.success({
          'token': token,
          'user': data['user'],
          'expires_at': data['expires_at'],
        });
      }

      return ApiResult.failure(responseData['message'] ?? 'Login failed');
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

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
    try {
      final requestData = {
        'firstname': firstname,
        'lastname': lastname,
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
      };

      if (refer != null && refer.isNotEmpty) {
        requestData['refer'] = refer;
      }

      final response = await _dio.post(
        ApiConfig.registerEndpoint,
        data: requestData,
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'];

        final token = data['token'];
        if (token != null) {
          await _storage.saveToken(token);
        }

        return ApiResult.success({
          'token': token,
          'user': data['user'],
          'expires_at': data['expires_at'],
        });
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Registration failed',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<String>> forgotPassword({required String email}) async {
    try {
      final response = await _dio.post(
        ApiConfig.forgotPasswordEndpoint,
        data: {'email': email},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        return ApiResult.success(
          responseData['message'] ?? 'OTP sent successfully',
        );
      }

      return ApiResult.failure(responseData['message'] ?? 'Failed to send OTP');
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<String>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyOtpEndpoint,
        data: {'email': email, 'otp': int.tryParse(otp) ?? otp},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        return ApiResult.success(responseData['message'] ?? 'OTP verified');
      }

      return ApiResult.failure(responseData['message'] ?? 'Invalid OTP');
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<String>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.resetPasswordEndpoint,
        data: {
          'email': email,
          'otp': int.tryParse(otp) ?? otp,
          'new_password': newPassword,
        },
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        return ApiResult.success(
          responseData['message'] ?? 'Password reset successful',
        );
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to reset password',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<String>> logout() async {
    try {
      final response = await _dio.post(ApiConfig.logoutEndpoint);

      final responseData = response.data;

      await _storage.deleteToken();

      if (responseData['ok'] == true) {
        return ApiResult.success('Logged out successfully');
      }

      return ApiResult.failure(responseData['message'] ?? 'Logout failed');
    } on DioException catch (e) {
      await _storage.deleteToken();
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      await _storage.deleteToken();
      return ApiResult.failure(e.toString());
    }
  }

  Future<ApiResult<String>> getNotice() async {
    try {
      final response = await _dio.get(ApiConfig.notificationsEndpoint);
      final responseData = response.data;

      if (responseData['ok'] == true) {
        final notice2 = responseData['data']['notice2']?.toString() ?? '';
        return ApiResult.success(notice2);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get notice',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // USER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ApiResult<User>> getMe() async {
    try {
      final response = await _dio.get(ApiConfig.userProfileEndpoint);

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'];
        final user = User.fromJson(data['user'] ?? data);
        return ApiResult.success(user);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get profile',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<User>> updateProfile({
    required String firstname,
    required String lastname,
    required String email,
    required String phone,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.updateProfileEndpoint,
        data: {
          'firstname': firstname,
          'lastname': lastname,
          'email': email,
          'phone': phone,
        },
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        return await getMe();
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to update profile',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<String>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.changePasswordEndpoint,
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        return ApiResult.success(
          responseData['message'] ?? 'Password changed successfully',
        );
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to change password',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<String>> setPin({required String pin}) async {
    try {
      final response = await _dio.post(
        ApiConfig.setPinEndpoint,
        data: {'pin': pin},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        return ApiResult.success(
          responseData['message'] ?? 'PIN set successfully',
        );
      }

      return ApiResult.failure(responseData['message'] ?? 'Failed to set PIN');
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<String>> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.changePinEndpoint,
        data: {'old_pin': oldPin, 'new_pin': newPin},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        return ApiResult.success(
          responseData['message'] ?? 'PIN changed successfully',
        );
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to change PIN',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  Future<ApiResult<bool>> verifyPinAPI({required String pin}) async {
    try {
      final response = await _dio.post(
        ApiConfig.changePinEndpoint,
        data: {'old_pin': pin, 'new_pin': pin},
      );
      final responseData = response.data;
      final msg = (responseData['message'] ?? '').toString().toLowerCase();

      if (responseData['ok'] == true) {
        return ApiResult.success(true);
      }

      if (msg.contains('new pin') ||
          msg.contains('new password') ||
          msg.contains('same') ||
          msg.contains('cannot be') ||
          msg.contains('confirm')) {
        return ApiResult.success(true);
      }

      return ApiResult.failure('Incorrect PIN. Please try again.');
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // KYC & WALLET
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ApiResult<List<VirtualAccount>>> verifyKyc({
    required String type,
    required String value,
    required String pincode,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'pincode': pincode,
        'bvn': '',
        'nin': '',
      };
      body[type] = value;

      final response = await _dio.post(ApiConfig.kycVerifyEndpoint, data: body);

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'] as Map<String, dynamic>? ?? {};
        final accounts = VirtualAccount.fromApiData(data);
        return ApiResult.success(accounts);
      }

      return ApiResult.failure(
        responseData['message']?.toString() ?? 'KYC verification failed',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<double>> getWalletBalance() async {
    try {
      final result = await getMe();
      if (result.success && result.data != null) {
        return ApiResult.success(result.data!.balance);
      }
      return ApiResult.failure(result.error ?? 'Failed to get balance');
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<List<VirtualAccount>>> getVirtualAccounts() async {
    final user = _storage.getUser();

    if (user == null) {
      return ApiResult.failure('User not logged in');
    }

    final accountName = user.fullName;
    final accounts = <VirtualAccount>[];

    if (user.wemaAccount != null && user.wemaAccount!.isNotEmpty) {
      accounts.add(
        VirtualAccount(
          bankName: 'Wema Bank',
          accountNumber: user.wemaAccount!,
          accountName: accountName,
          reference: '',
        ),
      );
    }

    if (user.moniepointAccount != null && user.moniepointAccount!.isNotEmpty) {
      accounts.add(
        VirtualAccount(
          bankName: 'Moniepoint MFB',
          accountNumber: user.moniepointAccount!,
          accountName: accountName,
          reference: '',
        ),
      );
    }

    if (user.sterlingAccount != null && user.sterlingAccount!.isNotEmpty) {
      accounts.add(
        VirtualAccount(
          bankName: 'Sterling Bank',
          accountNumber: user.sterlingAccount!,
          accountName: accountName,
          reference: '',
        ),
      );
    }

    if (accounts.isEmpty) {
      return ApiResult.failure('No virtual accounts found');
    }

    return ApiResult.success(accounts);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> initializePaystackPayment({
    required double amount,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.paystackInitEndpoint,
        data: {'amount': amount},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        return ApiResult.success(responseData['data']);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to initialize payment',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> verifyPaystackPayment({
    required String reference,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.paystackCallbackEndpoint,
        queryParameters: {'reference': reference},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        // Data might be a list or map, we just need to return success
        return ApiResult.success(responseData);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Payment verification failed',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLANS METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ApiResult<List<DataPlan>>> getDataPlans({String? network}) async {
    try {
      final response = await _dio.get(ApiConfig.dataPlansEndpoint);

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'];
        final plansData = data['plans'] as Map<String, dynamic>? ?? {};

        final List<DataPlan> allPlans = [];

        plansData.forEach((networkName, types) {
          if (network != null && networkName != network) return;

          if (types is Map<String, dynamic>) {
            types.forEach((typeName, plans) {
              if (plans is List) {
                for (final plan in plans) {
                  final planSize = plan['plan'] ?? '';
                  final size = plan['size'] ?? 'GB';
                  final planName = '$planSize$size';

                  allPlans.add(
                    DataPlan(
                      id: plan['id']?.toString() ?? '',
                      name: planName,
                      type: typeName,
                      price: (plan['price'] as num?)?.toDouble() ?? 0,
                      validity: plan['duration'] ?? '',
                      network: networkName,
                    ),
                  );
                }
              }
            });
          }
        });

        return ApiResult.success(allPlans);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get data plans',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure('Error parsing plans: $e');
    }
  }

  @override
  Future<ApiResult<List<AirtimeNetwork>>> getAirtimeNetworks() async {
    try {
      final response = await _dio.get(ApiConfig.airtimePlansEndpoint);

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final items = responseData['data']['items'] as List;
        final networks = items
            .map((e) => AirtimeNetwork.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResult.success(networks);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get airtime networks',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getCablePlans() async {
    try {
      final response = await _dio.get(ApiConfig.cablePlansEndpoint);
      final responseData = response.data;

      if (responseData['ok'] == true) {
        final items = responseData['data']['items'] as List;
        return ApiResult.success({'items': items});
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get cable plans',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<List<String>>> getElectricDiscos() async {
    try {
      final response = await _dio.get(ApiConfig.electricPlansEndpoint);
      final responseData = response.data;

      if (responseData['ok'] == true) {
        final items = responseData['data']['items'] as List;
        final discos = items.map((e) => e['code'].toString().trim()).toList();
        return ApiResult.success(discos);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get electricity discos',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<List<ExamType>>> getExamTypes() async {
    try {
      final response = await _dio.get(ApiConfig.examPlansEndpoint);
      final responseData = response.data;

      if (responseData['ok'] == true) {
        final items = responseData['data']['items'] as List;
        final examTypes = items.map((e) => ExamType.fromJson(e)).toList();
        return ApiResult.success(examTypes);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get exam types',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getDataCardPlans() async {
    try {
      final response = await _dio.get(ApiConfig.datacardPlansEndpoint);
      final responseData = response.data;

      if (responseData['ok'] == true) {
        final items = responseData['data']['items'] as List;
        return ApiResult.success({
          'server': responseData['data']['server'],
          'items': items,
        });
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get data card plans',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ApiResult<Map<String, dynamic>>> validateMeter({
    required String disco,
    required String meterNumber,
    required String meterType,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.electricValidateEndpoint,
        data: {
          'company': disco,
          'meterno': meterNumber,
          'meter_type': meterType
              .toUpperCase(), // API expects PREPAID / POSTPAID
        },
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'];
        return ApiResult.success({
          'customer_name': data['customer_name']?.toString() ?? '',
          'status': data['status']?.toString() ?? 'success',
        });
      }

      return ApiResult.failure(
        responseData['message']?.toString() ??
            'Failed to validate meter. Please check the details and try again.',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> validateSmartcard({
    required String provider,
    required String smartcard,
  }) async {
    try {
      // ✅ FIX: Use FormData so PHP reads fields via $_POST correctly.
      // The global Dio header sends 'Content-Type: application/json' which
      // PHP's cable_validate.php cannot parse — it reads $_POST not php://input.
      // FormData forces multipart encoding that PHP reads natively,
      // bypassing the global JSON Content-Type header.
      final response = await _dio.post(
        ApiConfig.cableValidateEndpoint,
        options: Options(
          validateStatus: (status) => status != null && status < 600,
          contentType: 'multipart/form-data',
        ),
        data: FormData.fromMap({'network': provider, 'iucno': smartcard}),
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'];
        return ApiResult.success({
          'customer_name': data['customer_name']?.toString() ?? '',
          'status': data['status']?.toString() ?? 'success',
        });
      }

      return ApiResult.failure(
        responseData['message']?.toString() ??
            'Failed to validate decoder. Please check the details and try again.',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PURCHASE METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ApiResult<Map<String, dynamic>>> buyAirtime({
    required String network,
    required String number,
    required double amount,
    required String pincode,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.buyAirtimeEndpoint,
        options: Options(
          validateStatus: (status) => status != null && status < 600,
        ),
        data: {
          'network': network,
          'number': number,
          'amount': amount,
          'pincode': pincode,
        },
      );

      final responseData = response.data;
      final topLevelMessage =
          responseData['message']?.toString() ?? 'Purchase failed';

      if (responseData['ok'] == true) {
        final Map<String, dynamic> body = Map<String, dynamic>.from(
          responseData,
        );
        final Map<String, dynamic>? data = body['data'] != null
            ? Map<String, dynamic>.from(body['data'])
            : null;

        final String status = (data?['status'] ?? '').toString().toUpperCase();

        if (status.isNotEmpty && status != 'SUCCESSFUL') {
          final String? providerMessage = data?['message']?.toString();
          final String errorMessage =
              (providerMessage != null && providerMessage.isNotEmpty)
              ? providerMessage
              : (topLevelMessage.isNotEmpty
                    ? topLevelMessage
                    : 'Transaction failed: $status');
          return ApiResult.failure(errorMessage);
        }

        return ApiResult.success({
          'transaction_id': data?['transaction_id']?.toString() ?? '',
          'status': status,
        });
      }

      return ApiResult.failure(topLevelMessage);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> buyData({
    required String network,
    required String dataType,
    required String dataPlan,
    required String number,
    required String pincode,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.buyDataEndpoint,
        options: Options(
          validateStatus: (status) => status != null && status < 600,
        ),
        data: {
          'network': network,
          'type': dataType,
          'dataBundle': int.tryParse(dataPlan) ?? dataPlan,
          'number': number,
          'pincode': pincode,
        },
      );

      final responseData = response.data;

      final Map<String, dynamic> body = Map<String, dynamic>.from(responseData);
      final Map<String, dynamic>? data = body['data'] != null
          ? Map<String, dynamic>.from(body['data'])
          : null;

      final String status = (data?['status'] ?? '').toString().toUpperCase();

      if (status != 'SUCCESSFUL') {
        return ApiResult.failure(
          data?['message']?.toString() ?? 'Transaction failed',
        );
      }

      return ApiResult.success({
        'transaction_id': data?['transaction_id']?.toString() ?? '',
        'status': status,
        'message': data?['message']?.toString() ?? '',
      });
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> buyCable({
    required String provider,
    required String planId,
    required String smartcard,
    required String pincode,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.buyCableEndpoint,
        data: {
          'provider': provider,
          'plan_id': planId,
          'smartcard': smartcard,
          'pincode': pincode,
        },
      );

      final responseData = response.data;
      final topLevelMessage =
          responseData['message']?.toString() ?? 'Purchase failed';

      if (responseData['ok'] == true) {
        final dynamic data = responseData['data'];

        final String status = (data != null ? (data['status'] ?? '') : '')
            .toString()
            .toUpperCase();
        if (status.isNotEmpty && status != 'SUCCESSFUL') {
          final String? providerMessage = data != null
              ? data['message']?.toString()
              : null;
          return ApiResult.failure(
            (providerMessage != null && providerMessage.isNotEmpty)
                ? providerMessage
                : (topLevelMessage.isNotEmpty
                      ? topLevelMessage
                      : 'Transaction failed: $status'),
          );
        }

        return ApiResult.success({
          'transaction_id':
              (data != null
                  ? (data['transaction_id'] ?? data['id'])?.toString()
                  : null) ??
              '',
          'reference': data != null ? data['reference']?.toString() : null,
          'balance': data != null
              ? (data['balance'] as num?)?.toDouble() ?? 0
              : 0.0,
        });
      }

      return ApiResult.failure(topLevelMessage);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> buyElectricity({
    required String disco,
    required String meter,
    required double amount,
    required String pincode,
    required String meterType,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.buyElectricEndpoint,
        data: {
          'network_code': disco,
          'number': meter,
          'type': 'electricity',
          'meter_type': meterType.toUpperCase(),
          'amount': amount,
          'pincode': pincode,
        },
      );

      final responseData = response.data;
      final topLevelMessage =
          responseData['message']?.toString() ?? 'Purchase failed';

      if (responseData['ok'] == true) {
        final dynamic data = responseData['data'];

        final String status = (data != null ? (data['status'] ?? '') : '')
            .toString()
            .toUpperCase();
        if (status.isNotEmpty && status != 'SUCCESSFUL') {
          final String? providerMessage = data != null
              ? data['message']?.toString()
              : null;
          return ApiResult.failure(
            (providerMessage != null && providerMessage.isNotEmpty)
                ? providerMessage
                : (topLevelMessage.isNotEmpty
                      ? topLevelMessage
                      : 'Transaction failed: $status'),
          );
        }

        return ApiResult.success({
          'transaction_id':
              (data != null
                  ? (data['transaction_id'] ?? data['id'])?.toString()
                  : null) ??
              '',
          'reference': data != null ? data['reference']?.toString() : null,
          'balance': data != null
              ? (data['balance'] as num?)?.toDouble() ?? 0
              : 0.0,
          'token': data != null ? data['token']?.toString() : null,
          'units': data != null ? data['units']?.toString() : null,
        });
      }

      return ApiResult.failure(topLevelMessage);
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> buyExamPin({
    required String examType,
    required int quantity,
    required String pincode,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.buyExamEndpoint,
        data: {'exam_type': examType, 'quantity': quantity, 'pincode': pincode},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'] ?? responseData;

        final status = (data['status'] ?? '').toString().toUpperCase();
        if (status.isNotEmpty && status != 'SUCCESSFUL') {
          final reason = data['message']?.toString();
          return ApiResult.failure(
            (reason != null && reason.isNotEmpty)
                ? reason
                : 'Transaction failed: $status',
          );
        }

        return ApiResult.success({
          'transaction_id': data['transaction_id'] ?? data['id'],
          'reference': data['reference'],
          'balance': (data['balance'] as num?)?.toDouble() ?? 0,
          'pins': data['pins'],
        });
      }

      return ApiResult.failure(responseData['message'] ?? 'Purchase failed');
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> buyDataCard({
    required String cardId,
    required int quantity,
    required String pincode,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.buyDatacardEndpoint,
        data: {'plan_id': cardId, 'quantity': quantity, 'pincode': pincode},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'] ?? responseData;

        final status = (data['status'] ?? '').toString().toUpperCase();
        if (status.isNotEmpty && status != 'SUCCESSFUL') {
          final reason = data['message']?.toString();
          return ApiResult.failure(
            (reason != null && reason.isNotEmpty)
                ? reason
                : 'Transaction failed: $status',
          );
        }

        return ApiResult.success({
          'transaction_id': data['transaction_id'] ?? data['id'],
          'reference': data['reference'],
          'balance': (data['balance'] as num?)?.toDouble() ?? 0,
          'pins': data['pins'],
        });
      }

      return ApiResult.failure(responseData['message'] ?? 'Purchase failed');
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ApiResult<PaginatedTransactions>> getTransactions({
    int page = 1,
    int limit = 10,
    String? type,
    String? status,
    String? search,
  }) async {
    try {
      final response = await _dio.get(ApiConfig.transactionsEndpoint);
      final responseData = response.data;

      if (responseData['ok'] == true) {
        final paginated = PaginatedTransactions.fromJson(responseData);
        return ApiResult.success(paginated);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get transactions',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<Transaction>> getTransactionDetail(String id) async {
    try {
      final response = await _dio.get(
        ApiConfig.transactionDetailEndpoint,
        queryParameters: {'transaction_id': id},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final tx = responseData['data']['transaction'];
        final transaction = Transaction.fromJson(tx);
        return ApiResult.success(transaction);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get transaction detail',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REFERRALS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ApiResult<ReferralStats>> getReferralStats() async {
    try {
      final response = await _dio.get(ApiConfig.referralHistoryEndpoint);
      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'];
        final refCredit =
            data['ref_credit'] ??
            data['commission_balance'] ??
            data['commission'] ??
            0;
        final count = data['count'] ?? data['total_referrals'] ?? 0;
        final totalEarnings =
            data['total_earnings'] ?? data['total_commission'] ?? refCredit;
        final stats = ReferralStats(
          totalEarnings: double.parse(totalEarnings.toString()),
          availableBalance: double.parse(refCredit.toString()),
          totalReferrals: int.tryParse(count.toString()) ?? 0,
          activeReferrals: int.tryParse(count.toString()) ?? 0,
        );
        return ApiResult.success(stats);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get referral stats',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<List<ReferralEarning>>> getReferralHistory() async {
    try {
      final response = await _dio.get(ApiConfig.referralHistoryEndpoint);
      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'];
        final items =
            (data['items'] ??
                    data['history'] ??
                    data['earnings'] ??
                    data['referrals'] ??
                    data['list'] ??
                    [])
                as List;
        final earnings = items.map((e) => ReferralEarning.fromJson(e)).toList();
        return ApiResult.success(earnings);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to get referral history',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> withdrawReferralEarnings({
    required double amount,
    required String pincode,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.withdrawCommissionEndpoint,
        data: {'amount': amount, 'pincode': pincode},
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        final data = responseData['data'] as Map<String, dynamic>;
        return ApiResult.success({
          'reference': data['reference'],
          'amount': (data['amount'] as num?)?.toDouble() ?? amount,
          'wallet_balance': (data['wallet_balance'] as num?)?.toDouble() ?? 0.0,
          'commission_balance':
              (data['commission_balance'] as num?)?.toDouble() ?? 0.0,
          'message': responseData['message'] ?? 'Withdrawal successful',
        });
      }

      return ApiResult.failure(responseData['message'] ?? 'Withdrawal failed');
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AIRTIME TO CASH
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<ApiResult<Map<String, dynamic>>> submitATCRequest({
    required String network,
    required double amount,
    required String number,
    required String paymentMethod,
    String? accountNumber,
    String? bankName,
    String? accountName,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'network': network,
        'amount': amount.toInt(),
        'sender_phone': number,
        'payment_method': paymentMethod,
      };

      if (paymentMethod == 'bank') {
        if (accountName != null && accountName.isNotEmpty) {
          body['account_name'] = accountName;
        }
        if (accountNumber != null && accountNumber.isNotEmpty) {
          body['account_number'] = accountNumber;
        }
        if (bankName != null && bankName.isNotEmpty) {
          body['bank_name'] = bankName;
        }
      }

      final response = await _dio.post(
        ApiConfig.atcRequestEndpoint,
        data: body,
      );

      final responseData = response.data;

      if (responseData['ok'] == true) {
        return ApiResult.success(responseData['data']);
      }

      return ApiResult.failure(responseData['message'] ?? 'Request failed');
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR HANDLING
  // ═══════════════════════════════════════════════════════════════════════════

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please try again.';

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;

        if (data is Map && data['message'] != null) {
          return data['message'];
        }

        if (statusCode == 401) {
          return 'Session expired. Please login again.';
        }

        return 'Server error: ${statusCode ?? 'Unknown'}';

      case DioExceptionType.cancel:
        return 'Request cancelled';

      case DioExceptionType.unknown:
        if (e.message?.contains('SocketException') == true) {
          return 'No internet connection';
        }
        return 'Connection failed. Please check your internet.';

      default:
        return 'An error occurred. Please try again.';
    }
  }

  @override
  Future<ApiResult<List<ATCNetwork>>> getATCNetworks() async {
    try {
      final response = await _dio.get(ApiConfig.atcNetworksEndpoint);
      final responseData = response.data;

      if (responseData['ok'] == true) {
        final items = responseData['data']['items'] as List;
        final networks = items
            .map((e) => ATCNetwork.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResult.success(networks);
      }

      return ApiResult.failure(
        responseData['message'] ?? 'Failed to load ATC networks',
      );
    } on DioException catch (e) {
      return ApiResult.failure(_handleDioError(e));
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INTERCEPTORS
// ═══════════════════════════════════════════════════════════════════════════

class _AuthInterceptor extends Interceptor {
  final StorageService _storage;

  _AuthInterceptor(this._storage);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    super.onRequest(options, handler);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 &&
        !(err.requestOptions.path.contains('login'))) {
      ApiService.onUnauthenticated.add(null);
    }

    super.onError(err, handler);
  }
}
