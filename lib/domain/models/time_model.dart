import '../../core/utils/json_parsing.dart';

class TimeModel {
  const TimeModel({
    required this.id,
    required this.nome,
    required this.cor,
    required this.temporadaId,
    this.escudoUrl,
    this.jogadoresTotal,
    this.pontos,
    this.vitorias,
    this.empates,
    this.derrotas,
    this.golsMarcados,
    this.golsSofridos,
    this.saldoGols,
    this.criadoEm,
  });

  final int id;
  final String nome;
  final String cor;
  final int temporadaId;
  final String? escudoUrl;
  final int? jogadoresTotal;
  final int? pontos;
  final int? vitorias;
  final int? empates;
  final int? derrotas;
  final int? golsMarcados;
  final int? golsSofridos;
  final int? saldoGols;
  final String? criadoEm;

  factory TimeModel.fromJson(Map<String, dynamic> json) {
    final jogadoresRaw = json['jogadores'];
    final jogadoresTotal =
        parseInt(json['jogadores_total']) ??
        parseInt(json['jogadores_count']) ??
        parseInt(json['total_jogadores']) ??
        (jogadoresRaw is Iterable ? jogadoresRaw.length : null);

    return TimeModel(
      id: parseInt(json['id']) ?? 0,
      nome: parseString(json['nome']) ?? '',
      cor: parseString(json['cor']) ?? '',
      temporadaId: parseInt(json['temporada_id']) ?? 0,
      escudoUrl: parseString(json['escudo_url']),
      jogadoresTotal: jogadoresTotal,
      pontos: parseInt(json['pontos']),
      vitorias: parseInt(json['vitorias']),
      empates: parseInt(json['empates']),
      derrotas: parseInt(json['derrotas']),
      golsMarcados: parseInt(json['gols_marcados']),
      golsSofridos: parseInt(json['gols_sofridos']),
      saldoGols: parseInt(json['saldo_gols']),
      criadoEm: parseString(json['criado_em']),
    );
  }
}
