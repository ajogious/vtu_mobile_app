import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart' as local_auth;
import 'package:flutter/services.dart';
import 'storage_service.dart';

enum BiometricResult {
  success,
  failed,
  notAvailable,
  notEnrolled,
  lockedOut,
  cancelled,
  fallbackRequested,
}

class BiometricService {
  static final local_auth.LocalAuthentication _auth =
      local_auth.LocalAuthentication();

  /// Check if device supports biometrics at all
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Check if biometrics are available and enrolled
  static Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;

      final canCheck = await _auth.canCheckBiometrics;
      return canCheck;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<local_auth.BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Get biometric type label for display
  static Future<String> getBiometricLabel() async {
    try {
      final biometrics = await getAvailableBiometrics();

      if (biometrics.contains(local_auth.BiometricType.face)) {
        return 'Face ID';
      } else if (biometrics.contains(local_auth.BiometricType.fingerprint)) {
        return 'Fingerprint';
      } else if (biometrics.contains(local_auth.BiometricType.iris)) {
        return 'Iris Scan';
      } else if (biometrics.contains(local_auth.BiometricType.strong)) {
        return 'Biometric';
      } else if (biometrics.contains(local_auth.BiometricType.weak)) {
        return 'Biometric';
      }

      return 'Biometric';
    } catch (e) {
      return 'Biometric';
    }
  }

  /// Get biometric icon for display
  static Future<IconData> getBiometricIcon() async {
    try {
      final biometrics = await getAvailableBiometrics();

      if (biometrics.contains(local_auth.BiometricType.face)) {
        return Icons.face;
      } else if (biometrics.contains(local_auth.BiometricType.fingerprint)) {
        return Icons.fingerprint;
      } else if (biometrics.contains(local_auth.BiometricType.iris)) {
        return Icons.remove_red_eye;
      }

      return Icons.fingerprint;
    } catch (e) {
      return Icons.fingerprint;
    }
  }

  /// Check if biometric is enabled in settings
  static bool isBiometricEnabled() {
    final storage = StorageService();
    return storage.getBiometricEnabled();
  }

  /// Core authentication method
  static Future<BiometricResult> authenticate({
    required String reason,
    bool biometricOnly = false,
    bool sensitiveTransaction = false,
  }) async {
    try {

      // Check if device supports biometrics
      final canAuth = await canAuthenticate();
      if (!canAuth) {
        return BiometricResult.notAvailable;
      }

      // Check if biometrics are enrolled
      final biometrics = await getAvailableBiometrics();
      if (biometrics.isEmpty) {
        return BiometricResult.notEnrolled;
      }

      // ignore: deprecated_member_use
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        // ignore: deprecated_member_use
        biometricOnly: biometricOnly,
        // ignore: deprecated_member_use
        sensitiveTransaction: sensitiveTransaction,
      );

      return authenticated ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();

      if (code.contains('notavailable') || code.contains('not_available')) {
        return BiometricResult.notAvailable;
      } else if (code.contains('notenrolled') ||
          code.contains('not_enrolled')) {
        return BiometricResult.notEnrolled;
      } else if (code.contains('lockedout') || code.contains('locked_out')) {
        return BiometricResult.lockedOut;
      } else if (code.contains('passcodenotset') ||
          code.contains('passcode_not_set')) {
        return BiometricResult.notAvailable;
      } else if (code.contains('cancel')) {
        return BiometricResult.cancelled;
      }

      return BiometricResult.failed;
    } catch (e) {
      return BiometricResult.failed;
    }
  }

  /// Authenticate for app unlock — biometric only (no pattern/PIN fallback)
  static Future<BiometricResult> authenticateForAppUnlock() async {
    return authenticate(
      reason: 'Use your fingerprint or face to unlock the app',
      biometricOnly: true,
      sensitiveTransaction: false,
    );
  }

  /// Authenticate for transaction — biometric only (no pattern/PIN fallback)
  static Future<BiometricResult> authenticateForTransaction({
    required String transactionDescription,
  }) async {
    return authenticate(
      reason: 'Use your fingerprint or face to confirm: $transactionDescription',
      biometricOnly: true,
      sensitiveTransaction: true,
    );
  }

  /// Cancel any ongoing authentication
  static Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
