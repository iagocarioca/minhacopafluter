import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../domain/models/auth_tokens.dart';
import '../../../domain/models/user.dart';
import '../data/auth_remote_data_source.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService secureStorage,
  }) : _remoteDataSource = remoteDataSource,
       _secureStorage = secureStorage;

  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorage;

  AuthTokens? _tokens;
  User? _currentUser;
  bool _initialized = false;
  bool _loading = false;
  String? _errorMessage;
  Completer<bool>? _refreshCompleter;

  bool get initialized => _initialized;
  bool get isLoading => _loading;
  bool get isAuthenticated =>
      _tokens != null && _tokens!.accessToken.trim().isNotEmpty;
  String? get accessToken => _tokens?.accessToken;
  String? get refreshToken => _tokens?.refreshToken;
  bool get hasRefreshToken => _tokens?.hasRefreshToken == true;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _tokens = await _secureStorage.readTokens();
    if (_tokens != null) {
      await _fetchCurrentUserWithFallback();
    }

    _initialized = true;
    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final response = await _remoteDataSource.login(
        username: username,
        password: password,
      );

      if (response.tokens.accessToken.isEmpty) {
        throw ApiException(message: 'Login sem token de acesso');
      }

      _tokens = response.tokens;
      await _secureStorage.saveTokens(_tokens!);

      _currentUser =
          response.user ??
          await _remoteDataSource.fetchCurrentUser(_tokens!.accessToken);

      _initialized = true;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _resolveErrorMessage(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _remoteDataSource.register(
        username: username,
        email: email,
        password: password,
      );
      return true;
    } catch (error) {
      _errorMessage = _resolveErrorMessage(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  Future<bool> refreshAccessToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final currentRefreshToken = refreshToken;
    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      return false;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final nextTokens = await _remoteDataSource.refreshAccessToken(
        currentRefreshToken,
      );
      if (nextTokens.accessToken.isEmpty) {
        await _clearSession();
        completer.complete(false);
        return false;
      }

      _tokens = AuthTokens(
        accessToken: nextTokens.accessToken,
        refreshToken: nextTokens.refreshToken ?? currentRefreshToken,
      );
      await _secureStorage.saveTokens(_tokens!);
      completer.complete(true);
      notifyListeners();
      return true;
    } catch (_) {
      await _clearSession();
      completer.complete(false);
      notifyListeners();
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _fetchCurrentUserWithFallback() async {
    if (_tokens == null || _tokens!.accessToken.isEmpty) {
      return;
    }

    try {
      _currentUser = await _remoteDataSource.fetchCurrentUser(
        _tokens!.accessToken,
      );
    } catch (_) {
      final refreshed = await refreshAccessToken();
      if (!refreshed || _tokens == null) {
        await _clearSession();
        return;
      }

      try {
        _currentUser = await _remoteDataSource.fetchCurrentUser(
          _tokens!.accessToken,
        );
      } catch (_) {
        await _clearSession();
      }
    }
  }

  Future<void> _clearSession() async {
    _tokens = null;
    _currentUser = null;
    _errorMessage = null;
    await _secureStorage.clearTokens();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  String _resolveErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Erro inesperado de autenticacao';
  }
}
