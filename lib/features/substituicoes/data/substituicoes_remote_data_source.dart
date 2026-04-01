import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/substituicao.dart';

class SubstituicaoCreateInput {
  const SubstituicaoCreateInput({
    required this.timeId,
    required this.jogadorAusenteId,
    required this.jogadorSubstitutoId,
  });

  final int timeId;
  final int jogadorAusenteId;
  final int jogadorSubstitutoId;
}

class SubstituicoesRemoteDataSource {
  SubstituicoesRemoteDataSource({required ApiClient apiClient})
    : _dio = apiClient.dio;

  final Dio _dio;

  Future<List<Substituicao>> listSubstituicoes(int rodadaId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/rodadas/$rodadaId/substituicoes',
      );

      final payload = asPayload(response.data);
      final dataPayload = parseMap(payload['data']);
      final raw =
          payload['substituicoes'] ??
          dataPayload['substituicoes'] ??
          payload['data'] ??
          payload;

      if (raw is! Iterable) return const <Substituicao>[];
      return raw
          .map(parseMap)
          .where((item) => item.isNotEmpty)
          .map(Substituicao.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Substituicao> createSubstituicao({
    required int rodadaId,
    required SubstituicaoCreateInput input,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/rodadas/$rodadaId/substituicoes',
        data: <String, dynamic>{
          'time_id': input.timeId,
          'jogador_ausente_id': input.jogadorAusenteId,
          'jogador_substituto_id': input.jogadorSubstitutoId,
        },
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('substituicao')
          ? parseMap(payload['substituicao'])
          : payload;
      return Substituicao.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deleteSubstituicao(int substituicaoId) async {
    try {
      await _dio.delete<dynamic>('/api/peladas/substituicoes/$substituicaoId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
