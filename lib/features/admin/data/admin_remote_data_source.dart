import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/network/pagination.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/admin.dart';
import '../../../domain/models/user.dart';

class AdminRemoteDataSource {
  AdminRemoteDataSource({required ApiClient apiClient}) : _dio = apiClient.dio;

  final Dio _dio;

  Future<AdminDashboardData> getDashboard() async {
    try {
      final response = await _dio.get<dynamic>('/api/usuarios/admin/dashboard');
      final payload = asPayload(response.data);
      return AdminDashboardData.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PaginatedResult<User>> listUsuarios({
    required int page,
    required int perPage,
    String? busca,
    String? tipoUsuario,
    String? status,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/usuarios/admin/usuarios',
        queryParameters: <String, dynamic>{
          'page': page,
          'per_page': perPage,
          if (busca != null && busca.trim().isNotEmpty) 'busca': busca,
          if (tipoUsuario != null && tipoUsuario.trim().isNotEmpty)
            'tipo_usuario': tipoUsuario,
          if (status != null && status.trim().isNotEmpty) 'status': status,
        },
      );
      final payload = asPayload(response.data);
      final raw = payload['data'] ?? payload['usuarios'] ?? payload;
      final items = raw is Iterable
          ? raw
                .map(parseMap)
                .where((item) => item.isNotEmpty)
                .map(User.fromJson)
                .toList()
          : const <User>[];
      return PaginatedResult<User>(
        items: items,
        meta: parsePaginationMeta(payload),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PaginatedResult<AdminPelada>> listPeladas({
    required int page,
    required int perPage,
    String? busca,
    String? ativa,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/usuarios/admin/peladas',
        queryParameters: <String, dynamic>{
          'page': page,
          'per_page': perPage,
          if (busca != null && busca.trim().isNotEmpty) 'busca': busca,
          if (ativa != null && ativa.trim().isNotEmpty) 'ativa': ativa,
        },
      );
      final payload = asPayload(response.data);
      final raw = payload['data'] ?? payload['peladas'] ?? payload;
      final items = raw is Iterable
          ? raw
                .map(parseMap)
                .where((item) => item.isNotEmpty)
                .map(AdminPelada.fromJson)
                .toList()
          : const <AdminPelada>[];
      return PaginatedResult<AdminPelada>(
        items: items,
        meta: parsePaginationMeta(payload),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
