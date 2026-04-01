import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/network/pagination.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/jogador.dart';
import '../../../domain/models/partida.dart';
import '../../../domain/models/rodada.dart';

class RodadaCreateInput {
  const RodadaCreateInput({
    required this.dataRodada,
    required this.quantidadeTimes,
    required this.jogadoresPorTime,
  });

  final String dataRodada;
  final int quantidadeTimes;
  final int jogadoresPorTime;
}

class RodadaFullResponse {
  const RodadaFullResponse({
    required this.rodada,
    required this.partidas,
    this.rankingGols = const <Map<String, dynamic>>[],
    this.rankingAssistencias = const <Map<String, dynamic>>[],
    this.timesDisponiveis = const <Map<String, dynamic>>[],
    this.selecaoRodada = const <String, dynamic>{},
    this.estatisticas = const <String, dynamic>{},
  });

  final Rodada rodada;
  final List<Partida> partidas;
  final List<Map<String, dynamic>> rankingGols;
  final List<Map<String, dynamic>> rankingAssistencias;
  final List<Map<String, dynamic>> timesDisponiveis;
  final Map<String, dynamic> selecaoRodada;
  final Map<String, dynamic> estatisticas;
}

class RodadasRemoteDataSource {
  RodadasRemoteDataSource({required ApiClient apiClient})
    : _dio = apiClient.dio;

  final Dio _dio;

  Future<PaginatedResult<Rodada>> listRodadas({
    required int temporadaId,
    required int page,
    required int perPage,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/temporadas/$temporadaId/rodadas',
        queryParameters: <String, dynamic>{'page': page, 'per_page': perPage},
      );

      final payload = asPayload(response.data);
      final items = parseDataList(payload).map(Rodada.fromJson).toList();
      return PaginatedResult<Rodada>(
        items: items,
        meta: parsePaginationMeta(payload),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Rodada> getRodada(int rodadaId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/rodadas/$rodadaId',
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('rodada')
          ? parseMap(payload['rodada'])
          : payload;
      return Rodada.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<RodadaFullResponse> getRodadaFull(int rodadaId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/rodadas/$rodadaId/full',
      );
      final payload = asPayload(response.data);
      final rodadaMap = parseMap(payload['rodada']);
      final rodada = rodadaMap.isNotEmpty
          ? Rodada.fromJson(rodadaMap)
          : Rodada.fromJson(payload);

      final partidasRaw = payload['partidas'];
      final partidas = partidasRaw is Iterable
          ? partidasRaw
                .map(parseMap)
                .where((item) => item.isNotEmpty)
                .map(Partida.fromJson)
                .toList()
          : const <Partida>[];

      List<Map<String, dynamic>> parseMapList(dynamic raw) {
        if (raw is! Iterable) return const <Map<String, dynamic>>[];
        return raw.map(parseMap).where((item) => item.isNotEmpty).toList();
      }

      return RodadaFullResponse(
        rodada: rodada,
        partidas: partidas,
        rankingGols: parseMapList(payload['ranking_gols']),
        rankingAssistencias: parseMapList(payload['ranking_assistencias']),
        timesDisponiveis: parseMapList(payload['times_disponiveis']),
        selecaoRodada: parseMap(payload['selecao_rodada']),
        estatisticas: parseMap(payload['estatisticas']),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Rodada> createRodada({
    required int temporadaId,
    required RodadaCreateInput input,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/temporadas/$temporadaId/rodadas',
        data: <String, dynamic>{
          'data_rodada': input.dataRodada,
          'quantidade_times': input.quantidadeTimes,
          'jogadores_por_time': input.jogadoresPorTime,
        },
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('rodada')
          ? parseMap(payload['rodada'])
          : payload;
      return Rodada.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deleteRodada(int rodadaId) async {
    try {
      await _dio.delete<dynamic>('/api/peladas/rodadas/$rodadaId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<Jogador>> listJogadoresRodada(
    int rodadaId, {
    String? posicao,
    bool? apenasAtivos,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/rodadas/$rodadaId/jogadores',
        queryParameters: <String, dynamic>{
          if (posicao != null && posicao.trim().isNotEmpty) 'posicao': posicao,
          if (apenasAtivos != null) 'apenas_ativos': apenasAtivos.toString(),
        },
      );
      final payload = asPayload(response.data);
      final raw = payload['jogadores'] ?? payload['data'] ?? payload;
      if (raw is! Iterable) return const <Jogador>[];
      return raw
          .map(parseMap)
          .where((item) => item.isNotEmpty)
          .map(Jogador.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
