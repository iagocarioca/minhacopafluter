import '../../core/utils/json_parsing.dart';

class SubstituicaoJogador {
  const SubstituicaoJogador({
    required this.id,
    required this.nomeCompleto,
    this.apelido,
    this.fotoUrl,
  });

  final int id;
  final String nomeCompleto;
  final String? apelido;
  final String? fotoUrl;

  String get nomeExibicao =>
      apelido?.trim().isNotEmpty == true ? apelido! : nomeCompleto;

  factory SubstituicaoJogador.fromJson(Map<String, dynamic> json) {
    return SubstituicaoJogador(
      id: parseInt(json['id']) ?? 0,
      nomeCompleto: parseString(json['nome_completo']) ?? '',
      apelido: parseString(json['apelido']),
      fotoUrl: parseString(json['foto_url']),
    );
  }
}

class Substituicao {
  const Substituicao({
    required this.id,
    required this.rodadaId,
    required this.timeId,
    required this.jogadorAusente,
    required this.jogadorSubstituto,
    this.criadoEm,
  });

  final int id;
  final int rodadaId;
  final int timeId;
  final SubstituicaoJogador jogadorAusente;
  final SubstituicaoJogador jogadorSubstituto;
  final String? criadoEm;

  factory Substituicao.fromJson(Map<String, dynamic> json) {
    return Substituicao(
      id: parseInt(json['id']) ?? 0,
      rodadaId: parseInt(json['rodada_id']) ?? 0,
      timeId: parseInt(json['time_id']) ?? 0,
      jogadorAusente: SubstituicaoJogador.fromJson(
        parseMap(json['jogador_ausente']),
      ),
      jogadorSubstituto: SubstituicaoJogador.fromJson(
        parseMap(json['jogador_substituto']),
      ),
      criadoEm: parseString(json['criado_em']),
    );
  }
}
