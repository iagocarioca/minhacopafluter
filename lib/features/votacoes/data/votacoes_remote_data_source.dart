import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/votacao.dart';

class VotacaoCreateInput {
  const VotacaoCreateInput({
    required this.tipo,
    this.abreEm,
    this.fechaEm,
    this.titulo,
  });

  final String tipo;
  final String? abreEm;
  final String? fechaEm;
  final String? titulo;
}

class VotoInput {
  const VotoInput({
    required this.jogadorVotanteId,
    required this.jogadorVotadoId,
    required this.pontos,
  });

  final int jogadorVotanteId;
  final int jogadorVotadoId;
  final int pontos;
}

class VotacoesRemoteDataSource {
  VotacoesRemoteDataSource({required ApiClient apiClient})
    : _dio = apiClient.dio;

  final Dio _dio;

  Future<List<Votacao>> listVotacoes({
    required int rodadaId,
    String? tipo,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/rodadas/$rodadaId/votacoes',
        queryParameters: <String, dynamic>{
          if (tipo != null && tipo.trim().isNotEmpty) 'tipo': tipo,
        },
      );

      final payload = asPayload(response.data);
      final raw = payload['votacoes'] ?? payload['data'] ?? payload;
      if (raw is! Iterable) return const <Votacao>[];
      return raw
          .map(parseMap)
          .where((item) => item.isNotEmpty)
          .map(Votacao.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Votacao> getVotacao(int votacaoId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/votacoes/$votacaoId',
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('votacao')
          ? parseMap(payload['votacao'])
          : payload;
      return Votacao.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Votacao> createVotacao({
    required int rodadaId,
    required VotacaoCreateInput input,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/rodadas/$rodadaId/votacoes',
        data: <String, dynamic>{
          'tipo': input.tipo,
          'abre_em': input.abreEm,
          'fecha_em': input.fechaEm,
          'titulo': input.titulo,
        }..removeWhere((key, value) => value == null),
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('votacao')
          ? parseMap(payload['votacao'])
          : payload;
      return Votacao.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> votar({
    required int votacaoId,
    required VotoInput input,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/votacoes/$votacaoId/votar',
        data: <String, dynamic>{
          'jogador_votante_id': input.jogadorVotanteId,
          'jogador_votado_id': input.jogadorVotadoId,
          'pontos': input.pontos,
        },
      );
      return asPayload(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> getResultado(int votacaoId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/votacoes/$votacaoId/resultado',
      );
      return asPayload(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<Map<String, dynamic>>> listVotantes(int votacaoId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/votacoes/$votacaoId/votantes',
      );
      final payload = asPayload(response.data);
      final raw = payload['votantes'] ?? payload['data'] ?? payload;
      if (raw is! Iterable) return const <Map<String, dynamic>>[];
      return raw.map(parseMap).where((item) => item.isNotEmpty).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> getResultadosRodada({
    required int rodadaId,
    String? tipo,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/rodadas/$rodadaId/votacoes/resultados',
        queryParameters: <String, dynamic>{
          if (tipo != null && tipo.trim().isNotEmpty) 'tipo': tipo,
        },
      );
      return asPayload(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Votacao> encerrarVotacao(int votacaoId) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/votacoes/$votacaoId/encerrar',
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('votacao')
          ? parseMap(payload['votacao'])
          : payload;
      return Votacao.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
