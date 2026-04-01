import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/network/multipart_file_factory.dart';
import '../../../core/network/pagination.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/jogador.dart';

class JogadorUpsertInput {
  const JogadorUpsertInput({
    required this.nomeCompleto,
    required this.apelido,
    required this.ativo,
    this.telefone,
    this.posicao,
    this.fotoFile,
  });

  final String nomeCompleto;
  final String apelido;
  final bool ativo;
  final String? telefone;
  final String? posicao;
  final XFile? fotoFile;
}

class JogadoresRemoteDataSource {
  JogadoresRemoteDataSource({required ApiClient apiClient})
    : _dio = apiClient.dio;

  final Dio _dio;

  Future<PaginatedResult<Jogador>> listJogadores({
    required int peladaId,
    required int page,
    required int perPage,
    bool? ativo,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/$peladaId/jogadores',
        queryParameters: <String, dynamic>{
          'page': page,
          'per_page': perPage,
          ...?ativo == null ? null : <String, dynamic>{'ativo': ativo},
        },
      );

      final payload = asPayload(response.data);
      final items = parseDataList(payload).map(Jogador.fromJson).toList();
      return PaginatedResult<Jogador>(
        items: items,
        meta: parsePaginationMeta(payload),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Jogador> getJogador(int jogadorId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/jogadores/$jogadorId',
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('jogador')
          ? parseMap(payload['jogador'])
          : payload;
      return Jogador.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Jogador> createJogador({
    required int peladaId,
    required JogadorUpsertInput input,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/$peladaId/jogadores',
        data: input.fotoFile != null
            ? await _toFormData(input)
            : _toJsonBody(input),
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('jogador')
          ? parseMap(payload['jogador'])
          : payload;
      return Jogador.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Jogador> updateJogador({
    required int jogadorId,
    required JogadorUpsertInput input,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        '/api/peladas/jogadores/$jogadorId',
        data: input.fotoFile != null
            ? await _toFormData(input)
            : _toJsonBody(input),
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('jogador')
          ? parseMap(payload['jogador'])
          : payload;
      return Jogador.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Map<String, dynamic> _toJsonBody(JogadorUpsertInput input) {
    return <String, dynamic>{
      'nome_completo': input.nomeCompleto,
      'apelido': input.apelido,
      'telefone': parseString(input.telefone),
      'posicao': parseString(input.posicao),
      'ativo': input.ativo,
    }..removeWhere((key, value) => value == null);
  }

  Future<FormData> _toFormData(JogadorUpsertInput input) async {
    final telefone = parseString(input.telefone);
    final posicao = parseString(input.posicao);

    final map = <String, dynamic>{
      'nome_completo': input.nomeCompleto,
      'apelido': input.apelido,
      ...?telefone == null ? null : <String, dynamic>{'telefone': telefone},
      ...?posicao == null ? null : <String, dynamic>{'posicao': posicao},
      'ativo': input.ativo.toString(),
    };

    if (input.fotoFile != null) {
      map['foto'] = await MultipartFileFactory.fromXFile(input.fotoFile!);
    }

    return FormData.fromMap(map);
  }
}
