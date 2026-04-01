import '../../core/utils/json_parsing.dart';

class RankingTimeEntry {
  const RankingTimeEntry({
    required this.timeId,
    required this.timeNome,
    required this.pontos,
    required this.jogos,
    required this.vitorias,
    required this.empates,
    required this.derrotas,
    required this.golsFeitos,
    required this.golsSofridos,
    required this.saldoGols,
    this.timeEscudoUrl,
    this.timeCor,
  });

  final int timeId;
  final String timeNome;
  final String? timeEscudoUrl;
  final String? timeCor;
  final int pontos;
  final int jogos;
  final int vitorias;
  final int empates;
  final int derrotas;
  final int golsFeitos;
  final int golsSofridos;
  final int saldoGols;
}

class RankingJogadorEntry {
  const RankingJogadorEntry({
    required this.jogadorId,
    required this.jogadorNome,
    required this.quantidade,
    this.jogadorFotoUrl,
    this.timeNome,
  });

  final int jogadorId;
  final String jogadorNome;
  final String? jogadorFotoUrl;
  final int quantidade;
  final String? timeNome;

  factory RankingJogadorEntry.fromApi(dynamic raw) {
    final item = parseMap(raw);
    final jogador = item.containsKey('jogador')
        ? parseMap(item['jogador'])
        : item;

    return RankingJogadorEntry(
      jogadorId:
          parseInt(jogador['id']) ?? parseInt(jogador['jogador_id']) ?? 0,
      jogadorNome:
          parseString(jogador['apelido']) ??
          parseString(jogador['nome_completo']) ??
          'Sem nome',
      jogadorFotoUrl:
          parseString(jogador['foto_url']) ?? parseString(jogador['foto']),
      quantidade:
          parseInt(jogador['total_gols']) ??
          parseInt(jogador['total_assistencias']) ??
          parseInt(jogador['quantidade']) ??
          0,
      timeNome:
          parseString(jogador['time_nome']) ??
          parseString(parseMap(jogador['time'])['nome']),
    );
  }
}
