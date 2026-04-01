import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/network/pagination.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/jogador.dart';
import '../../../domain/models/transferencia.dart';

class TransferenciaCreateInput {
  const TransferenciaCreateInput({
    required this.timeOrigemId,
    required this.timeDestinoId,
    required this.jogadorOrigemId,
    required this.jogadorDestinoId,
  });

  final int timeOrigemId;
  final int timeDestinoId;
  final int jogadorOrigemId;
  final int jogadorDestinoId;
}

class TransferenciasRemoteDataSource {
  TransferenciasRemoteDataSource({required ApiClient apiClient})
    : _dio = apiClient.dio;

  final Dio _dio;

  Future<PaginatedResult<Transferencia>> listTransferencias({
    required int temporadaId,
    required int page,
    required int perPage,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/temporadas/$temporadaId/transferencias',
        queryParameters: <String, dynamic>{'page': page, 'per_page': perPage},
      );
      final payload = asPayload(response.data);
      final raw = payload['items'] ?? payload['data'] ?? payload;
      final items = raw is Iterable
          ? raw
                .map(parseMap)
                .where((item) => item.isNotEmpty)
                .map(Transferencia.fromJson)
                .toList()
          : const <Transferencia>[];
      return PaginatedResult<Transferencia>(
        items: items,
        meta: parsePaginationMeta(payload),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Transferencia> createTransferencia({
    required int temporadaId,
    required TransferenciaCreateInput input,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/api/peladas/temporadas/$temporadaId/transferencias',
        data: <String, dynamic>{
          'time_origem_id': input.timeOrigemId,
          'time_destino_id': input.timeDestinoId,
          'jogador_origem_id': input.jogadorOrigemId,
          'jogador_destino_id': input.jogadorDestinoId,
        },
      );
      final payload = asPayload(response.data);
      final data = payload.containsKey('transferencia')
          ? parseMap(payload['transferencia'])
          : payload;
      return Transferencia.fromJson(data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<Jogador>> getJogadoresTime({
    required int temporadaId,
    required int timeId,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/api/peladas/temporadas/$temporadaId/transferencias/times/$timeId/jogadores',
      );
      final payload = asPayload(response.data);
      final raw = payload['jogadores'] ?? payload['data'] ?? payload;
      if (raw is! Iterable) return const <Jogador>[];
      return raw.map(parseMap).where((item) => item.isNotEmpty).map((item) {
        final jogador = item.containsKey('jogador')
            ? parseMap(item['jogador'])
            : item;
        final merged = <String, dynamic>{...jogador};
        merged['time_id'] = parseInt(merged['time_id']) ?? timeId;
        return Jogador.fromJson(merged);
      }).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Transferencia> revertTransferencia({
    required int temporadaId,
    required Transferencia transferencia,
  }) async {
    final timeOrigemId =
        transferencia.jogadorOrigem.timeNovo?.id ??
        transferencia.jogadorDestino.timeAnterior.id;
    final timeDestinoId =
        transferencia.jogadorDestino.timeNovo?.id ??
        transferencia.jogadorOrigem.timeAnterior.id;

    return createTransferencia(
      temporadaId: temporadaId,
      input: TransferenciaCreateInput(
        timeOrigemId: timeOrigemId,
        timeDestinoId: timeDestinoId,
        jogadorOrigemId: transferencia.jogadorOrigem.id,
        jogadorDestinoId: transferencia.jogadorDestino.id,
      ),
    );
  }
}
