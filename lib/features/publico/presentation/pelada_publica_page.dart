import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/domain/models/pelada_publica.dart';
import 'package:frontcopa_flutter/domain/models/ranking.dart';
import 'package:frontcopa_flutter/domain/models/temporada.dart';
import 'package:frontcopa_flutter/features/peladas/data/peladas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/rankings/data/rankings_remote_data_source.dart';
import 'package:go_router/go_router.dart';

class PeladaPublicaPage extends StatefulWidget {
  const PeladaPublicaPage({
    super.key,
    required this.peladaId,
    required this.config,
    required this.peladasDataSource,
    required this.rankingsDataSource,
  });

  final int peladaId;
  final AppConfig config;
  final PeladasRemoteDataSource peladasDataSource;
  final RankingsRemoteDataSource rankingsDataSource;

  @override
  State<PeladaPublicaPage> createState() => _PeladaPublicaPageState();
}

class _PeladaPublicaPageState extends State<PeladaPublicaPage> {
  PeladaPublicProfile? _profile;

  bool _loading = true;
  bool _loadingRankings = false;
  String? _error;
  int _rankingTabIndex = 0;

  List<RankingTimeEntry> _rankingTimes = const <RankingTimeEntry>[];
  List<RankingJogadorEntry> _artilheiros = const <RankingJogadorEntry>[];
  List<RankingJogadorEntry> _assistencias = const <RankingJogadorEntry>[];

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
      final profile = await widget.peladasDataSource.getPeladaProfile(
        widget.peladaId,
      );

      if (!mounted) return;
      setState(() => _profile = profile);

