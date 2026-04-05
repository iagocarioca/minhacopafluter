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
    : _apiClient = apiClient,
      _dio = apiClient.dio;

  final ApiClient _apiClient;
  final Dio _dio;
  bool get _isSeguidor => _apiClient.isSeguidor;

  Future<PaginatedResult<Temporada>> listTemporadas({
    required int peladaId,
    required int page,
    required int perPage,
  }) async {
    try {
      final path = _isSeguidor
          ? '/api/seguidores/peladas/$peladaId/temporadas'
          : '/api/peladas/$peladaId/temporadas';
      final response = await _dio.get<dynamic>(
        path,
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

  Future<Temporada> getTemporada(int temporadaId, {int? peladaId}) async {
    try {
      if (_isSeguidor) {
        if (peladaId == null || peladaId <= 0) {
          throw ApiException(
            message: 'Pelada obrigatoria para buscar temporada de seguidor',
          );
        }
        final temporadas = await listTemporadas(
          peladaId: peladaId,
          page: 1,
          perPage: 200,
        );
        final temporada = temporadas.items.where(
          (item) => item.id == temporadaId,
        );
        if (temporada.isNotEmpty) {
          return temporada.first;
        }
        throw ApiException(message: 'Temporada nao encontrada para a pelada');
      }

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
