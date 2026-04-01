import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/ranking.dart';

class RankingsRemoteDataSource {
  RankingsRemoteDataSource({required ApiClient apiClient})
    : _dio = apiClient.dio;

  final Dio _dio;

  Future<List<RankingTimeEntry>> getRankingTimes(int temporadaId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/temporadas/$temporadaId/ranking/times',
      );
      final payload = asPayload(response.data);
      final raw = payload['ranking'] ?? payload['data'] ?? payload;
      if (raw is! Iterable) return const <RankingTimeEntry>[];

      return raw
          .map(parseMap)
          .where((item) => item.isNotEmpty)
          .map(
            (item) => item.containsKey('time') ? parseMap(item['time']) : item,
          )
          .where((item) => item.isNotEmpty)
          .map((time) {
            final golsFeitos =
                parseInt(time['gols_marcados']) ??
                parseInt(time['gols_feitos']) ??
                0;
            final golsSofridos = parseInt(time['gols_sofridos']) ?? 0;
            return RankingTimeEntry(
              timeId: parseInt(time['id']) ?? parseInt(time['time_id']) ?? 0,
              timeNome:
                  parseString(time['nome']) ??
                  parseString(time['time_nome']) ??
                  'Sem nome',
              timeEscudoUrl:
                  parseString(time['escudo_url']) ??
                  parseString(time['time_escudo_url']),
              timeCor:
                  parseString(time['cor']) ?? parseString(time['time_cor']),
              pontos: parseInt(time['pontos']) ?? 0,
              jogos: parseInt(time['jogos']) ?? 0,
              vitorias: parseInt(time['vitorias']) ?? 0,
              empates: parseInt(time['empates']) ?? 0,
              derrotas: parseInt(time['derrotas']) ?? 0,
              golsFeitos: golsFeitos,
              golsSofridos: golsSofridos,
              saldoGols:
                  parseInt(time['saldo_gols']) ?? (golsFeitos - golsSofridos),
            );
          })
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<RankingJogadorEntry>> getRankingArtilheiros(
    int temporadaId,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/temporadas/$temporadaId/ranking/artilheiros',
      );
      final payload = asPayload(response.data);
      final raw = payload['ranking'] ?? payload['data'] ?? payload;
      if (raw is! Iterable) return const <RankingJogadorEntry>[];

      return raw.map((item) => RankingJogadorEntry.fromApi(item)).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<RankingJogadorEntry>> getRankingAssistencias(
    int temporadaId,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/temporadas/$temporadaId/ranking/assistencias',
      );
      final payload = asPayload(response.data);
      final raw = payload['ranking'] ?? payload['data'] ?? payload;
      if (raw is! Iterable) return const <RankingJogadorEntry>[];

      return raw.map((item) => RankingJogadorEntry.fromApi(item)).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> getScout(int temporadaId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/temporadas/$temporadaId/scout',
      );
      return asPayload(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
