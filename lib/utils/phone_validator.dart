class PhoneValidator {
  PhoneValidator._();

  static bool isValidIndonesianPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;

    // Format: 628xxxxxxxxx (11-13 digits after 62)
    if (digits.startsWith('628')) {
      return digits.length >= 12 && digits.length <= 14;
    }

    // Format: 08xxxxxxxxx (10-12 digits)
    if (digits.startsWith('08')) {
      return digits.length >= 11 && digits.length <= 13;
    }

    // Format: 8xxxxxxxxx (9-11 digits without 0 or country code)
    if (digits.startsWith('8')) {
      return digits.length >= 10 && digits.length <= 12;
    }

    return false;
  }

  static String normalizePhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('62')) {
      return '+$digits';
    }

    if (digits.startsWith('0')) {
      return '+62${digits.substring(1)}';
    }

    if (digits.startsWith('8')) {
      return '+62$digits';
    }

    return '+62$digits';
  }
}
