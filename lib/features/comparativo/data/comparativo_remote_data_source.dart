import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../domain/models/comparativo.dart';

class ComparativoRemoteDataSource {
  ComparativoRemoteDataSource({required ApiClient apiClient})
    : _dio = apiClient.dio;

  final Dio _dio;

  Future<ComparativoJogadoresData> compararJogadores({
    required int peladaId,
    required List<int> jogadorIds,
    String escopo = 'atual',
    int? temporadaId,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/$peladaId/comparativo/jogadores',
        queryParameters: <String, dynamic>{
          'escopo': escopo,
          'jogador_ids': jogadorIds,
          ...?temporadaId == null
              ? null
              : <String, dynamic>{'temporada_id': temporadaId},
        },
      );
      final payload = asPayload(response.data);
      return ComparativoJogadoresData.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
