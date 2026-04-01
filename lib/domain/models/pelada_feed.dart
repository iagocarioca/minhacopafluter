import '../../core/utils/json_parsing.dart';

class PeladaFeedItem {
  const PeladaFeedItem({
    required this.id,
    required this.nome,
    required this.partidasRecentes,
    required this.rodadasRecentes,
    this.iconeUrl,
    this.instagramUrl,
  });

  final int id;
  final String nome;
  final String? iconeUrl;
  final String? instagramUrl;
  final int partidasRecentes;
  final int rodadasRecentes;

  factory PeladaFeedItem.fromJson(Map<String, dynamic> json) {
    final partidas = parseInt(json['partidas_recentes']);
    final rodadas = parseInt(json['rodadas_recentes']);
    return PeladaFeedItem(
      id: parseInt(json['id']) ?? 0,
      nome: parseString(json['nome']) ?? '',
      iconeUrl: parseString(json['icone_url']),
      instagramUrl: parseString(json['instagram_url']),
      partidasRecentes: partidas ?? rodadas ?? 0,
      rodadasRecentes: rodadas ?? 0,
    );
  }
}

class PeladasFeedResponse {
  const PeladasFeedResponse({
    required this.periodoSemanas,
    required this.limite,
    required this.feed,
    this.dataInicio,
  });

  final int periodoSemanas;
  final int limite;
  final String? dataInicio;
  final List<PeladaFeedItem> feed;

  factory PeladasFeedResponse.fromJson(Map<String, dynamic> json) {
    final rawFeed = json['feed'];
    final items = rawFeed is Iterable
        ? rawFeed
              .map(parseMap)
              .where((item) => item.isNotEmpty)
              .map(PeladaFeedItem.fromJson)
              .toList()
        : const <PeladaFeedItem>[];

    return PeladasFeedResponse(
      periodoSemanas: parseInt(json['periodo_semanas']) ?? 4,
      limite: parseInt(json['limite']) ?? items.length,
      dataInicio: parseString(json['data_inicio']),
      feed: items,
    );
  }
}
