import '../../core/utils/json_parsing.dart';

class ComparativoContextTemporada {
  const ComparativoContextTemporada({
    required this.id,
    this.inicioMes,
    this.fimMes,
    this.status,
  });

  final int id;
  final String? inicioMes;
  final String? fimMes;
  final String? status;

  factory ComparativoContextTemporada.fromJson(Map<String, dynamic> json) {
    return ComparativoContextTemporada(
      id: parseInt(json['id']) ?? 0,
      inicioMes: parseString(json['inicio_mes']),
      fimMes: parseString(json['fim_mes']),
      status: parseString(json['status']),
    );
  }
}

class ComparativoContexto {
  const ComparativoContexto({
    required this.escopo,
    required this.label,
    this.temporada,
  });

  final String escopo;
  final String label;
  final ComparativoContextTemporada? temporada;

  factory ComparativoContexto.fromJson(Map<String, dynamic> json) {
    final temporadaJson = parseMap(json['temporada']);
    return ComparativoContexto(
      escopo: parseString(json['escopo']) ?? 'atual',
      label: parseString(json['label']) ?? 'Comparativo',
      temporada: temporadaJson.isEmpty
          ? null
          : ComparativoContextTemporada.fromJson(temporadaJson),
    );
  }
}

class ComparativoJogadorResumo {
  const ComparativoJogadorResumo({
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

  factory ComparativoJogadorResumo.fromJson(Map<String, dynamic> json) {
    return ComparativoJogadorResumo(
      id: parseInt(json['id']) ?? parseInt(json['jogador_id']) ?? 0,
      nomeCompleto: parseString(json['nome_completo']) ?? '',
      apelido: parseString(json['apelido']),
      fotoUrl: parseString(json['foto_url']),
    );
  }
}

class ComparativoJogadorEstatisticas {
  const ComparativoJogadorEstatisticas({
    required this.vitorias,
    required this.empates,
    required this.derrotas,
    required this.totalPartidas,
    required this.golsMarcados,
    required this.assistencias,
    required this.titulos,
    required this.pontos,
    required this.votosRecebidos,
    required this.pontosVotos,
  });

  final int vitorias;
  final int empates;
  final int derrotas;
  final int totalPartidas;
  final int golsMarcados;
  final int assistencias;
  final int titulos;
  final int pontos;
  final int votosRecebidos;
  final int pontosVotos;

  factory ComparativoJogadorEstatisticas.fromJson(Map<String, dynamic> json) {
    return ComparativoJogadorEstatisticas(
      vitorias: parseInt(json['vitorias']) ?? 0,
      empates: parseInt(json['empates']) ?? 0,
      derrotas: parseInt(json['derrotas']) ?? 0,
      totalPartidas: parseInt(json['total_partidas']) ?? 0,
      golsMarcados: parseInt(json['gols_marcados']) ?? 0,
      assistencias: parseInt(json['assistencias']) ?? 0,
      titulos: parseInt(json['titulos']) ?? 0,
      pontos: parseInt(json['pontos']) ?? 0,
      votosRecebidos: parseInt(json['votos_recebidos']) ?? 0,
      pontosVotos: parseInt(json['pontos_votos']) ?? 0,
    );
  }
}

class ComparativoJogadorEntry {
  const ComparativoJogadorEntry({
    required this.posicao,
    required this.jogador,
    required this.estatisticas,
  });

  final int posicao;
  final ComparativoJogadorResumo jogador;
  final ComparativoJogadorEstatisticas estatisticas;

  factory ComparativoJogadorEntry.fromJson(Map<String, dynamic> json) {
    return ComparativoJogadorEntry(
      posicao: parseInt(json['posicao']) ?? 0,
      jogador: ComparativoJogadorResumo.fromJson(parseMap(json['jogador'])),
      estatisticas: ComparativoJogadorEstatisticas.fromJson(
        parseMap(json['estatisticas']),
      ),
    );
  }
}

class ComparativoVencedor {
  const ComparativoVencedor({
    required this.titulo,
    required this.campo,
    required this.valor,
    required this.jogadoresIds,
    required this.empate,
  });

  final String titulo;
  final String campo;
  final int valor;
  final List<int> jogadoresIds;
  final bool empate;

  factory ComparativoVencedor.fromJson(Map<String, dynamic> json) {
    final idsRaw = json['jogadores_ids'];
    final jogadoresIds = idsRaw is Iterable
        ? idsRaw.map(parseInt).whereType<int>().toList()
        : const <int>[];
    return ComparativoVencedor(
      titulo: parseString(json['titulo']) ?? '',
      campo: parseString(json['campo']) ?? '',
      valor: parseInt(json['valor']) ?? 0,
      jogadoresIds: jogadoresIds,
      empate: parseBool(json['empate']),
    );
  }
}

class ComparativoJogadoresData {
  const ComparativoJogadoresData({
    required this.peladaId,
    required this.peladaNome,
    required this.contexto,
    required this.comparativo,
    required this.vencedores,
  });

  final int peladaId;
  final String peladaNome;
  final ComparativoContexto contexto;
  final List<ComparativoJogadorEntry> comparativo;
  final Map<String, ComparativoVencedor> vencedores;

  factory ComparativoJogadoresData.fromJson(Map<String, dynamic> json) {
    final peladaJson = parseMap(json['pelada']);
    final contextoJson = parseMap(json['contexto']);

    final comparativoRaw = json['comparativo'];
    final comparativo = comparativoRaw is Iterable
        ? comparativoRaw
              .map(parseMap)
              .where((item) => item.isNotEmpty)
              .map(ComparativoJogadorEntry.fromJson)
              .toList()
        : const <ComparativoJogadorEntry>[];

    final vencedoresRaw = parseMap(json['vencedores']);
    final vencedores = <String, ComparativoVencedor>{};
    for (final entry in vencedoresRaw.entries) {
      final item = parseMap(entry.value);
      if (item.isEmpty) continue;
      vencedores[entry.key] = ComparativoVencedor.fromJson(item);
    }

    return ComparativoJogadoresData(
      peladaId: parseInt(peladaJson['id']) ?? 0,
      peladaNome: parseString(peladaJson['nome']) ?? '',
      contexto: ComparativoContexto.fromJson(contextoJson),
      comparativo: comparativo,
      vencedores: vencedores,
    );
  }
}
