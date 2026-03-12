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

  // Check if logged in and token is not expired.
  //
  // The server returns `expires_at` as "YYYY-MM-DD HH:MM:SS" with no timezone
  // suffix (implicitly UTC on the server). We always normalise it to UTC before
  // comparing so that devices in non-UTC timezones don't get a false "expired"
  // result. A 7-day early-expiry buffer is applied so the session is refreshed
  // proactively before the user ever hits the real expiry moment.
  Future<bool> isLoggedIn() async {
    String? token = await _storage.getToken();
    if (token == null || token.isEmpty) return false;

    String? expiryStr = _storage.getTokenExpiry();
    if (expiryStr != null && expiryStr.isNotEmpty) {
      try {
        // Normalise "YYYY-MM-DD HH:MM:SS" → ISO-8601 UTC so DateTime.parse
        // always treats it as UTC regardless of the device locale.
        final normalised =
            expiryStr.replaceAll(' ', 'T') +
            (expiryStr.contains('Z') || expiryStr.contains('+') ? '' : 'Z');
        final expiryDate = DateTime.parse(normalised).toLocal();

        // Apply a 7-day proactive buffer so we refresh sessions before they
        // actually expire, avoiding last-second log-outs.
        final effectiveExpiry = expiryDate.subtract(const Duration(days: 7));

        if (DateTime.now().isAfter(effectiveExpiry)) {
          // Token is expired (or within the 7-day buffer). Clear auth.
          await _storage.clearAuth();
          return false;
        }
      } catch (_) {
        // Parsing failed — the expiry string is malformed or the format
        // changed. Trust the stored token and let the server respond with
        // a 401 if it's actually invalid. Do NOT silently log the user out.
        return true;
      }
    }

    return true;
  }

  /// Silently re-issues a fresh token by logging in with the credentials
  /// that are already saved in secure storage (used by biometrics).
  ///
  /// Returns `true` if a new token was successfully obtained and stored.
  /// Returns `false` if credentials are missing or the request failed
  /// (caller should fall back to showing the login screen).
  Future<bool> silentRefresh() async {
    try {
      final username = _storage.getLastUsername();
      final password = await _storage.getPassword();

      if (username == null ||
          username.isEmpty ||
          password == null ||
          password.isEmpty) {
        return false;
      }

      final result = await login(username, password);
      return result.success;
    } catch (_) {
      return false;
    }
  }

  // Get current user from storage
  User? getCurrentUser() {
    return _storage.getUser();
  }

  // Get API service (for use in other services/providers)
  ApiService get api => _api;
}
