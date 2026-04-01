import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/network/pagination.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/temporada.dart';

class TemporadaCreateInput {
  const TemporadaCreateInput({required this.inicio, required this.fim});

  final String inicio;
  final String fim;
}

class TemporadasRemoteDataSource {
  TemporadasRemoteDataSource({required ApiClient apiClient})
    : _dio = apiClient.dio;

  final Dio _dio;

  Future<PaginatedResult<Temporada>> listTemporadas({
    required int peladaId,
    required int page,
    required int perPage,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/$peladaId/temporadas',
        queryParameters: <String, dynamic>{'page': page, 'per_page': perPage},
      );

      final payload = asPayload(response.data);
      final items = parseDataList(payload).map(Temporada.fromJson).toList();
      return PaginatedResult<Temporada>(
        items: items,
        meta: parsePaginationMeta(payload),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Temporada> getTemporada(int temporadaId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/temporadas/$temporadaId',
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('temporada')
          ? parseMap(payload['temporada'])
          : payload;
      return Temporada.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Temporada> createTemporada({
    required int peladaId,
    required TemporadaCreateInput input,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/$peladaId/temporadas',
        data: <String, dynamic>{
          'inicio_mes': input.inicio,
          'fim_mes': input.fim,
          'inicio': input.inicio,
          'fim': input.fim,
        },
      );

      final payload = asPayload(response.data);
      final data = payload.containsKey('temporada')
          ? parseMap(payload['temporada'])
          : payload;
      return Temporada.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Temporada> encerrarTemporada(int temporadaId) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/temporadas/$temporadaId/encerrar',
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('temporada')
          ? parseMap(payload['temporada'])
          : payload;
      return Temporada.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> excluirTemporada(int temporadaId) async {
    try {
      await _dio.delete<dynamic>('/api/peladas/temporadas/$temporadaId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
