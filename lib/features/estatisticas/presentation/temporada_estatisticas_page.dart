import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/domain/models/ranking.dart';
import 'package:frontcopa_flutter/domain/models/temporada.dart';
import 'package:frontcopa_flutter/features/rankings/data/rankings_remote_data_source.dart';
import 'package:frontcopa_flutter/features/temporadas/data/temporadas_remote_data_source.dart';

class TemporadaEstatisticasPage extends StatefulWidget {
  const TemporadaEstatisticasPage({
    super.key,
    required this.peladaId,
    required this.temporadaId,
    required this.config,
    required this.temporadasDataSource,
    required this.rankingsDataSource,
  });

  final int peladaId;
  final int temporadaId;
  final AppConfig config;
  final TemporadasRemoteDataSource temporadasDataSource;
  final RankingsRemoteDataSource rankingsDataSource;

  @override
  State<TemporadaEstatisticasPage> createState() =>
      _TemporadaEstatisticasPageState();
}

class _TemporadaEstatisticasPageState extends State<TemporadaEstatisticasPage> {
  Temporada? _temporada;
  List<RankingTimeEntry> _rankingTimes = const <RankingTimeEntry>[];
  List<RankingJogadorEntry> _artilheiros = const <RankingJogadorEntry>[];
  List<RankingJogadorEntry> _assistencias = const <RankingJogadorEntry>[];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait([
        widget.temporadasDataSource.getTemporada(
          widget.temporadaId,
          peladaId: widget.peladaId,
        ),
        widget.rankingsDataSource.getRankingTimes(widget.temporadaId),
        widget.rankingsDataSource.getRankingArtilheiros(widget.temporadaId),
        widget.rankingsDataSource.getRankingAssistencias(widget.temporadaId),
      ]);
      if (!mounted) return;
      setState(() {
        _temporada = result[0] as Temporada;
        _rankingTimes = result[1] as List<RankingTimeEntry>;
        _artilheiros = result[2] as List<RankingJogadorEntry>;
        _assistencias = result[3] as List<RankingJogadorEntry>;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int get _totalGols =>
      _artilheiros.fold<int>(0, (sum, item) => sum + item.quantidade);

  int get _totalPartidas {
    final somaJogos = _rankingTimes.fold<int>(
      0,
      (sum, item) => sum + item.jogos,
    );
    return somaJogos > 0 ? (somaJogos / 2).round() : 0;
  }

  String get _periodoTemporada {
    final temporada = _temporada;
    if (temporada == null) return '-';
    final inicio = temporada.inicioMes ?? temporada.inicio ?? '-';
    final fim = temporada.fimMes ?? temporada.fim ?? '-';
    return '$inicio - $fim';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        leading: AppBackButton(
          fallbackLocation:
              '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}',
        ),
        title: const Text('Estatisticas'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  CyberCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estatisticas',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _periodoTemporada,
                          style: const TextStyle(
                            color: Color(0xFF98A0AF),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.55,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _HeroKpi(label: 'Gols', value: '$_totalGols'),
                            _HeroKpi(
                              label: 'Partidas',
                              value: '$_totalPartidas',
                            ),
                            _HeroKpi(
                              label: 'Times',
                              value: '${_rankingTimes.length}',
                            ),
                            _HeroKpi(
                              label: 'Artilheiro',
                              value: _artilheiros.isNotEmpty
                                  ? '${_artilheiros.first.jogadorNome.split(' ').first} (${_artilheiros.first.quantidade})'
                                  : '-',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Classificacao',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_rankingTimes.isEmpty)
                    const CyberCard(
                      child: Text('Nenhuma partida finalizada ainda.'),
                    )
                  else
                    CyberCard(
                      padding: EdgeInsets.zero,
                      child: ListView.builder(
                        itemCount: _rankingTimes.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final item = _rankingTimes[index];
                          final image = widget.config.resolveApiImageUrl(
                            item.timeEscudoUrl,
                          );
                          return ListTile(
                            leading: SizedBox(
                              width: 52,
                              child: Row(
                                children: [
                                  Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: switch (index) {
                                        0 => const Color(0xFFF5C451),
                                        1 => const Color(0xFF98A0AF),
                                        2 => const Color(0xFFB87333),
                                        _ => const Color(0xFFE6F2E8),
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundImage: image != null
                                        ? NetworkImage(image)
                                        : null,
                                    child: image == null
                                        ? const Icon(Icons.shield, size: 14)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            title: Text(item.timeNome),
                            subtitle: Text(
                              'P ${item.jogos}  V ${item.vitorias}  E ${item.empates}  D ${item.derrotas}',
                            ),
                            trailing: Text(
                              '${item.pontos}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 18),
                  _RankingBlock(
                    title: 'Artilharia',
                    items: _artilheiros,
                    config: widget.config,
                    unidade: 'gols',
                  ),
                  const SizedBox(height: 18),
                  _RankingBlock(
                    title: 'Assistencias',
                    items: _assistencias,
                    config: widget.config,
                    unidade: 'assist.',
                  ),
                ],
              ),
            ),
    );
  }
}

class _HeroKpi extends StatelessWidget {
  const _HeroKpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.transparent),
        color: const Color(0x1A121815),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF98A0AF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RankingBlock extends StatelessWidget {
  const _RankingBlock({
    required this.title,
    required this.items,
    required this.config,
    required this.unidade,
  });

  final String title;
  final List<RankingJogadorEntry> items;
  final AppConfig config;
  final String unidade;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const CyberCard(child: Text('Nenhum dado registrado ainda.'))
        else
          CyberCard(
            padding: EdgeInsets.zero,
            child: ListView.builder(
              itemCount: items.take(5).length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final item = items[index];
                final image = config.resolveApiImageUrl(item.jogadorFotoUrl);
                return ListTile(
                  leading: SizedBox(
                    width: 52,
                    child: Row(
                      children: [
                        Text(
                          '${index + 1}o',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: image != null
                              ? NetworkImage(image)
                              : null,
                          child: image == null
                              ? const Icon(Icons.person, size: 14)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  title: Text(item.jogadorNome),
                  subtitle: Text(item.timeNome ?? 'Sem time'),
                  trailing: Text(
                    '${item.quantidade} $unidade',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
