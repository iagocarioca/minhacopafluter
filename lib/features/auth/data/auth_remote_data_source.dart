import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/auth_tokens.dart';
import '../../../domain/models/user.dart';

class LoginResponse {
  const LoginResponse({required this.tokens, this.user});

  final AuthTokens tokens;
  final User? user;
}

class AuthRemoteDataSource {
  AuthRemoteDataSource({required String baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          headers: <String, dynamic>{'Content-Type': 'application/json'},
        ),
      );

  final Dio _dio;

  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/usuarios/login',
        data: <String, dynamic>{'username': username, 'password': password},
      );

      final payload = parseMap(response.data);
      final tokens = AuthTokens.fromJson(payload);
      final userPayload = parseMap(payload['usuario']);
      final user = userPayload.isEmpty ? null : User.fromJson(userPayload);

      return LoginResponse(tokens: tokens, user: user);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? tipoUsuario,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/api/usuarios/registrar',
        data: <String, dynamic>{
          'username': username,
          'email': email,
          'password': password,
          if (tipoUsuario != null && tipoUsuario.trim().isNotEmpty)
            'tipo_usuario': tipoUsuario.trim(),
        },
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<User> fetchCurrentUser(String accessToken) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/usuarios/me',
        options: Options(
          headers: <String, dynamic>{'Authorization': 'Bearer $accessToken'},
        ),
      );

      final payload = parseMap(response.data);
      final userPayload = payload.containsKey('usuario')
          ? parseMap(payload['usuario'])
          : payload;

      return User.fromJson(userPayload);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<AuthTokens> refreshAccessToken(String refreshToken) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/usuarios/refresh',
        options: Options(
          headers: <String, dynamic>{'Authorization': 'Bearer $refreshToken'},
        ),
      );

      final payload = parseMap(response.data);
      final accessToken = parseString(payload['token_acesso']);
      final nextRefreshToken = parseString(payload['token_atualizacao']);

      return AuthTokens(
        accessToken: accessToken ?? '',
        refreshToken: nextRefreshToken ?? refreshToken,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
