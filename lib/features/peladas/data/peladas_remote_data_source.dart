import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/network/multipart_file_factory.dart';
import '../../../core/network/pagination.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/pelada.dart';
import '../../../domain/models/pelada_feed.dart';
import '../../../domain/models/pelada_publica.dart';
import '../../../core/network/api_client.dart';

class PeladaUpsertInput {
  const PeladaUpsertInput({
    required this.nome,
    required this.cidade,
    required this.fusoHorario,
    required this.corPrimaria,
    this.corSecundaria,
    this.instagramUrl,
    this.ativa,
    this.logoFile,
    this.logoVetorFile,
    this.perfilFile,
  });

  final String nome;
  final String cidade;
  final String fusoHorario;
  final String corPrimaria;
  final String? corSecundaria;
  final String? instagramUrl;
  final bool? ativa;
  final XFile? logoFile;
  final XFile? logoVetorFile;
  final XFile? perfilFile;
}

class PeladasRemoteDataSource {
  PeladasRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient,
      _dio = apiClient.dio;

  final ApiClient _apiClient;
  final Dio _dio;
  bool get _isSeguidor => _apiClient.isSeguidor;

  Future<PaginatedResult<Pelada>> listPeladas({
    required int page,
    required int perPage,
    int? usuarioId,
  }) async {
    try {
      final path = _isSeguidor ? '/api/seguidores/peladas' : '/api/peladas/';
      final query = <String, dynamic>{'page': page, 'per_page': perPage};
      if (!_isSeguidor && usuarioId != null) {
        query['usuario_id'] = usuarioId;
      }
      final response = await _dio.get<dynamic>(path, queryParameters: query);

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

  Future<Pelada> getPelada(int id) async {
    try {
      final path = _isSeguidor
          ? '/api/seguidores/peladas/$id/perfil'
          : '/api/peladas/$id';
      final response = await _dio.get<dynamic>(path);
      final payload = asPayload(response.data);
      final data = payload.containsKey('pelada')
          ? parseMap(payload['pelada'])
          : payload;
      return Pelada.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PeladaPublicProfile> getPeladaProfile(int id) async {
    try {
      final response = await _dio.get<dynamic>('/api/peladas/$id/perfil');
      final payload = asPayload(response.data);
      return PeladaPublicProfile.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PeladasFeedResponse> getPublicPeladasFeed({
    int semanas = 4,
    int limit = 20,
    bool somenteComInstagram = true,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/publico/peladas/feed',
        queryParameters: <String, dynamic>{
          'semanas': semanas,
          'limit': limit.clamp(1, 100),
          'somente_com_instagram': somenteComInstagram,
        },
      );
      final payload = asPayload(response.data);
      final nestedData = parseMap(payload['data']);
      final source = nestedData.isNotEmpty ? nestedData : payload;
      var parsed = PeladasFeedResponse.fromJson(source);

      if (parsed.feed.isNotEmpty || !somenteComInstagram) {
        return parsed;
      }

      final fallbackResponse = await _dio.get<dynamic>(
        '/api/publico/peladas/feed',
        queryParameters: <String, dynamic>{
          'semanas': semanas,
          'limit': limit.clamp(1, 100),
          'somente_com_instagram': false,
        },
      );
      final fallbackPayload = asPayload(fallbackResponse.data);
      final fallbackNested = parseMap(fallbackPayload['data']);
      final fallbackSource = fallbackNested.isNotEmpty
          ? fallbackNested
          : fallbackPayload;
      parsed = PeladasFeedResponse.fromJson(fallbackSource);
      return parsed;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Pelada> createPelada(PeladaUpsertInput input) async {
    try {
      final useMultipart = _hasAnyFile(input);
      final response = await _dio.post<dynamic>(
        '/api/peladas/',
        data: useMultipart ? await _toFormData(input) : _toJsonBody(input),
      );

      final payload = asPayload(response.data);
      final data = payload.containsKey('pelada')
          ? parseMap(payload['pelada'])
          : payload;
      return Pelada.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Pelada> updatePelada({
    required int id,
    required PeladaUpsertInput input,
  }) async {
    try {
      final useMultipart = _hasAnyFile(input);
      final response = await _dio.put<dynamic>(
        '/api/peladas/$id',
        data: useMultipart ? await _toFormData(input) : _toJsonBody(input),
      );

      final payload = asPayload(response.data);
      final data = payload.containsKey('pelada')
          ? parseMap(payload['pelada'])
          : payload;
      return Pelada.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  bool _hasAnyFile(PeladaUpsertInput input) {
    return input.logoFile != null ||
        input.logoVetorFile != null ||
        input.perfilFile != null;
  }

  Map<String, dynamic> _toJsonBody(PeladaUpsertInput input) {
    final colors = _normalizeColors(input.corPrimaria, input.corSecundaria);
    return <String, dynamic>{
      'nome': input.nome,
      'cidade': input.cidade,
      'fuso_horario': input.fusoHorario,
      if (input.instagramUrl != null) 'instagram_url': input.instagramUrl,
      'cores': colors,
      if (input.ativa != null) 'ativa': input.ativa,
    };
  }

  Future<FormData> _toFormData(PeladaUpsertInput input) async {
    final colors = _normalizeColors(input.corPrimaria, input.corSecundaria);
    final map = <String, dynamic>{
      'nome': input.nome,
      'cidade': input.cidade,
      'fuso_horario': input.fusoHorario,
      if (input.instagramUrl != null) 'instagram_url': input.instagramUrl,
      'cores': colors.isNotEmpty
          ? '[${colors.map((c) => '"$c"').join(',')}]'
          : null,
      if (input.ativa != null) 'ativa': input.ativa.toString(),
    };

    if (input.logoFile != null) {
      map['logo'] = await MultipartFileFactory.fromXFile(input.logoFile!);
    }
    if (input.logoVetorFile != null) {
      map['logo_vetor'] = await MultipartFileFactory.fromXFile(
        input.logoVetorFile!,
      );
    }
    if (input.perfilFile != null) {
      map['perfil'] = await MultipartFileFactory.fromXFile(input.perfilFile!);
    }

    map.removeWhere((key, value) => value == null);
    return FormData.fromMap(map);
  }

  List<String> _normalizeColors(String primary, String? secondary) {
    final values = <String>[
      primary,
      ...?secondary == null ? null : <String>[secondary],
    ];
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map((value) => value.startsWith('#') ? value : '#$value')
        .where((value) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value))
        .toList();
  }
}
