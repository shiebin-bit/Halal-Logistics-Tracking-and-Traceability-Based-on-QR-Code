import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Centralized helper for login session persistence and account security state.
///
/// Stores sensitive token data in secure storage while keeping compatibility
/// with existing `SharedPreferences` keys used by legacy screens.
class AuthSessionService {
  AuthSessionService._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _secureTokenKey = 'secure_auth_token';
  static const String _rememberMeKey = 'remember_me';
  static const String _savedEmailKey = 'saved_email';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _failedAttemptsKey = 'login_failed_attempts';
  static const String _lockoutUntilKey = 'login_lockout_until_ms';

  /// Saves current login context after successful authentication.
  static Future<void> saveLoginSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('auth_token', token); // Legacy compatibility.
    await prefs.setString('userRole', (user['role'] ?? '').toString());
    await prefs.setString('userName', (user['name'] ?? '').toString());

    if (user['id'] != null) {
      await prefs.setString('userId', user['id'].toString());
    }

    await _secureStorage.write(key: _secureTokenKey, value: token);
  }

  /// Reads the token from secure storage only.
  static Future<String?> getSecureToken() async {
    final secureToken = await _secureStorage.read(key: _secureTokenKey);
    if (secureToken == null || secureToken.isEmpty) {
      return null;
    }
    return secureToken;
  }

  /// Returns an auth token with migration support from legacy plain storage.
  static Future<String?> getToken() async {
    final secureToken = await getSecureToken();
    if (secureToken != null) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('auth_token') != secureToken) {
        await prefs.setString('auth_token', secureToken);
      }
      return secureToken;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString('auth_token');
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secureStorage.write(key: _secureTokenKey, value: legacyToken);
      return legacyToken;
    }

    return null;
  }

  /// Clears session data while optionally preserving remembered email.
  static Future<void> clearAuthSession({
    bool preserveRememberedEmail = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final rememberMe =
        preserveRememberedEmail && (prefs.getBool(_rememberMeKey) ?? false);
    final rememberedEmail = preserveRememberedEmail
        ? prefs.getString(_savedEmailKey)
        : null;

    await prefs.clear();
    await _secureStorage.delete(key: _secureTokenKey);

    if (rememberMe && rememberedEmail != null && rememberedEmail.isNotEmpty) {
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_savedEmailKey, rememberedEmail);
    }
  }

  /// Validates the persisted token by requesting `/user` and refreshes cache.
  static Future<Map<String, dynamic>?> validateTokenAndFetchUser() async {
    final token = await getToken();
    if (token == null) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = (data['user'] as Map?)?.cast<String, dynamic>();
        if (user == null) {
          return null;
        }

        await saveLoginSession(token: token, user: user);
        return user;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearAuthSession();
        return null;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Enables or disables biometric login preference.
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  static Future<void> setRememberMe({
    required bool rememberMe,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_savedEmailKey, email.trim());
      return;
    }

    await prefs.remove(_rememberMeKey);
    await prefs.remove(_savedEmailKey);
  }

  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedEmailKey);
  }

  static Future<int> getFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_failedAttemptsKey) ?? 0;
  }

  static Future<void> setFailedAttempts(int attempts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_failedAttemptsKey, attempts);
  }

  static Future<DateTime?> getLockoutUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutMs = prefs.getInt(_lockoutUntilKey);
    if (lockoutMs == null || lockoutMs <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(lockoutMs);
  }

  static Future<void> setLockoutUntil(DateTime? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_lockoutUntilKey);
      return;
    }
    await prefs.setInt(_lockoutUntilKey, value.millisecondsSinceEpoch);
  }

  static Future<void> clearLockout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failedAttemptsKey);
    await prefs.remove(_lockoutUntilKey);
  }
}
