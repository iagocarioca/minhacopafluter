import 'package:dio/dio.dart';

import '../utils/json_parsing.dart';

class ApiException implements Exception {
  ApiException({required this.message, this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final dynamic data;

  factory ApiException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final payload = parseMap(data);

    final message =
        parseString(payload['erro']) ??
        parseString(payload['message']) ??
        parseString(payload['detail']) ??
        error.message ??
        'Erro na requisicao';

    return ApiException(message: message, statusCode: statusCode, data: data);
  }

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message)';
  }
}
