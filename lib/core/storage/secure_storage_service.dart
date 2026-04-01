import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/auth_tokens.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'auth.access_token';
  static const String _refreshTokenKey = 'auth.refresh_token';

  Future<void> saveTokens(AuthTokens tokens) async {
    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
    if (tokens.refreshToken != null && tokens.refreshToken!.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
    } else {
      await _storage.delete(key: _refreshTokenKey);
    }
  }

  Future<AuthTokens?> readTokens() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    if (accessToken == null || accessToken.trim().isEmpty) {
      return null;
    }

    final refreshToken = await _storage.read(key: _refreshTokenKey);
    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
