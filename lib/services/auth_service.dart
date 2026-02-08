import 'api/api_service.dart';
import 'api/mock_api_service.dart';
import 'storage_service.dart';
import '../config/api_config.dart';
import '../core/api_result.dart';
import '../models/user_model.dart';

class AuthService {
  late ApiService _api;
  final StorageService _storage = StorageService();

  AuthService() {
    // Switch between mock and real API based on environment
    if (ApiConfig.isMock) {
      _api = MockApiService();
    } else {
      // _api = RealApiService(); // Will create this on Day 26
      _api = MockApiService(); // Fallback to mock for now
    }
  }

  // Login
  Future<ApiResult<User>> login(String username, String password) async {
    final response = await _api.login(username: username, password: password);

    if (response.success && response.data != null) {
      // Save token
      await _storage.saveToken(response.data!['token']);

      // Save user
      final user = User.fromJson(response.data!['user']);
      await _storage.saveUser(user);

      return ApiResult.success(user, message: response.message);
    }

    return ApiResult.failure(
      response.error ?? 'Login failed',
      message: response.message,
    );
  }

  // Register
  Future<ApiResult<User>> register({
    required String firstname,
    required String lastname,
    required String username,
    required String email,
    required String phone,
    required String password,
    String? refer,
  }) async {
    final response = await _api.register(
      firstname: firstname,
      lastname: lastname,
      username: username,
      email: email,
      phone: phone,
      password: password,
      refer: refer,
    );

    if (response.success && response.data != null) {
      final user = User.fromJson(response.data!['user']);
      return ApiResult.success(user, message: response.message);
    }

    return ApiResult.failure(
      response.error ?? 'Registration failed',
      message: response.message,
    );
  }

  // Logout
  Future<void> logout() async {
    await _api.logout();
    await _storage.clearAll();
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    String? token = await _storage.getToken();
    return token != null && token.isNotEmpty;
  }

  // Get current user from storage
  User? getCurrentUser() {
    return _storage.getUser();
  }

  // Get API service (for use in other services/providers)
  ApiService get api => _api;
}
