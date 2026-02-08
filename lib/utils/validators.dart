class Validators {
  // Email validation
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Nigerian phone number validation
  static String? nigerianPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }

    // Remove spaces and special characters
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check if it's a valid Nigerian number
    // Formats: 08012345678, +2348012345678, 2348012345678
    final phoneRegex = RegExp(r'^(\+?234|0)[789][01]\d{8}$');

    if (!phoneRegex.hasMatch(cleaned)) {
      return 'Please enter a valid Nigerian phone number';
    }

    return null;
  }

  // Username validation
  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a username';
    }

    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }

    if (value.trim().length > 20) {
      return 'Username must be less than 20 characters';
    }

    // Only letters, numbers, and underscores
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value.trim())) {
      return 'Username can only contain letters, numbers, and underscores';
    }

    return null;
  }

  // Name validation
  static String? name(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your $fieldName';
    }

    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }

    // Only letters and spaces
    final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
    if (!nameRegex.hasMatch(value.trim())) {
      return '$fieldName can only contain letters';
    }

    return null;
  }

  // Password validation
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  // Confirm password validation
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  // Required field validation
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }
}
