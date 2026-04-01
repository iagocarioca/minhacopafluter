import '../../core/utils/json_parsing.dart';

class TransferenciaTimeRef {
  const TransferenciaTimeRef({required this.id, required this.nome});

  final int id;
  final String nome;

  factory TransferenciaTimeRef.fromJson(Map<String, dynamic> json) {
    return TransferenciaTimeRef(
      id: parseInt(json['id']) ?? 0,
      nome: parseString(json['nome']) ?? '',
    );
  }
}

class TransferenciaJogadorRef {
  const TransferenciaJogadorRef({
    required this.id,
    required this.nomeCompleto,
    required this.apelido,
    required this.timeAnterior,
    this.timeNovo,
    this.posicao,
    this.capitao,
  });

  final int id;
  final String nomeCompleto;
  final String apelido;
  final TransferenciaTimeRef timeAnterior;
  final TransferenciaTimeRef? timeNovo;
  final String? posicao;
  final bool? capitao;

  String get nomeExibicao => apelido.trim().isNotEmpty ? apelido : nomeCompleto;

  factory TransferenciaJogadorRef.fromJson(Map<String, dynamic> json) {
    return TransferenciaJogadorRef(
      id: parseInt(json['id']) ?? 0,
      nomeCompleto: parseString(json['nome_completo']) ?? '',
      apelido: parseString(json['apelido']) ?? '',
      timeAnterior: TransferenciaTimeRef.fromJson(
        parseMap(json['time_anterior']),
      ),
      timeNovo: parseMap(json['time_novo']).isEmpty
          ? null
          : TransferenciaTimeRef.fromJson(parseMap(json['time_novo'])),
      posicao: parseString(json['posicao']),
      capitao: json['capitao'] == null ? null : parseBool(json['capitao']),
    );
  }
}

class Transferencia {
  const Transferencia({
    required this.id,
    required this.temporadaId,
    required this.jogadorOrigem,
    required this.jogadorDestino,
    this.criadoEm,
  });

  final int id;
  final int temporadaId;
  final String? criadoEm;
  final TransferenciaJogadorRef jogadorOrigem;
  final TransferenciaJogadorRef jogadorDestino;

  factory Transferencia.fromJson(Map<String, dynamic> json) {
    return Transferencia(
      id: parseInt(json['id']) ?? 0,
      temporadaId: parseInt(json['temporada_id']) ?? 0,
      criadoEm: parseString(json['criado_em']),
      jogadorOrigem: TransferenciaJogadorRef.fromJson(
        parseMap(json['jogador_origem']),
      ),
      jogadorDestino: TransferenciaJogadorRef.fromJson(
        parseMap(json['jogador_destino']),
      ),
    );
  }
}
