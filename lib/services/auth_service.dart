import 'api/api_service.dart';
// import 'api/mock_api_service.dart';
import 'api/real_api_service.dart';
import 'storage_service.dart';
import '../core/api_result.dart';
import '../models/user_model.dart';

class AuthService {
  late final ApiService _api;
  final StorageService _storage = StorageService();

  AuthService({bool useMock = false}) {
    _api = RealApiService();
  }

  // Login
  Future<ApiResult<User>> login(String username, String password) async {
    final response = await _api.login(username: username, password: password);

    if (response.success && response.data != null) {
      // Save token
      await _storage.saveToken(response.data!['token']);

      // Save token expiry if provided
      if (response.data!['expires_at'] != null) {
        await _storage.saveTokenExpiry(response.data!['expires_at']);
      }

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
      // Save token expiry if provided
      if (response.data!['expires_at'] != null) {
        await _storage.saveTokenExpiry(response.data!['expires_at']);
      }
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
    await _storage.clearAuth();
  }

  // Check if logged in and token is not expired
  Future<bool> isLoggedIn() async {
    String? token = await _storage.getToken();
    if (token == null || token.isEmpty) return false;

    String? expiryStr = _storage.getTokenExpiry();
    if (expiryStr != null && expiryStr.isNotEmpty) {
      try {
        final expiryDate = DateTime.parse(expiryStr);
        if (DateTime.now().isAfter(expiryDate)) {
          // Token expired, clear auth
          await _storage.clearAuth();
          return false;
        }
      } catch (e) {
        // If parsing fails, assume expired for safety
        return false;
      }
    }

    return true;
  }

  // Get current user from storage
  User? getCurrentUser() {
    return _storage.getUser();
  }

  // Get API service (for use in other services/providers)
  ApiService get api => _api;
}
