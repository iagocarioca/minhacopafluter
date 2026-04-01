import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/jogador.dart';
import '../../../domain/models/partida.dart';

class PartidaCreateInput {
  const PartidaCreateInput({
    required this.timeCasaId,
    required this.timeForaId,
  });

  final int timeCasaId;
  final int timeForaId;
}

class GolCreateInput {
  const GolCreateInput({
    required this.timeId,
    required this.jogadorId,
    this.assistenciaId,
    this.minuto,
    this.golContra = false,
  });

  final int timeId;
  final int jogadorId;
  final int? assistenciaId;
  final int? minuto;
  final bool golContra;
}

class PartidasRemoteDataSource {
  PartidasRemoteDataSource({required ApiClient apiClient})
    : _dio = apiClient.dio;

  final Dio _dio;

  Future<List<Partida>> listPartidas(int rodadaId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/rodadas/$rodadaId/partidas',
      );
      final payload = asPayload(response.data);
      final raw = payload['partidas'] ?? payload['data'] ?? payload;
      if (raw is! Iterable) return const <Partida>[];
      return raw
          .map(parseMap)
          .where((item) => item.isNotEmpty)
          .map(Partida.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Partida> getPartida(int partidaId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/partidas/$partidaId',
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('partida')
          ? parseMap(payload['partida'])
          : payload;
      return Partida.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Partida> createPartida({
    required int rodadaId,
    required PartidaCreateInput input,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/rodadas/$rodadaId/partidas',
        data: <String, dynamic>{
          'time_casa_id': input.timeCasaId,
          'time_fora_id': input.timeForaId,
        },
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('partida')
          ? parseMap(payload['partida'])
          : payload;
      return Partida.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Partida> iniciarPartida(int partidaId) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/partidas/$partidaId/iniciar',
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('partida')
          ? parseMap(payload['partida'])
          : payload;
      return Partida.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Partida> finalizarPartida(int partidaId) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/partidas/$partidaId/finalizar',
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('partida')
          ? parseMap(payload['partida'])
          : payload;
      return Partida.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Partida> registrarGol({
    required int partidaId,
    required GolCreateInput input,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/partidas/$partidaId/gols',
        data: <String, dynamic>{
          'time_id': input.timeId,
          'jogador_id': input.jogadorId,
          'assistencia_id': input.assistenciaId,
          'minuto': input.minuto,
          'gol_contra': input.golContra,
        }..removeWhere((key, value) => value == null),
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('partida')
          ? parseMap(payload['partida'])
          : payload;
      return Partida.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Partida> atualizarGol({
    required int golId,
    required GolCreateInput input,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        '/api/peladas/gols/$golId',
        data: <String, dynamic>{
          'time_id': input.timeId,
          'jogador_id': input.jogadorId,
          'assistencia_id': input.assistenciaId,
          'minuto': input.minuto,
          'gol_contra': input.golContra,
        }..removeWhere((key, value) => value == null),
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('partida')
          ? parseMap(payload['partida'])
          : payload;
      return Partida.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> removerGol(int golId) async {
    try {
      await _dio.delete<dynamic>('/api/peladas/gols/$golId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<Jogador>> getJogadoresTime({
    required int partidaId,
    required int timeId,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/partidas/$partidaId/jogadores-time/$timeId',
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

  Future<void> excluirPartida(int partidaId) async {
    try {
      await _dio.delete<dynamic>('/api/peladas/partidas/$partidaId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
