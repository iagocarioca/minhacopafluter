import '../../core/utils/json_parsing.dart';

class Rodada {
  const Rodada({
    required this.id,
    required this.temporadaId,
    required this.dataRodada,
    required this.quantidadeTimes,
    required this.jogadoresPorTime,
    this.numero,
    this.data,
    this.status,
    this.criadoEm,
  });

  final int id;
  final int temporadaId;
  final String dataRodada;
  final int quantidadeTimes;
  final int jogadoresPorTime;
  final int? numero;
  final String? data;
  final String? status;
  final String? criadoEm;

  factory Rodada.fromJson(Map<String, dynamic> json) {
    return Rodada(
      id: parseInt(json['id']) ?? 0,
      temporadaId: parseInt(json['temporada_id']) ?? 0,
      dataRodada: parseString(json['data_rodada']) ?? '',
      quantidadeTimes: parseInt(json['quantidade_times']) ?? 0,
      jogadoresPorTime: parseInt(json['jogadores_por_time']) ?? 0,
      numero: parseInt(json['numero']),
      data: parseString(json['data']),
      status: parseString(json['status']),
      criadoEm: parseString(json['criado_em']),
    );
  }
}
