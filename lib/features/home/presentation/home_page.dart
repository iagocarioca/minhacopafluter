import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cyber_card.dart';
import '../../../domain/models/partida.dart';
import '../../../domain/models/pelada.dart';
import '../../../domain/models/pelada_feed.dart';
import '../../../domain/models/ranking.dart';
import '../../../domain/models/temporada.dart';
import '../../auth/state/auth_controller.dart';
import '../../partidas/data/partidas_remote_data_source.dart';
import '../../peladas/data/peladas_remote_data_source.dart';
import '../../perfis/data/perfis_remote_data_source.dart';
import '../../rankings/data/rankings_remote_data_source.dart';
import '../../rodadas/data/rodadas_remote_data_source.dart';
import '../../temporadas/data/temporadas_remote_data_source.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.authController,
    required this.config,
    required this.peladasDataSource,
    required this.temporadasDataSource,
    required this.rodadasDataSource,
    required this.partidasDataSource,
    required this.rankingsDataSource,
    required this.perfisDataSource,
  });

  final AuthController authController;
  final AppConfig config;
  final PeladasRemoteDataSource peladasDataSource;
  final TemporadasRemoteDataSource temporadasDataSource;
  final RodadasRemoteDataSource rodadasDataSource;
  final PartidasRemoteDataSource partidasDataSource;
  final RankingsRemoteDataSource rankingsDataSource;
  final PerfisRemoteDataSource perfisDataSource;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  String? _error;

  int? _peladaId;
  int? _temporadaId;
  int? _selectedPeladaId;

  List<Pelada> _peladas = const <Pelada>[];
  List<PeladaFeedItem> _topPeladasAtivas = const <PeladaFeedItem>[];
  List<_HomeTopPlayerEntry> _topPlayers = const <_HomeTopPlayerEntry>[];
  List<Partida> _recentMatches = const <Partida>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setTopPeladas(List<PeladaFeedItem> items) {
    _topPeladasAtivas = items;
  }

  DateTime? _parseTemporadaDate(Temporada temporada) {
    final raw = temporada.inicioMes ?? temporada.inicio ?? temporada.criadoEm;
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim();
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) return parsed;

    const patterns = <String>['dd/MM/yyyy', 'dd-MM-yyyy', 'MM/yyyy', 'yyyy-MM'];
    for (final pattern in patterns) {
      try {
        return DateFormat(pattern).parseStrict(normalized);
      } catch (_) {
        // Try next supported format.
      }
    }
    return null;
  }

  int? _extractTemporadaYear(Temporada temporada) {
    return _parseTemporadaDate(temporada)?.year;
  }

  Future<List<_HomeTopPlayerEntry>> _loadAnnualTopPlayers({
    required Temporada temporadaBase,
    required List<Temporada> temporadasPelada,
  }) async {
    final year = _extractTemporadaYear(temporadaBase);
    final temporadasAno = year == null
        ? <Temporada>[temporadaBase]
        : temporadasPelada
              .where((item) => _extractTemporadaYear(item) == year)
              .toList();
    final alvo = temporadasAno.isEmpty
        ? <Temporada>[temporadaBase]
        : temporadasAno;

    final rankingsPorTemporada = await Future.wait(
      alvo.map((temporada) async {
        try {
          return await widget.rankingsDataSource.getRankingArtilheiros(
            temporada.id,
          );
        } catch (_) {
          return const <RankingJogadorEntry>[];
        }
      }),
    );

    final merged = <int, _HomeTopPlayerAccumulator>{};
    for (final rankingTemporada in rankingsPorTemporada) {
      for (final item in rankingTemporada) {
        if (item.jogadorId <= 0) continue;
        final current = merged.putIfAbsent(
          item.jogadorId,
          () => _HomeTopPlayerAccumulator(
            jogadorId: item.jogadorId,
            nome: item.jogadorNome,
            fotoUrl: item.jogadorFotoUrl,
            gols: 0,
          ),
        );
        current.gols += item.quantidade;
        if ((current.fotoUrl == null || current.fotoUrl!.isEmpty) &&
            item.jogadorFotoUrl != null &&
            item.jogadorFotoUrl!.isNotEmpty) {
          current.fotoUrl = item.jogadorFotoUrl;
        }
      }
    }

    final annual =
        merged.values
            .map(
              (entry) => _HomeTopPlayerEntry(
                jogadorId: entry.jogadorId,
                nome: entry.nome,
                fotoUrl: entry.fotoUrl,
                gols: entry.gols,
                vitorias: 0,
                derrotas: 0,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byGoals = b.gols.compareTo(a.gols);
            if (byGoals != 0) return byGoals;
            return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
          });

    final top = annual.take(8).toList();
    await Future.wait(
      top.map((player) async {
        try {
          final stats = await widget.perfisDataSource.getEstatisticas(
            player.jogadorId,
          );
          player.vitorias = stats.vitorias;
          player.derrotas = stats.derrotas;
        } catch (_) {
          // Keep defaults when stats endpoint is unavailable.
        }
      }),
    );
    return top;
  }

  Future<void> _load({int? selectedPeladaId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    var topPeladas = _topPeladasAtivas;
    var topPlayers = _topPlayers;
    try {
      final feedResponse = await widget.peladasDataSource.getPublicPeladasFeed(
        semanas: 4,
        limit: 12,
        somenteComInstagram: true,
      );
      topPeladas = feedResponse.feed;
    } catch (_) {
      topPeladas = const <PeladaFeedItem>[];
    }

    try {
      final peladasResponse = await widget.peladasDataSource.listPeladas(
        page: 1,
        perPage: 40,
        usuarioId: widget.authController.currentUser?.id,
      );
      final peladas = List<Pelada>.from(peladasResponse.items);
      if (topPeladas.isEmpty) {
        topPeladas = peladas
            .where((item) => item.ativa)
            .take(12)
            .map(
              (item) => PeladaFeedItem(
                id: item.id,
                nome: item.nome,
                iconeUrl: item.logoUrl,
                instagramUrl: item.instagramUrl,
                partidasRecentes: 0,
                rodadasRecentes: 0,
              ),
            )
            .toList();
      }

      if (peladas.isEmpty) {
        if (!mounted) return;
        setState(() {
          _peladas = const <Pelada>[];
          _setTopPeladas(topPeladas);
          _topPlayers = const <_HomeTopPlayerEntry>[];
          _peladaId = null;
          _temporadaId = null;
          _selectedPeladaId = null;
          _recentMatches = const <Partida>[];
        });
        return;
      }

      final peladaDefault = peladas.firstWhere(
        (item) => item.ativa,
        orElse: () => peladas.first,
      );

      final alvoId = selectedPeladaId ?? _selectedPeladaId;
      final peladaSelecionada = peladas.firstWhere(
        (item) => item.id == alvoId,
        orElse: () => peladaDefault,
      );

      final temporadas = await widget.temporadasDataSource.listTemporadas(
        peladaId: peladaSelecionada.id,
        page: 1,
        perPage: 50,
      );

      if (temporadas.items.isEmpty) {
        if (!mounted) return;
        setState(() {
          _peladas = peladas;
          _setTopPeladas(topPeladas);
          _topPlayers = const <_HomeTopPlayerEntry>[];
          _peladaId = peladaSelecionada.id;
          _selectedPeladaId = peladaSelecionada.id;
          _temporadaId = null;
          _recentMatches = const <Partida>[];
        });
        return;
      }

      final temporada = temporadas.items.firstWhere(
        (item) => item.status == 'ativa',
        orElse: () => temporadas.items.first,
      );

      try {
        topPlayers = await _loadAnnualTopPlayers(
          temporadaBase: temporada,
          temporadasPelada: temporadas.items,
        );
      } catch (_) {
        topPlayers = const <_HomeTopPlayerEntry>[];
      }

      final rodadas = await widget.rodadasDataSource.listRodadas(
        temporadaId: temporada.id,
        page: 1,
        perPage: 30,
      );

      if (rodadas.items.isEmpty) {
        if (!mounted) return;
        setState(() {
          _peladas = peladas;
          _setTopPeladas(topPeladas);
          _topPlayers = topPlayers.take(8).toList();
          _peladaId = peladaSelecionada.id;
          _selectedPeladaId = peladaSelecionada.id;
          _temporadaId = temporada.id;
          _recentMatches = const <Partida>[];
        });
        return;
      }

      final rodadaAtual = rodadas.items.reduce((a, b) => (a.id > b.id ? a : b));
      final partidas = await widget.partidasDataSource.listPartidas(
        rodadaAtual.id,
      );

      if (!mounted) return;
      setState(() {
        _peladas = peladas;
        _setTopPeladas(topPeladas);
        _topPlayers = topPlayers.take(8).toList();
        _peladaId = peladaSelecionada.id;
        _selectedPeladaId = peladaSelecionada.id;
        _temporadaId = temporada.id;
        _recentMatches = partidas.take(4).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _setTopPeladas(topPeladas);
        _topPlayers = topPlayers.take(8).toList();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectPelada(Pelada pelada) async {
    if (_selectedPeladaId == pelada.id && _peladaId == pelada.id) {
      context.go('/peladas/${pelada.id}');
      return;
    }
    await _load(selectedPeladaId: pelada.id);
  }

  Uri? _instagramUri(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.tryParse(value);
    }

    if (value.toLowerCase().contains('instagram.com/')) {
      return Uri.tryParse('https://$value');
    }

    final handle = value.startsWith('@') ? value.substring(1) : value;
    if (handle.isEmpty) return null;
    return Uri.tryParse('https://www.instagram.com/$handle');
  }

  Future<void> _openInstagram(String? url) async {
    final uri = _instagramUri(url);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir o Instagram.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.authController.currentUser?.username ?? 'Jogador';
    final canOpenRanking = _peladaId != null && _temporadaId != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF79C788),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white.withValues(alpha: 0.26),
                          child: Text(
                            username.isNotEmpty
                                ? username.substring(0, 1).toUpperCase()
                                : 'M',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ola, $username',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        _HeaderAction(
                          icon: Icons.refresh_rounded,
                          onTap: _loading ? null : _load,
                        ),
                        const SizedBox(width: 6),
                        _HeaderAction(
                          icon: Icons.logout_rounded,
                          onTap: () => widget.authController.logout(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const _PeladaPillsSkeleton()
                    else if (_peladas.isNotEmpty)
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _peladas.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final pelada = _peladas[index];
                            return _PeladaPill(
                              name: pelada.nome,
                              imageUrl: widget.config.resolveApiImageUrl(
                                pelada.logoUrl,
                              ),
                              selected:
                                  pelada.id == (_selectedPeladaId ?? _peladaId),
                              onTap: _loading
                                  ? null
                                  : () => _selectPelada(pelada),
                            );
                          },
                        ),
                      )
                    else
                      const SizedBox(height: 72),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: 'Melhores Peladas',
                    actionLabel: 'Atualizar',
                    onAction: _loading ? null : _load,
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const SizedBox(
                      height: 178,
                      child: _TopPeladasSkeletonList(),
                    )
                  else if (_topPeladasAtivas.isNotEmpty)
                    SizedBox(
                      height: 178,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _topPeladasAtivas.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = _topPeladasAtivas[index];
                          return _TopActiveLeagueCard(
                            nome: item.nome,
                            iconUrl: widget.config.resolveApiImageUrl(
                              item.iconeUrl,
                            ),
                            instagramUrl: item.instagramUrl,
                            partidasRecentes: item.partidasRecentes,
                            rodadasRecentes: item.rodadasRecentes,
                            rank: index + 1,
                            featured: index == 0,
                            onTap: () =>
                                context.push('/peladas/${item.id}/publico'),
                            onInstagramTap: () =>
                                _openInstagram(item.instagramUrl),
                          );
                        },
                      ),
                    )
                  else
                    const SizedBox(height: 178),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'MVP',
                    actionLabel: 'Ver todos',
                    onAction: canOpenRanking
                        ? () => context.go(
                            '/peladas/$_peladaId/temporadas/$_temporadaId/rankings/anual',
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const SizedBox(
                      height: 196,
                      child: _TopPlayersSkeletonList(),
                    )
                  else if (_topPlayers.isNotEmpty)
                    SizedBox(
                      height: 196,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _topPlayers.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final player = _topPlayers[index];
                          return _TopPlayerCard(
                            nome: player.nome,
                            fotoUrl: widget.config.resolveApiImageUrl(
                              player.fotoUrl,
                            ),
                            gols: player.gols,
                            vitorias: player.vitorias,
                            derrotas: player.derrotas,
                            rank: index + 1,
                            highlighted: index == 0,
                            onTap: player.jogadorId > 0
                                ? () => context.push(
                                    '/perfil/${player.jogadorId}',
                                  )
                                : null,
                          );
                        },
                      ),
                    )
                  else
                    const SizedBox(height: 196),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'Ultimos jogos',
                    actionLabel: 'Ver todos',
                    onAction: () => context.go('/peladas'),
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const SizedBox(
                      height: 154,
                      child: _UltimosJogosSkeletonList(),
                    ),
                  if (_error != null && !_loading)
                    CyberCard(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFDA3F4D)),
                      ),
                    ),
                  if (!_loading && _error == null && _recentMatches.isNotEmpty)
                    SizedBox(
                      height: 154,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentMatches.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final partida = _recentMatches[index];
                          return _UpcomingMatchCard(
                            partida: partida,
                            config: widget.config,
                            onTap: _peladaId == null
                                ? null
                                : () => context.go(
                                    '/peladas/$_peladaId/partidas/${partida.id}',
                                  ),
                          );
                        },
                      ),
                    ),
                  if (!_loading && _error == null && _recentMatches.isEmpty)
                    const SizedBox(height: 154),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: AppTheme.textPrimary,
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8A94A3),
              disabledForegroundColor: const Color(0xFFB4BCC8),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _PeladaPill extends StatelessWidget {
  const _PeladaPill({
    required this.name,
    required this.imageUrl,
    required this.selected,
    this.onTap,
  });

  final String name;
  final String? imageUrl;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = selected ? Colors.white : Colors.white70;

    return SizedBox(
      width: 72,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0),
                  width: 1.8,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallbackAvatar(),
                    )
                  : _fallbackAvatar(),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: labelColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: Colors.white.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'P',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}

