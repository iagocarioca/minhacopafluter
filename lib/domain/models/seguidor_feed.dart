import '../../core/utils/json_parsing.dart';

class SeguidorPeladaFeed {
  const SeguidorPeladaFeed({
    required this.ultimasPartidas,
    required this.ultimosGanhadoresVotacao,
  });

  final List<SeguidorUltimaPartida> ultimasPartidas;
  final List<SeguidorUltimoGanhadorVotacao> ultimosGanhadoresVotacao;

  bool get isEmpty =>
      ultimasPartidas.isEmpty && ultimosGanhadoresVotacao.isEmpty;

  factory SeguidorPeladaFeed.fromJson(Map<String, dynamic> json) {
    final feed = parseMap(json['feed']);
    final source = feed.isNotEmpty ? feed : json;

    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      if (raw is! Iterable) return <T>[];
      return raw
          .map(parseMap)
          .where((item) => item.isNotEmpty)
          .map(fromJson)
          .toList();
    }

    return SeguidorPeladaFeed(
      ultimasPartidas: parseList(
        source['ultimas_partidas'],
        SeguidorUltimaPartida.fromJson,
      ),
      ultimosGanhadoresVotacao: parseList(
        source['ultimos_ganhadores_votacao'],
        SeguidorUltimoGanhadorVotacao.fromJson,
      ),
    );
  }
}

class SeguidorUltimaPartida {
  const SeguidorUltimaPartida({
    required this.id,
    required this.timeCasaNome,
    required this.timeForaNome,
    this.timeCasaEscudoUrl,
    this.timeForaEscudoUrl,
    this.rodadaId,
    this.rodadaNumero,
    this.status,
    this.dataHora,
    this.golsCasa,
    this.golsFora,
  });

  final int id;
  final int? rodadaId;
  final int? rodadaNumero;
  final String? status;
  final String? dataHora;
  final String timeCasaNome;
  final String timeForaNome;
  final String? timeCasaEscudoUrl;
  final String? timeForaEscudoUrl;
  final int? golsCasa;
  final int? golsFora;

  factory SeguidorUltimaPartida.fromJson(Map<String, dynamic> json) {
    final partida = parseMap(json['partida']);
    final source = partida.isNotEmpty ? partida : json;

    final rodada = parseMap(json['rodada']);
    final timeCasa = parseMap(source['time_casa_full']).isNotEmpty
        ? parseMap(source['time_casa_full'])
        : parseMap(source['time_casa']);
    final timeFora = parseMap(source['time_fora_full']).isNotEmpty
        ? parseMap(source['time_fora_full'])
        : parseMap(source['time_fora']);

    return SeguidorUltimaPartida(
      id: parseInt(source['id']) ?? 0,
      rodadaId:
          parseInt(source['rodada_id']) ??
          parseInt(json['rodada_id']) ??
          parseInt(rodada['id']),
      rodadaNumero:
          parseInt(rodada['numero']) ??
          parseInt(source['rodada_numero']) ??
          parseInt(json['rodada_numero']),
      status: parseString(source['status']) ?? parseString(json['status']),
      dataHora:
          parseString(source['data_hora']) ??
          parseString(source['inicio']) ??
          parseString(source['fim']) ??
          parseString(json['data_hora']),
      timeCasaNome:
          parseString(source['time_casa_nome']) ??
          parseString(timeCasa['nome']) ??
          'Time casa',
      timeForaNome:
          parseString(source['time_fora_nome']) ??
          parseString(timeFora['nome']) ??
          'Time fora',
      timeCasaEscudoUrl:
          parseString(source['time_casa_escudo_url']) ??
          parseString(timeCasa['escudo_url']) ??
          parseString(timeCasa['logo_url']) ??
          parseString(timeCasa['imagem_destaque_url']),
      timeForaEscudoUrl:
          parseString(source['time_fora_escudo_url']) ??
          parseString(timeFora['escudo_url']) ??
          parseString(timeFora['logo_url']) ??
          parseString(timeFora['imagem_destaque_url']),
      golsCasa:
          parseInt(source['gols_casa']) ?? parseInt(source['placar_casa']),
      golsFora:
          parseInt(source['gols_fora']) ?? parseInt(source['placar_fora']),
    );
  }
}

class SeguidorUltimoGanhadorVotacao {
  const SeguidorUltimoGanhadorVotacao({
    required this.id,
    this.votacaoId,
    this.tipoVotacao,
    this.titulo,
    this.vencedorNome,
    this.vencedorFotoUrl,
    this.timeNome,
    this.encerradaEm,
  });

  final int id;
  final int? votacaoId;
  final String? tipoVotacao;
  final String? titulo;
  final String? vencedorNome;
  final String? vencedorFotoUrl;
  final String? timeNome;
  final String? encerradaEm;

  factory SeguidorUltimoGanhadorVotacao.fromJson(Map<String, dynamic> json) {
    final votacao = parseMap(json['votacao']);
    final source = votacao.isNotEmpty ? votacao : json;

    final vencedor = parseMap(json['vencedor']).isNotEmpty
        ? parseMap(json['vencedor'])
        : parseMap(source['vencedor']).isNotEmpty
        ? parseMap(source['vencedor'])
        : parseMap(source['jogador']);
    final time = parseMap(vencedor['time']).isNotEmpty
        ? parseMap(vencedor['time'])
        : parseMap(source['time']);

    return SeguidorUltimoGanhadorVotacao(
      id: parseInt(json['id']) ?? parseInt(source['id']) ?? 0,
      votacaoId:
          parseInt(source['id']) ??
          parseInt(json['votacao_id']) ??
          parseInt(json['id']),
      tipoVotacao:
          parseString(source['tipo']) ??
          parseString(json['tipo_votacao']) ??
          parseString(json['tipo']),
      titulo:
          parseString(source['titulo']) ??
          parseString(source['descricao']) ??
          parseString(json['titulo']),
      vencedorNome:
          parseString(vencedor['apelido']) ??
          parseString(vencedor['nome_completo']) ??
          parseString(json['vencedor_nome']),
      vencedorFotoUrl:
          parseString(vencedor['foto_url']) ??
          parseString(json['vencedor_foto_url']),
      timeNome: parseString(time['nome']) ?? parseString(json['time_nome']),
      encerradaEm:
          parseString(source['encerrada_em']) ??
          parseString(source['fecha_em']) ??
          parseString(source['updated_at']) ??
          parseString(json['encerrada_em']),
    );
  }
}
