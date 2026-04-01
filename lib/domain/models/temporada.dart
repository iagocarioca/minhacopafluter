import '../../core/utils/json_parsing.dart';

class Temporada {
  const Temporada({
    required this.id,
    required this.peladaId,
    required this.status,
    this.inicio,
    this.fim,
    this.inicioMes,
    this.fimMes,
    this.criadoEm,
  });

  final int id;
  final int peladaId;
  final String status;
  final String? inicio;
  final String? fim;
  final String? inicioMes;
  final String? fimMes;
  final String? criadoEm;

  factory Temporada.fromJson(Map<String, dynamic> json) {
    return Temporada(
      id: parseInt(json['id']) ?? 0,
      peladaId: parseInt(json['pelada_id']) ?? 0,
      status: parseString(json['status']) ?? '',
      inicio: parseString(json['inicio']),
      fim: parseString(json['fim']),
      inicioMes: parseString(json['inicio_mes']),
      fimMes: parseString(json['fim_mes']),
      criadoEm: parseString(json['criado_em']),
    );
  }
}
