import '../../core/utils/json_parsing.dart';

class JogadorPerfilPublico {
  const JogadorPerfilPublico({
    required this.apelido,
    required this.nomeCompleto,
    this.fotoUrl,
    this.timeAtual,
    this.timeNome,
    this.posicao,
    this.telefone,
  });

  final String apelido;
  final String nomeCompleto;
  final String? fotoUrl;
  final String? timeAtual;
  final String? timeNome;
  final String? posicao;
  final String? telefone;

  String get nomeExibicao => apelido.trim().isNotEmpty ? apelido : nomeCompleto;

  factory JogadorPerfilPublico.fromJson(Map<String, dynamic> json) {
    return JogadorPerfilPublico(
      apelido: parseString(json['apelido']) ?? '',
      nomeCompleto: parseString(json['nome_completo']) ?? '',
      fotoUrl: parseString(json['foto_url']),
      timeAtual: parseString(json['time_atual']),
      timeNome: parseString(json['time_nome']),
      posicao: parseString(json['posicao']),
      telefone: parseString(json['telefone']),
    );
  }
}

class JogadorEstatisticasPublicas {
  const JogadorEstatisticasPublicas({
    required this.gols,
    required this.assistencias,
    required this.partidas,
    required this.vitorias,
    required this.empates,
    required this.derrotas,
  });

  final int gols;
  final int assistencias;
  final int partidas;
  final int vitorias;
  final int empates;
  final int derrotas;

  factory JogadorEstatisticasPublicas.fromJson(Map<String, dynamic> json) {
    final item = parseMap(json['estatisticas']).isNotEmpty
        ? parseMap(json['estatisticas'])
        : json;
    return JogadorEstatisticasPublicas(
      gols: parseInt(item['gols']) ?? parseInt(item['total_gols']) ?? 0,
      assistencias:
          parseInt(item['assistencias']) ??
          parseInt(item['total_assistencias']) ??
          0,
      partidas:
          parseInt(item['partidas']) ??
          parseInt(item['jogos']) ??
          parseInt(item['partidas_jogadas']) ??
          0,
      vitorias: parseInt(item['vitorias']) ?? 0,
      empates: parseInt(item['empates']) ?? 0,
      derrotas: parseInt(item['derrotas']) ?? 0,
    );
  }
}

class HistoricoPartidaPublica {
  const HistoricoPartidaPublica({
    this.id,
    this.timeCasa,
    this.timeFora,
    required this.placarCasa,
    required this.placarFora,
    this.data,
    required this.gols,
    required this.assistencias,
    this.timeDoJogador,
    this.timeDoJogadorId,
    this.timeCasaId,
    this.timeForaId,
    this.resultado,
  });

  final int? id;
  final String? timeCasa;
  final String? timeFora;
  final int placarCasa;
  final int placarFora;
  final String? data;
  final int gols;
  final int assistencias;
  final String? timeDoJogador;
  final int? timeDoJogadorId;
  final int? timeCasaId;
  final int? timeForaId;
  final String? resultado;

  factory HistoricoPartidaPublica.fromJson(Map<String, dynamic> json) {
    return HistoricoPartidaPublica(
      id: parseInt(json['id']),
      timeCasa:
          parseString(json['time_casa']) ?? parseString(json['time_casa_nome']),
      timeFora:
          parseString(json['time_fora']) ?? parseString(json['time_fora_nome']),
      placarCasa:
          parseInt(json['placar_casa']) ?? parseInt(json['gols_casa']) ?? 0,
      placarFora:
          parseInt(json['placar_fora']) ?? parseInt(json['gols_fora']) ?? 0,
      data:
          parseString(json['data']) ??
          parseString(json['data_hora']) ??
          parseString(json['inicio']),
      gols: parseInt(json['gols']) ?? 0,
      assistencias: parseInt(json['assistencias']) ?? 0,
      timeDoJogador:
          parseString(json['time_do_jogador']) ??
          parseString(json['time_do_jogador_nome']),
      timeDoJogadorId: parseInt(json['time_do_jogador_id']),
      timeCasaId: parseInt(json['time_casa_id']),
      timeForaId: parseInt(json['time_fora_id']),
      resultado: parseString(json['resultado']),
    );
  }
}