class _TopPlayerCard extends StatelessWidget {
  const _TopPlayerCard({
    required this.nome,
    required this.gols,
    required this.vitorias,
    required this.derrotas,
    required this.rank,
    this.fotoUrl,
    this.highlighted = false,
    this.onTap,
  });

  final String nome;
  final int gols;
  final int vitorias;
  final int derrotas;
  final int rank;
  final String? fotoUrl;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = highlighted
        ? const Color(0xFFFDECEE)
        : const Color(0xFFF8FAFC);
    final titleColor = const Color(0xFF1A2430);
    final pointsColor = const Color(0xFF5E6A7A);
    final rankBg = highlighted
        ? const Color(0xFFE14A52)
        : const Color(0xFFE7ECF2);
    final rankText = highlighted ? Colors.white : const Color(0xFF657286);

    return SizedBox(
      width: 154,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 82,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF0F3F7), Color(0xFFE7ECF3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: fotoUrl != null && fotoUrl!.isNotEmpty
                          ? Image.network(
                              fotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _fallbackAvatar(),
                            )
                          : _fallbackAvatar(),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: highlighted
                              ? const Color(0xFFE14A52)
                              : Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.emoji_events_rounded,
                          size: 14,
                          color: highlighted
                              ? Colors.white
                              : const Color(0xFF77859A),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: rankBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '#$rank',
                          style: TextStyle(
                            color: rankText,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$gols pts',
                      style: TextStyle(
                        color: pointsColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: highlighted
                            ? const Color(0xFFE14A52)
                            : const Color(0xFFE8EDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        highlighted ? 'MVP' : 'TOP',
                        style: TextStyle(
                          color: highlighted
                              ? Colors.white
                              : const Color(0xFF657286),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PlayerMiniStat(
                        label: 'V',
                        value: vitorias,
                        highlighted: highlighted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _PlayerMiniStat(
                        label: 'D',
                        value: derrotas,
                        highlighted: highlighted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: const Color(0xFFE7ECF3),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: 26,
        color: const Color(0xFF8D9AAF),
      ),
    );
  }
}

class _PlayerMiniStat extends StatelessWidget {
  const _PlayerMiniStat({
    required this.label,
    required this.value,
    required this.highlighted,
  });

  final String label;
  final int value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final bgColor = highlighted ? const Color(0x14E14A52) : Colors.white;
    final textColor = highlighted
        ? const Color(0xFFCC3E47)
        : const Color(0xFF5C6878);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              color: textColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActiveLeagueCard extends StatelessWidget {
  const _TopActiveLeagueCard({
    required this.nome,
    required this.iconUrl,
    required this.instagramUrl,
    required this.partidasRecentes,
    required this.rodadasRecentes,
    required this.rank,
    required this.featured,
    this.onTap,
    this.onInstagramTap,
  });

  final String nome;
  final String? iconUrl;
  final String? instagramUrl;
  final int partidasRecentes;
  final int rodadasRecentes;
  final int rank;
  final bool featured;
  final VoidCallback? onTap;
  final VoidCallback? onInstagramTap;

  @override
  Widget build(BuildContext context) {
    final hasInstagram = (instagramUrl ?? '').trim().isNotEmpty;
    final cardWidth = featured ? 132.0 : 124.0;

    return SizedBox(
      width: cardWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: featured ? const Color(0xFF79C788) : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: featured
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x30FFFFFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '#1',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : const SizedBox(height: 17),
                ),
                Container(
                  width: 50,
                  height: 50,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: featured
                        ? const Color(0x30FFFFFF)
                        : AppTheme.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: iconUrl != null
                      ? Image.network(
                          iconUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.sports_soccer_rounded,
                            color: featured
                                ? Colors.white
                                : const Color(0xFF8EA0B7),
                            size: 24,
                          ),
                        )
                      : Icon(
                          Icons.sports_soccer_rounded,
                          color: featured
                              ? Colors.white
                              : const Color(0xFF8EA0B7),
                          size: 24,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: featured ? Colors.white : AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 11,
                      color: featured
                          ? const Color(0xFFEAF6ED)
                          : const Color(0xFF8F9BAD),
                    ),
                    Text(
                      '$rodadasRecentes',
                      style: TextStyle(
                        color: featured
                            ? const Color(0xFFEAF6ED)
                            : const Color(0xFF8F9BAD),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.sports_soccer_rounded,
                      size: 11,
                      color: featured
                          ? const Color(0xFFEAF6ED)
                          : const Color(0xFF8F9BAD),
                    ),
                    Text(
                      '$partidasRecentes',
                      style: TextStyle(
                        color: featured
                            ? const Color(0xFFEAF6ED)
                            : const Color(0xFF8F9BAD),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: FilledButton.icon(
                    onPressed: hasInstagram ? onInstagramTap : null,
                    style: FilledButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: featured
                          ? const Color(0xFF4FA15E)
                          : const Color(0xFFE3F0D5),
                      disabledBackgroundColor: const Color(0xFFE8EDF3),
                      foregroundColor: featured
                          ? Colors.white
                          : const Color(0xFF6B8C4E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                    icon: Icon(
                      hasInstagram
                          ? Icons.open_in_new_rounded
                          : Icons.link_off_rounded,
                      size: 14,
                    ),
                    label: const Text('Instagram'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingMatchCard extends StatelessWidget {
  const _UpcomingMatchCard({
    required this.partida,
    required this.config,
    this.onTap,
  });

  final Partida partida;
  final AppConfig config;
  final VoidCallback? onTap;

  Color _teamColor(String? raw) {
    final value = (raw ?? '').trim();
    if (value.startsWith('#') && value.length == 7) {
      final parsed = int.tryParse(value.substring(1), radix: 16);
      if (parsed != null) {
        return Color(0xFF000000 | parsed);
      }
    }
    return AppTheme.primary;
  }

  String? _resolveTeamImageUrl({required bool home}) {
    final team = home ? partida.timeCasa : partida.timeFora;
    final teamImage = config.resolveApiImageUrl(team?.escudoUrl);
    if (teamImage != null && teamImage.isNotEmpty) {
      return teamImage;
    }
    final destaqueImage = config.resolveApiImageUrl(team?.imagemDestaqueUrl);
    if (destaqueImage != null && destaqueImage.isNotEmpty) {
      return destaqueImage;
    }

    final teamId = home ? partida.timeCasaId : partida.timeForaId;
    for (final gol in partida.gols) {
      if (gol.timeId != teamId) continue;
      final jogadorFoto = config.resolveApiImageUrl(gol.jogadorFotoUrl);
      if (jogadorFoto != null && jogadorFoto.isNotEmpty) {
        return jogadorFoto;
      }
      final assistenciaFoto = config.resolveApiImageUrl(gol.assistenciaFotoUrl);
      if (assistenciaFoto != null && assistenciaFoto.isNotEmpty) {
        return assistenciaFoto;
      }
    }

    return null;
  }

  Widget _teamTile({
    required String name,
    required Color color,
    required String? imageUrl,
  }) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl != null
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.shield_rounded, color: color, size: 22),
                )
              : Icon(Icons.shield_rounded, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeName = partida.timeCasa?.nome ?? 'Time casa';
    final awayName = partida.timeFora?.nome ?? 'Time fora';
    final homeColor = _teamColor(partida.timeCasa?.cor);
    final awayColor = _teamColor(partida.timeFora?.cor);
    final homeImage = _resolveTeamImageUrl(home: true);
    final awayImage = _resolveTeamImageUrl(home: false);
    final isLive = partida.status == 'em_andamento';
    final isEnded = partida.status == 'finalizada';
    final statusLabel = isLive
        ? 'Ao vivo'
        : isEnded
        ? 'Finalizada'
        : 'Agendada';
    final statusColor = isLive
        ? const Color(0xFF18C76F)
        : isEnded
        ? const Color(0xFFE14A52)
        : const Color(0xFF3B82F6);

    return SizedBox(
      width: 272,
      child: CyberCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _teamTile(
                    name: homeName,
                    color: homeColor,
                    imageUrl: homeImage,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Text(
                        '${partida.scoreCasa} - ${partida.scoreFora}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 30,
                        height: 3,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _teamTile(
                    name: awayName,
                    color: awayColor,
                    imageUrl: awayImage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTopPlayerEntry {
  _HomeTopPlayerEntry({
    required this.jogadorId,
    required this.nome,
    required this.fotoUrl,
    required this.gols,
    required this.vitorias,
    required this.derrotas,
  });

  final int jogadorId;
  final String nome;
  final String? fotoUrl;
  final int gols;
  int vitorias;
  int derrotas;
}

class _HomeTopPlayerAccumulator {
  _HomeTopPlayerAccumulator({
    required this.jogadorId,
    required this.nome,
    required this.fotoUrl,
    required this.gols,
  });

  final int jogadorId;
  final String nome;
  String? fotoUrl;
  int gols;
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, required this.height, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6EBF1),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _PeladaPillsSkeleton extends StatelessWidget {
  const _PeladaPillsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, _) => const SizedBox(
          width: 72,
          child: Column(
            children: [
              _SkeletonBox(width: 46, height: 46, radius: 23),
              SizedBox(height: 6),
              _SkeletonBox(width: 56, height: 10, radius: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopPeladasSkeletonList extends StatelessWidget {
  const _TopPeladasSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, index) {
        return Container(
          width: index == 0 ? 132 : 124,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: index == 0
                ? const Color(0xFFD9EDE0)
                : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: _SkeletonBox(width: 28, height: 16, radius: 10),
              ),
              SizedBox(height: 8),
              _SkeletonBox(width: 50, height: 50, radius: 25),
              SizedBox(height: 8),
              _SkeletonBox(width: 78, height: 12, radius: 6),
              SizedBox(height: 8),
              _SkeletonBox(width: 90, height: 10, radius: 6),
              Spacer(),
              _SkeletonBox(width: double.infinity, height: 30, radius: 999),
            ],
          ),
        );
      },
    );
  }
}

class _TopPlayersSkeletonList extends StatelessWidget {
  const _TopPlayersSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, index) => Container(
        width: 154,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(width: double.infinity, height: 82, radius: 12),
            SizedBox(height: 8),
            _SkeletonBox(width: 98, height: 12, radius: 6),
            SizedBox(height: 8),
            _SkeletonBox(width: 76, height: 10, radius: 6),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _SkeletonBox(height: 20, radius: 8)),
                SizedBox(width: 6),
                Expanded(child: _SkeletonBox(height: 20, radius: 8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UltimosJogosSkeletonList extends StatelessWidget {
  const _UltimosJogosSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, index) => Container(
        width: 272,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceBorderSoft),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _SkeletonBox(width: 74, height: 18, radius: 10),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _SkeletonBox(width: 46, height: 46, radius: 14),
                      SizedBox(height: 6),
                      _SkeletonBox(width: 78, height: 10, radius: 6),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                _SkeletonBox(width: 56, height: 24, radius: 8),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _SkeletonBox(width: 46, height: 46, radius: 14),
                      SizedBox(height: 6),
                      _SkeletonBox(width: 78, height: 10, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
