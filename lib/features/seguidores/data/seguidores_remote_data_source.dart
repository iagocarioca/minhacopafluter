import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/network/pagination.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/pelada.dart';
import '../../../domain/models/seguidor_feed.dart';

class SeguidorPeladaStatus {
  const SeguidorPeladaStatus({
    required this.peladaId,
    required this.segue,
    this.seguimento,
  });

  final int peladaId;
  final bool segue;
  final Map<String, dynamic>? seguimento;
}

class SeguidoresRemoteDataSource {
  SeguidoresRemoteDataSource({required ApiClient apiClient})
    : _dio = apiClient.dio;

  final Dio _dio;

  Future<SeguidorPeladaStatus> seguirPelada(int peladaId) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/seguidores/peladas/$peladaId/seguir',
      );
      final payload = asPayload(response.data);
      final seguimento = parseMap(payload['seguimento']);
      return SeguidorPeladaStatus(
        peladaId: parseInt(seguimento['pelada_id']) ?? peladaId,
        segue: true,
        seguimento: seguimento.isEmpty ? null : seguimento,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deixarDeSeguirPelada(int peladaId) async {
    try {
      await _dio.delete<dynamic>('/api/seguidores/peladas/$peladaId/seguir');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SeguidorPeladaStatus> getStatusPelada(int peladaId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/seguidores/peladas/$peladaId/status',
      );
      final payload = asPayload(response.data);
      final seguimento = parseMap(payload['seguimento']);
      return SeguidorPeladaStatus(
        peladaId: parseInt(payload['pelada_id']) ?? peladaId,
        segue: parseBool(payload['segue']),
        seguimento: seguimento.isEmpty ? null : seguimento,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PaginatedResult<Pelada>> listPeladasSeguidas({
    required int page,
    required int perPage,
    bool? ativa,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/seguidores/peladas',
        queryParameters: <String, dynamic>{
          'page': page,
          'per_page': perPage,
          ...?ativa == null ? null : <String, dynamic>{'ativa': ativa},
        },
      );
      final payload = asPayload(response.data);
      final items = parseDataList(payload)
          .map(
            (item) =>
                item.containsKey('pelada') ? parseMap(item['pelada']) : item,
          )
          .where((item) => item.isNotEmpty)
          .map(Pelada.fromJson)
          .toList();
      return PaginatedResult<Pelada>(
        items: items,
        meta: parsePaginationMeta(payload),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<SeguidorPeladaFeed> getPeladaFeed({
    required int peladaId,
    int limitPartidas = 10,
    int limitVotacoes = 5,
    String? tipoVotacao,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/seguidores/peladas/$peladaId/feed',
        queryParameters: <String, dynamic>{
          'limit_partidas': limitPartidas.clamp(1, 50),
          'limit_votacoes': limitVotacoes.clamp(1, 30),
          if (tipoVotacao != null && tipoVotacao.trim().isNotEmpty)
            'tipo_votacao': tipoVotacao.trim(),
        },
      );
      final payload = asPayload(response.data);
      return SeguidorPeladaFeed.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
