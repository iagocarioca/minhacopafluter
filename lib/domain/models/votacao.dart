import '../../core/utils/json_parsing.dart';

class Votacao {
  const Votacao({
    required this.id,
    required this.rodadaId,
    required this.tipo,
    required this.status,
    this.titulo,
    this.abreEm,
    this.fechaEm,
  });

  final int id;
  final int rodadaId;
  final String tipo;
  final String status;
  final String? titulo;
  final String? abreEm;
  final String? fechaEm;

  factory Votacao.fromJson(Map<String, dynamic> json) {
    return Votacao(
      id: parseInt(json['id']) ?? 0,
      rodadaId: parseInt(json['rodada_id']) ?? 0,
      tipo: parseString(json['tipo']) ?? '',
      status: parseString(json['status']) ?? '',
      titulo: parseString(json['titulo']),
      abreEm: parseString(json['abre_em']),
      fechaEm: parseString(json['fecha_em']),
    );
  }
}
