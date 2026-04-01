import '../../core/utils/json_parsing.dart';
import 'jogador.dart';
import 'pelada.dart';
import 'temporada.dart';
import 'user.dart';

class PeladaPublicaEstatisticas {
  const PeladaPublicaEstatisticas({
    required this.totalJogadores,
    required this.totalTemporadas,
    required this.rodadasRealizadas,
    required this.partidasRealizadas,
  });

  final int totalJogadores;
  final int totalTemporadas;
  final int rodadasRealizadas;
  final int partidasRealizadas;

  factory PeladaPublicaEstatisticas.fromJson(Map<String, dynamic> json) {
    return PeladaPublicaEstatisticas(
      totalJogadores: parseInt(json['total_jogadores']) ?? 0,
      totalTemporadas: parseInt(json['total_temporadas']) ?? 0,
      rodadasRealizadas: parseInt(json['rodadas_realizadas']) ?? 0,
      partidasRealizadas: parseInt(json['partidas_realizadas']) ?? 0,
    );
  }
}

class PeladaPublicProfile {
  const PeladaPublicProfile({
    required this.pelada,
    this.gerente,
    this.estatisticas,
    this.jogadores = const <Jogador>[],
    this.temporadas = const <Temporada>[],
    this.temporadaAtiva,
  });

  final Pelada pelada;
  final User? gerente;
  final PeladaPublicaEstatisticas? estatisticas;
  final List<Jogador> jogadores;
  final List<Temporada> temporadas;
  final Temporada? temporadaAtiva;

  factory PeladaPublicProfile.fromJson(Map<String, dynamic> json) {
    final pelada = Pelada.fromJson(parseMap(json['pelada']));
    final gerenteMap = parseMap(json['gerente']);
    final estatisticasMap = parseMap(json['estatisticas']);

    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      if (raw is! Iterable) {
        return <T>[];
      }
      return raw
          .map(parseMap)
          .where((item) => item.isNotEmpty)
          .map(fromJson)
          .toList();
    }

    final temporadaAtivaRaw = parseMap(json['temporada_ativa']).isNotEmpty
        ? parseMap(json['temporada_ativa'])
        : parseMap(json['temporada_atual']);
    final temporadaAtivaNesting = parseMap(temporadaAtivaRaw['temporada']);
    final temporadaAtivaMap = temporadaAtivaNesting.isNotEmpty
        ? temporadaAtivaNesting
        : temporadaAtivaRaw;

    final temporadas = parseList(json['temporadas'], Temporada.fromJson);
    final temporadaAtiva = temporadaAtivaMap.isNotEmpty
        ? Temporada.fromJson(temporadaAtivaMap)
        : temporadas.firstWhere(
            (item) => item.status == 'ativa',
            orElse: () => temporadas.isNotEmpty
                ? temporadas.first
                : const Temporada(id: 0, peladaId: 0, status: ''),
          );

    return PeladaPublicProfile(
      pelada: pelada,
      gerente: gerenteMap.isEmpty ? null : User.fromJson(gerenteMap),
      estatisticas: estatisticasMap.isEmpty
          ? null
          : PeladaPublicaEstatisticas.fromJson(estatisticasMap),
      jogadores: parseList(json['jogadores'], Jogador.fromJson),
      temporadas: temporadas,
      temporadaAtiva: temporadaAtiva.id == 0 ? null : temporadaAtiva,
    );
  }
}
