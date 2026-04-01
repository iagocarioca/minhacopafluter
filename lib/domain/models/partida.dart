import '../../core/utils/json_parsing.dart';

class PartidaTeam {
  const PartidaTeam({
    required this.id,
    required this.nome,
    this.escudoUrl,
    this.imagemDestaqueUrl,
    this.cor,
  });

  final int id;
  final String nome;
  final String? escudoUrl;
  final String? imagemDestaqueUrl;
  final String? cor;

  factory PartidaTeam.fromJson(Map<String, dynamic> json) {
    return PartidaTeam(
      id: parseInt(json['id']) ?? 0,
      nome: parseString(json['nome']) ?? '',
      escudoUrl: parseString(json['escudo_url']),
      imagemDestaqueUrl:
          parseString(json['capitao_foto_url']) ??
          parseString(json['foto_url']) ??
          parseString(json['imagem_url']) ??
          parseString(json['avatar_url']),
      cor: parseString(json['cor']),
    );
  }
}

class GolEvent {
  const GolEvent({
    required this.id,
    required this.timeId,
    required this.jogadorId,
    this.assistenciaId,
    this.minuto,
    this.golContra = false,
    this.jogadorNome,
    this.jogadorFotoUrl,
    this.assistenciaNome,
    this.assistenciaFotoUrl,
  });

  final int id;
  final int timeId;
  final int jogadorId;
  final int? assistenciaId;
  final int? minuto;
  final bool golContra;
  final String? jogadorNome;
  final String? jogadorFotoUrl;
  final String? assistenciaNome;
  final String? assistenciaFotoUrl;

  factory GolEvent.fromJson(Map<String, dynamic> json) {
    final jogador = parseMap(json['jogador']);
    final assistente = parseMap(json['assistente']);
    final assistencia = parseMap(json['assistencia']);
    final assistenciaMap = assistente.isNotEmpty ? assistente : assistencia;

    return GolEvent(
      id: parseInt(json['id']) ?? 0,
      timeId: parseInt(json['time_id']) ?? 0,
      jogadorId: parseInt(json['jogador_id']) ?? 0,
      assistenciaId: parseInt(json['assistencia_id']),
      minuto: parseInt(json['minuto']),
      golContra: parseBool(json['gol_contra']),
      jogadorNome:
          parseString(jogador['apelido']) ??
          parseString(jogador['nome_completo']),
      jogadorFotoUrl: parseString(jogador['foto_url']),
      assistenciaNome:
          parseString(assistenciaMap['apelido']) ??
          parseString(assistenciaMap['nome_completo']),
      assistenciaFotoUrl: parseString(assistenciaMap['foto_url']),
    );
  }
}

class Partida {
  const Partida({
    required this.id,
    required this.rodadaId,
    required this.timeCasaId,
    required this.timeForaId,
    required this.status,
    this.golsCasa,
    this.golsFora,
    this.placarCasa,
    this.placarFora,
    this.inicio,
    this.fim,
    this.dataHora,
    this.local,
    this.timeCasa,
    this.timeFora,
    this.gols = const <GolEvent>[],
  });

  final int id;
  final int rodadaId;
  final int timeCasaId;
  final int timeForaId;
  final String status;
  final int? golsCasa;
  final int? golsFora;
  final int? placarCasa;
  final int? placarFora;
  final String? inicio;
  final String? fim;
  final String? dataHora;
  final String? local;
  final PartidaTeam? timeCasa;
  final PartidaTeam? timeFora;
  final List<GolEvent> gols;

  int get scoreCasa => golsCasa ?? placarCasa ?? 0;
  int get scoreFora => golsFora ?? placarFora ?? 0;

  factory Partida.fromJson(Map<String, dynamic> json) {
    final timeCasaMap = _pickTeamMap(json, 'time_casa_full', 'time_casa');
    final timeForaMap = _pickTeamMap(json, 'time_fora_full', 'time_fora');

    final golsRaw = json['gols'];
    final gols = golsRaw is Iterable
        ? golsRaw
              .map(parseMap)
              .where((item) => item.isNotEmpty)
              .map(GolEvent.fromJson)
              .toList()
        : const <GolEvent>[];

    return Partida(
      id: parseInt(json['id']) ?? 0,
      rodadaId: parseInt(json['rodada_id']) ?? 0,
      timeCasaId: parseInt(json['time_casa_id']) ?? 0,
      timeForaId: parseInt(json['time_fora_id']) ?? 0,
      status: parseString(json['status']) ?? '',
      golsCasa: parseInt(json['gols_casa']),
      golsFora: parseInt(json['gols_fora']),
      placarCasa: parseInt(json['placar_casa']),
      placarFora: parseInt(json['placar_fora']),
      inicio: parseString(json['inicio']),
      fim: parseString(json['fim']),
      dataHora: parseString(json['data_hora']),
      local: parseString(json['local']),
      timeCasa: timeCasaMap.isEmpty ? null : PartidaTeam.fromJson(timeCasaMap),
      timeFora: timeForaMap.isEmpty ? null : PartidaTeam.fromJson(timeForaMap),
      gols: gols,
    );
  }

  static Map<String, dynamic> _pickTeamMap(
    Map<String, dynamic> json,
    String preferredKey,
    String fallbackKey,
  ) {
    final preferred = parseMap(json[preferredKey]);
    if (preferred.isNotEmpty) return preferred;
    return parseMap(json[fallbackKey]);
  }
}
