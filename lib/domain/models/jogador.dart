import '../../core/utils/json_parsing.dart';

class Jogador {
  const Jogador({
    required this.id,
    required this.apelido,
    required this.nomeCompleto,
    this.peladaId,
    this.telefone,
    this.fotoUrl,
    this.posicao,
    this.capitao,
    this.timeId,
    this.timeNome,
    this.timeEscudoUrl,
    this.ativo,
    this.criadoEm,
  });

  final int id;
  final int? peladaId;
  final String apelido;
  final String nomeCompleto;
  final String? telefone;
  final String? fotoUrl;
  final String? posicao;
  final bool? capitao;
  final int? timeId;
  final String? timeNome;
  final String? timeEscudoUrl;
  final bool? ativo;
  final String? criadoEm;

  factory Jogador.fromJson(Map<String, dynamic> json) {
    return Jogador(
      id: parseInt(json['id']) ?? 0,
      peladaId: parseInt(json['pelada_id']),
      apelido: parseString(json['apelido']) ?? '',
      nomeCompleto: parseString(json['nome_completo']) ?? '',
      telefone: parseString(json['telefone']),
      fotoUrl: parseString(json['foto_url']),
      posicao: parseString(json['posicao']),
      capitao: json['capitao'] == null ? null : parseBool(json['capitao']),
      timeId: parseInt(json['time_id']),
      timeNome: parseString(json['time_nome']),
      timeEscudoUrl: parseString(json['time_escudo_url']),
      ativo: json['ativo'] == null ? null : parseBool(json['ativo']),
      criadoEm: parseString(json['criado_em']),
    );
  }
}
