import 'package:dio/dio.dart';

import '../../features/auth/state/auth_controller.dart';
import '../config/app_config.dart';

class ApiClient {
  ApiClient({required AppConfig config, required AuthController authController})
    : _authController = authController,
      dio = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  final Dio dio;
  final AuthController _authController;
  bool get isSeguidor => _authController.isSeguidor;
  String? get tipoUsuario => _authController.tipoUsuario;

  static const String _retriedKey = 'auth_retry_done';
  static const String _retryFormDataKey = 'retry_form_data';

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _authController.accessToken;
    if (token != null && token.isNotEmpty && !_isAuthEndpoint(options.path)) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    final isMultipart = options.data is FormData;
    if (isMultipart) {
      options.headers.remove(Headers.contentTypeHeader);
      options.contentType = null;
      options.extra[_retryFormDataKey] = (options.data as FormData).clone();
    } else if (_shouldSendJson(options)) {
      options.headers.putIfAbsent(
        Headers.contentTypeHeader,
        () => Headers.jsonContentType,
      );
      options.contentType ??= Headers.jsonContentType;
    }

    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = error.response?.statusCode;
    final request = error.requestOptions;

    final alreadyRetried = request.extra[_retriedKey] == true;
    final shouldTryRefresh =
        statusCode == 401 &&
        !alreadyRetried &&
        !_isAuthEndpoint(request.path) &&
        _authController.hasRefreshToken;

    if (!shouldTryRefresh) {
      handler.next(error);
      return;
    }

    final refreshed = await _authController.refreshAccessToken();
    if (!refreshed || _authController.accessToken == null) {
      await _authController.logout();
      handler.next(error);
      return;
    }

    final retriedHeaders = Map<String, dynamic>.from(request.headers);
    retriedHeaders['Authorization'] = 'Bearer ${_authController.accessToken}';
    final isMultipart = request.data is FormData;
    if (isMultipart) {
      retriedHeaders.remove(Headers.contentTypeHeader);
    }

    try {
      final response = await dio.request<dynamic>(
        request.path,
        data: _retryDataFrom(request),
        queryParameters: request.queryParameters,
        options: Options(
          method: request.method,
          headers: retriedHeaders,
          responseType: request.responseType,
          contentType: isMultipart ? null : request.contentType,
          extra: Map<String, dynamic>.from(request.extra)..[_retriedKey] = true,
          receiveDataWhenStatusError: request.receiveDataWhenStatusError,
          followRedirects: request.followRedirects,
          validateStatus: request.validateStatus,
          listFormat: request.listFormat,
        ),
        cancelToken: request.cancelToken,
        onReceiveProgress: request.onReceiveProgress,
        onSendProgress: request.onSendProgress,
      );

      handler.resolve(response);
    } on DioException catch (retriedError) {
      handler.next(retriedError);
    }
  }

  dynamic _retryDataFrom(RequestOptions request) {
    final data = request.data;
    if (data is! FormData) {
      return data;
    }

    final cloned = request.extra[_retryFormDataKey];
    if (cloned is FormData) {
      return cloned;
    }

    return data.clone();
  }

  bool _shouldSendJson(RequestOptions options) {
    if (options.contentType != null) return false;
    if (options.data == null) return false;
    final method = options.method.toUpperCase();
    return method == 'POST' || method == 'PUT' || method == 'PATCH';
  }

  bool _isAuthEndpoint(String path) {
    return path.contains('/api/usuarios/login') ||
        path.contains('/api/usuarios/refresh') ||
        path.contains('/api/usuarios/registrar') ||
        path.contains('/api/usuarios/me');
  }
}
