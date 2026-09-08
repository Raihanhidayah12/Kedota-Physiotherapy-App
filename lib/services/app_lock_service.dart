import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static const _keyLocked = 'app_locked';
  static const _keyUserPhone = 'user_phone';

  /// Tandai app sebagai terkunci
  static Future<void> lock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocked, true);
  }

  /// Tandai app sebagai sudah dibuka
  static Future<void> unlock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocked, false);
  }

  /// Cek apakah app dalam keadaan terkunci
  static Future<bool> isLocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLocked) ?? false;
  }

  /// Cek apakah biometric aktif untuk phone ini
  static Future<bool> isBiometricEnabled(String phone) async {
    if (phone.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_pin_enabled_$phone') ?? false;
  }

  /// Simpan phone number user yang sedang login
  static Future<void> setUserPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserPhone, phone);
  }

  /// Hapus phone number user (saat logout)
  static Future<void> clearUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserPhone);
  }

  /// Ambil phone number user yang sedang login
  static Future<String?> getBoundPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserPhone);
  }
}
