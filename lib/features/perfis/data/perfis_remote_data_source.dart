import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/perfil_publico.dart';

class PerfisRemoteDataSource {
  PerfisRemoteDataSource({required ApiClient apiClient}) : _dio = apiClient.dio;

  final Dio _dio;

  Future<JogadorPerfilPublico> getPerfilPublico(int jogadorId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/publico/jogadores/$jogadorId/perfil',
      );
      final payload = asPayload(response.data);
      final data = parseMap(payload['jogador']).isNotEmpty
          ? parseMap(payload['jogador'])
          : parseMap(payload['perfil']).isNotEmpty
          ? parseMap(payload['perfil'])
          : payload;
      return JogadorPerfilPublico.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<JogadorEstatisticasPublicas> getEstatisticas(int jogadorId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/publico/jogadores/$jogadorId/estatisticas',
      );
      final payload = asPayload(response.data);
      return JogadorEstatisticasPublicas.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<HistoricoPartidaPublica>> getHistorico(int jogadorId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/publico/jogadores/$jogadorId/historico',
      );
      final payload = asPayload(response.data);
      final raw =
          payload['historico'] ??
          payload['partidas'] ??
          payload['data'] ??
          response.data;
      if (raw is! Iterable) {
        return const <HistoricoPartidaPublica>[];
      }
      return raw
          .map(parseMap)
          .where((item) => item.isNotEmpty)
          .map(HistoricoPartidaPublica.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