      final temporadaAtiva = profile.temporadaAtiva;
      if (temporadaAtiva != null && temporadaAtiva.id > 0) {
        await _loadRankings(temporadaAtiva.id);
      } else {
        setState(() {
          _rankingTimes = const <RankingTimeEntry>[];
          _artilheiros = const <RankingJogadorEntry>[];
          _assistencias = const <RankingJogadorEntry>[];
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadRankings(int temporadaId) async {
    setState(() => _loadingRankings = true);
    try {
      final result = await Future.wait([
        widget.rankingsDataSource.getRankingTimes(temporadaId),
        widget.rankingsDataSource.getRankingArtilheiros(temporadaId),
        widget.rankingsDataSource.getRankingAssistencias(temporadaId),
      ]);
      if (!mounted) return;
      setState(() {
        _rankingTimes = result[0] as List<RankingTimeEntry>;
        _artilheiros = result[1] as List<RankingJogadorEntry>;
        _assistencias = result[2] as List<RankingJogadorEntry>;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingRankings = false);
      }
    }
  }

  String _periodoTemporada(dynamic temporada) {
    final inicio = temporada.inicioMes ?? temporada.inicio ?? '-';
    final fim = temporada.fimMes ?? temporada.fim ?? '-';
    return '$inicio - $fim';
  }

  Widget _buildRankingTab() {
    if (_loadingRankings) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_rankingTabIndex == 0) {
      if (_rankingTimes.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text('Sem classificacao disponivel.'),
        );
      }
      return Column(
        children: _rankingTimes.take(8).toList().asMap().entries.map((entry) {
          final position = entry.key + 1;
          final item = entry.value;
          final image = widget.config.resolveApiImageUrl(item.timeEscudoUrl);
          return CyberCard(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Row(
                    children: [
                      Text(
                        '$position',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: image != null
                            ? NetworkImage(image)
                            : null,
                        child: image == null
                            ? const Icon(Icons.shield_rounded, size: 14)
                            : null,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.timeNome,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'V ${item.vitorias}  E ${item.empates}  D ${item.derrotas}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.pontos} pts',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    final items = _rankingTabIndex == 1 ? _artilheiros : _assistencias;
    final unidade = _rankingTabIndex == 1 ? 'gols' : 'assist.';

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Text('Sem dados disponiveis.'),
      );
    }

    return Column(
      children: items.take(8).toList().asMap().entries.map((entry) {
        final position = entry.key + 1;
        final item = entry.value;
        final image = widget.config.resolveApiImageUrl(item.jogadorFotoUrl);
        return CyberCard(
          margin: const EdgeInsets.only(bottom: 8),
          onTap: () => context.push('/perfil/${item.jogadorId}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Row(
                  children: [
                    Text(
                      '$position',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: image != null
                          ? NetworkImage(image)
                          : null,
                      child: image == null
                          ? const Icon(Icons.person_rounded, size: 14)
                          : null,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.jogadorNome,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.timeNome ?? 'Sem time',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.quantidade} $unidade',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final pelada = profile?.pelada;
    final cover = widget.config.resolveApiImageUrl(pelada?.perfilUrl);
    final logo = widget.config.resolveApiImageUrl(pelada?.logoUrl);

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Liga pública'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      height: 220,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (cover != null)
                            Image.network(cover, fit: BoxFit.cover)
                          else
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF222733),
                                    Color(0xFF0F121A),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Color(0xB30F121A)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Spacer(),
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage: logo != null
                                          ? NetworkImage(logo)
                                          : null,
                                      child: logo == null
                                          ? const Icon(Icons.shield_rounded)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pelada?.nome ?? 'Liga',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              if ((pelada?.cidade ?? '')
                                                  .isNotEmpty)
                                                pelada!.cidade,
                                              if ((profile?.gerente?.username ??
                                                      '')
                                                  .isNotEmpty)
                                                'Gerente ${profile!.gerente!.username}',
                                            ].join('  •  '),
                                            style: const TextStyle(
                                              color: Color(0xFFE2E6EF),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _KpiCard(
                        label: 'Jogadores',
                        value:
                            '${profile?.estatisticas?.totalJogadores ?? profile?.jogadores.length ?? 0}',
                      ),
                      _KpiCard(
                        label: 'Temporadas',
                        value:
                            '${profile?.estatisticas?.totalTemporadas ?? profile?.temporadas.length ?? 0}',
                      ),
                      _KpiCard(
                        label: 'Rodadas',
                        value:
                            '${profile?.estatisticas?.rodadasRealizadas ?? 0}',
                      ),
                      _KpiCard(
                        label: 'Partidas',
                        value:
                            '${profile?.estatisticas?.partidasRealizadas ?? 0}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (profile?.temporadaAtiva != null) ...[
                    Text(
                      'Temporada atual',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _periodoTemporada(profile!.temporadaAtiva),
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(value: 0, label: Text('Tabela')),
                        ButtonSegment<int>(value: 1, label: Text('Artilharia')),
                        ButtonSegment<int>(
                          value: 2,
                          label: Text('Assistencias'),
                        ),
                      ],
                      selected: <int>{_rankingTabIndex},
                      onSelectionChanged: (selection) {
                        setState(() => _rankingTabIndex = selection.first);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildRankingTab(),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'Jogadores',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (profile?.jogadores.isEmpty ?? true)
                    const CyberCard(child: Text('Nenhum jogador cadastrado.'))
                  else
                    GridView.builder(
                      itemCount: profile!.jogadores.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.45,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemBuilder: (context, index) {
                        final jogador = profile.jogadores[index];
                        final image = widget.config.resolveApiImageUrl(
                          jogador.fotoUrl,
                        );
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.push('/perfil/${jogador.id}'),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111612),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: image != null
                                      ? NetworkImage(image)
                                      : null,
                                  child: image == null
                                      ? const Icon(Icons.person, size: 14)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    jogador.apelido.isNotEmpty
                                        ? jogador.apelido
                                        : jogador.nomeCompleto,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Historico de temporadas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (profile?.temporadas.isEmpty ?? true)
                    const CyberCard(
                      child: Text('Nenhuma temporada encontrada.'),
                    )
                  else
                    ...profile!.temporadas.map((temporada) {
                      return CyberCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _periodoTemporada(temporada),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: ${temporada.status}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
