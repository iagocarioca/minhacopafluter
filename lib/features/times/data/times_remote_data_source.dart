import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/network/multipart_file_factory.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/jogador.dart';
import '../../../domain/models/time_model.dart';

class TimeDetail {
  const TimeDetail({required this.time, required this.jogadores});

  final TimeModel time;
  final List<Jogador> jogadores;
}

class TimeCreateInput {
  const TimeCreateInput({
    required this.nome,
    required this.cor,
    this.escudoFile,
  });

  final String nome;
  final String cor;
  final XFile? escudoFile;
}

class TimeUpdateInput {
  const TimeUpdateInput({this.nome, this.cor, this.escudoFile});

  final String? nome;
  final String? cor;
  final XFile? escudoFile;
}

class TimesRemoteDataSource {
  TimesRemoteDataSource({required ApiClient apiClient}) : _dio = apiClient.dio;

  final Dio _dio;

  Future<List<TimeModel>> listTimes({
    required int temporadaId,
    required int page,
    required int perPage,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/temporadas/$temporadaId/times',
        queryParameters: <String, dynamic>{'page': page, 'per_page': perPage},
      );
      final payload = asPayload(response.data);
      final raw = payload['data'] ?? payload['items'] ?? payload;
      if (raw is! Iterable) return const <TimeModel>[];
      return raw
          .map(parseMap)
          .where((item) => item.isNotEmpty)
          .map(
            (item) => item.containsKey('time') ? parseMap(item['time']) : item,
          )
          .where((item) => item.isNotEmpty)
          .map(TimeModel.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeDetail> getTime(int timeId) async {
    try {
      final response = await _dio.get<dynamic>('/api/peladas/times/$timeId');
      final payload = asPayload(response.data);
      final data = payload.containsKey('time')
          ? parseMap(payload['time'])
          : payload;
      final jogadoresRaw = data['jogadores'] ?? payload['jogadores'];

      final jogadores = jogadoresRaw is Iterable
          ? jogadoresRaw
                .map(parseMap)
                .where((item) => item.isNotEmpty)
                .map(
                  (item) => item.containsKey('jogador')
                      ? parseMap(item['jogador'])
                      : item,
                )
                .where((item) => item.isNotEmpty)
                .map((item) {
                  final enriched = <String, dynamic>{
                    ...item,
                    if (!item.containsKey('time_id')) 'time_id': timeId,
                    if (!item.containsKey('time_nome'))
                      'time_nome': parseString(data['nome']),
                  };
                  return Jogador.fromJson(enriched);
                })
                .toList()
          : const <Jogador>[];

      return TimeDetail(time: TimeModel.fromJson(data), jogadores: jogadores);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeModel> createTime({
    required int temporadaId,
    required TimeCreateInput input,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/temporadas/$temporadaId/times',
        data: input.escudoFile == null
            ? <String, dynamic>{'nome': input.nome, 'cor': input.cor}
            : await _toFormData(input.nome, input.cor, input.escudoFile),
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('time')
          ? parseMap(payload['time'])
          : payload;
      return TimeModel.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<TimeModel> updateTime({
    required int timeId,
    required TimeUpdateInput input,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        '/api/peladas/times/$timeId',
        data: input.escudoFile == null
            ? <String, dynamic>{
                if (input.nome != null) 'nome': input.nome,
                if (input.cor != null) 'cor': input.cor,
              }
            : await _toFormData(
                input.nome ?? '',
                input.cor ?? '',
                input.escudoFile,
              ),
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('time')
          ? parseMap(payload['time'])
          : payload;
      return TimeModel.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> updateEscudo({
    required int timeId,
    required XFile escudoFile,
  }) async {
    try {
      final formData = FormData.fromMap(<String, dynamic>{
        'escudo': await MultipartFileFactory.fromXFile(escudoFile),
      });
      final response = await _dio.post<dynamic>(
        '/api/peladas/times/$timeId/escudo',
        data: formData,
      );
      return asPayload(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> addJogador({
    required int timeId,
    required int jogadorId,
    String? posicao,
    bool capitao = false,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/times/$timeId/jogadores',
        data: <String, dynamic>{
          'jogador_id': jogadorId,
          if (posicao != null && posicao.trim().isNotEmpty) 'posicao': posicao,
          'capitao': capitao,
        },
      );
      return asPayload(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> removeJogador({
    required int timeId,
    required int jogadorId,
  }) async {
    try {
      await _dio.delete<dynamic>(
        '/api/peladas/times/$timeId/jogadores/$jogadorId',
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> updateJogador({
    required int timeId,
    required int jogadorId,
    bool? capitao,
    String? posicao,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        '/api/peladas/times/$timeId/jogadores/$jogadorId',
        data: <String, dynamic>{
          if (capitao != null) 'capitao': capitao,
          if (posicao != null && posicao.trim().isNotEmpty) 'posicao': posicao,
        },
      );
      return asPayload(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<FormData> _toFormData(
    String nome,
    String cor,
    XFile? escudoFile,
  ) async {
    final map = <String, dynamic>{
      if (nome.trim().isNotEmpty) 'nome': nome,
      if (cor.trim().isNotEmpty) 'cor': cor,
    };
    if (escudoFile != null) {
      map['escudo'] = await MultipartFileFactory.fromXFile(escudoFile);
    }
    return FormData.fromMap(map);
  }
}
