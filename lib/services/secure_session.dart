/// Secure storage for the session token — the only secret v0.1 holds.
///
/// v0.1 auth is local-only (no backend): sign-in creates a local profile
/// and a random session token. The token lives in the platform keychain
/// / keystore via `flutter_secure_storage` (localStorage on web), never
/// in shared_preferences and never in the report JSON.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSession {
  static const _tokenKey = 'fp.session_token.v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Creates and stores a new session token for [email].
  Future<String> createSession(String email) async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final token =
        'fp_${base64Url.encode(bytes).replaceAll('=', '')}';
    await _storage.write(key: _tokenKey, value: '$email|$token');
    return token;
  }

  /// The stored session (`email|token`), or null when signed out.
  Future<String?> readSession() => _storage.read(key: _tokenKey);

  Future<void> clearSession() => _storage.delete(key: _tokenKey);
}
