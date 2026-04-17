import 'dart:async';
import '../../config/api_result.dart';
import '../../models/airtime_network_model.dart';
import '../../models/atc_request_model.dart';
import '../../models/data_plan_model.dart';
import '../../models/exam_type_model.dart';
import '../../models/referral_model.dart';
import '../../models/transaction_model.dart';
import '../../models/user_model.dart';
import '../../models/virtual_account_model.dart';

abstract class ApiService {
  static final StreamController<void> onUnauthenticated =
      StreamController<void>.broadcast();

  // ========== AUTHENTICATION ==========

  Future<ApiResult<Map<String, dynamic>>> register({
    required String firstname,
    required String lastname,
    required String username,
    required String email,
    required String phone,
    required String password,
    String? refer,
  });

  Future<ApiResult<Map<String, dynamic>>> login({
    required String username,
    required String password,
  });

  Future<ApiResult<String>> forgotPassword({required String email});

  Future<ApiResult<String>> verifyOtp({
    required String email,
    required String otp,
  });

  Future<ApiResult<String>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  });

  Future<ApiResult<String>> logout();

  // ========== USER ==========

  Future<ApiResult<User>> getMe();

  Future<ApiResult<String>> getNotice();

  Future<ApiResult<User>> updateProfile({
    required String firstname,
    required String lastname,
    required String email,
    required String phone,
  });

  Future<ApiResult<String>> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  Future<ApiResult<String>> setPin({required String pin});

  Future<ApiResult<String>> changePin({
    required String oldPin,
    required String newPin,
  });

  // ========== KYC & WALLET ==========

  Future<ApiResult<List<VirtualAccount>>> verifyKyc({
    required String type,
    required String value,
    required String pincode,
  });

  Future<ApiResult<double>> getWalletBalance();

  Future<ApiResult<List<VirtualAccount>>> getVirtualAccounts();

  Future<ApiResult<Map<String, dynamic>>> initializePaystackPayment({
    required double amount,
  });

  Future<ApiResult<Map<String, dynamic>>> verifyPaystackPayment({
    required String reference,
  });

  // ========== PLANS ==========

  Future<ApiResult<List<DataPlan>>> getDataPlans({String? network});

  Future<ApiResult<List<AirtimeNetwork>>> getAirtimeNetworks();

  Future<ApiResult<Map<String, dynamic>>> getCablePlans();

  Future<ApiResult<List<String>>> getElectricDiscos();

  Future<ApiResult<List<ExamType>>> getExamTypes();

  Future<ApiResult<Map<String, dynamic>>> getDataCardPlans();

  // ========== VALIDATION ==========

  Future<ApiResult<Map<String, dynamic>>> validateMeter({
    required String disco,
    required String meterNumber,
    required String meterType,
  });

  Future<ApiResult<Map<String, dynamic>>> validateSmartcard({
    required String provider,
    required String smartcard,
  });

  // ========== PURCHASES ==========

  Future<ApiResult<Map<String, dynamic>>> buyAirtime({
    required String network,
    required String number,
    required double amount,
    required String pincode,
  });

  Future<ApiResult<Map<String, dynamic>>> buyData({
    required String network,
    required String dataType,
    required String dataPlan,
    required String number,
    required String pincode,
  });

  Future<ApiResult<Map<String, dynamic>>> buyCable({
    required String provider,
    required String planId,
    required String smartcard,
    required String pincode,
  });

  Future<ApiResult<Map<String, dynamic>>> buyElectricity({
    required String disco,
    required String meter,
    required double amount,
    required String pincode,
    required String meterType,
  });

  Future<ApiResult<Map<String, dynamic>>> buyExamPin({
    required String examType,
    required int quantity,
    required String pincode,
  });

  Future<ApiResult<Map<String, dynamic>>> buyDataCard({
    required String cardId,
    required int quantity,
    required String pincode,
  });

  // ========== TRANSACTIONS ==========

  Future<ApiResult<PaginatedTransactions>> getTransactions({
    int page = 1,
    int limit = 10,
    String? type,
    String? status,
    String? search,
  });

  Future<ApiResult<Transaction>> getTransactionDetail(String id);

  // ========== REFERRALS ==========

  Future<ApiResult<ReferralStats>> getReferralStats();

  Future<ApiResult<List<ReferralEarning>>> getReferralHistory();

  Future<ApiResult<Map<String, dynamic>>> withdrawReferralEarnings({
    required double amount,
    required String pincode,
  });

  // ========== AIRTIME TO CASH ==========
  Future<ApiResult<List<ATCNetwork>>> getATCNetworks();

  Future<ApiResult<Map<String, dynamic>>> submitATCRequest({
    required String network,
    required double amount,
    required String number,
    required String paymentMethod, // 'bank' or 'wallet'
    String? accountNumber,
    String? bankName,
    String? accountName,
  });

  Future<ApiResult<List<ATCRequest>>> getATCHistory();
}
