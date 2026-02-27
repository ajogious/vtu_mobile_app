/// Nigerian network prefix validator.
/// Used to warn (not hard-block) when a phone number prefix doesn't match
/// the selected network — because numbers can be ported.

class NigeriaNetworkValidator {
  /// Map of network name → list of valid prefixes
  static const Map<String, List<String>> _networkPrefixes = {
    'MTN': [
      '0703',
      '0706',
      '0803',
      '0806',
      '0810',
      '0813',
      '0814',
      '0816',
      '0903',
      '0906',
      '0913',
      '0916',
    ],
    'GLO': ['0705', '0805', '0807', '0811', '0815', '0905'],
    'AIRTEL': [
      '0701',
      '0708',
      '0802',
      '0808',
      '0812',
      '0901',
      '0902',
      '0904',
      '0907',
    ],
    '9MOBILE': ['0809', '0817', '0818', '0908', '0909'],
  };

  /// Returns the expected network name for a given phone number.
  /// Returns null if the prefix is unrecognized.
  static String? getNetworkForNumber(String phone) {
    final normalized = _normalize(phone);
    if (normalized == null) return null;

    final prefix = normalized.substring(0, 4);

    for (final entry in _networkPrefixes.entries) {
      if (entry.value.contains(prefix)) {
        return entry.key;
      }
    }

    return null; // Unknown prefix
  }

  /// Returns a mismatch warning message if the phone prefix suggests a
  /// different network than selected. Returns null if all looks fine.
  ///
  /// NOTE: This is a SOFT warning only — numbers can be ported, so the
  /// user should be allowed to proceed after acknowledging the warning.
  static String? getMismatchWarning(String phone, String selectedNetwork) {
    final normalized = _normalize(phone);
    if (normalized == null) return null;

    final detectedNetwork = getNetworkForNumber(normalized);

    if (detectedNetwork == null) {
      // Unknown prefix — can't validate, don't warn
      return null;
    }

    if (detectedNetwork != selectedNetwork.toUpperCase()) {
      return '$normalized looks like a $detectedNetwork number, '
          'but you selected $selectedNetwork.';
    }

    return null; // No mismatch
  }

  /// Normalizes phone number to 11-digit format starting with 0.
  static String? _normalize(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    if (cleaned.startsWith('+234')) {
      cleaned = '0${cleaned.substring(4)}';
    } else if (cleaned.startsWith('234')) {
      cleaned = '0${cleaned.substring(3)}';
    }

    if (cleaned.length != 11 || !cleaned.startsWith('0')) {
      return null;
    }

    return cleaned;
  }

  /// Returns all prefixes for a given network (useful for UI hints).
  static List<String>? getPrefixesForNetwork(String network) {
    return _networkPrefixes[network.toUpperCase()];
  }
}
