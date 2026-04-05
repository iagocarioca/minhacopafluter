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
  final TextEditingController _seguidorSearchController =
      TextEditingController();

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
    _seguidorSearchController.dispose();
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

  void _goToPeladasSearch([String? value]) {
    final raw = (value ?? _seguidorSearchController.text).trim();
    if (raw.isEmpty) {
      context.go('/peladas');
      return;
    }
    final encoded = Uri.encodeQueryComponent(raw);
    context.go('/peladas?q=$encoded');
  }

  List<String> get _homeSearchSuggestions {
    final suggestions = <String>[];
    final seen = <String>{};
    void collect(String? value) {
      final parsed = (value ?? '').trim();
      if (parsed.isEmpty) return;
      final key = parsed.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      suggestions.add(parsed);
    }

    for (final item in _topPeladasAtivas) {
      collect(item.nome);
      if (suggestions.length >= 4) break;
    }
    if (suggestions.length < 4) {
      for (final item in _peladas) {
        collect(item.nome);
        if (suggestions.length >= 4) break;
      }
    }
    return suggestions;
  }

  void _useHomeSuggestion(String value) {
    _seguidorSearchController.text = value;
    _goToPeladasSearch(value);
  }

  @override
  Widget build(BuildContext context) {
    final isSeguidor = widget.authController.isSeguidor;
    final username = widget.authController.currentUser?.username ?? 'Jogador';
    final canOpenRanking = _peladaId != null && _temporadaId != null;
    final selectedPeladaId = _selectedPeladaId ?? _peladaId;
    String? selectedPeladaName;
    for (final pelada in _peladas) {
      if (pelada.id == selectedPeladaId) {
        selectedPeladaName = pelada.nome;
        break;
      }
    }
    final hasFollowedPeladas = _peladas.isNotEmpty;
    final followerHeaderLabel = isSeguidor && !hasFollowedPeladas
        ? 'Descubra sua primeira pelada'
        : (selectedPeladaName ?? 'Selecione uma pelada abaixo');
    final followerHeaderCount = isSeguidor
        ? '${_peladas.length} seguindo'
        : '${_peladas.length} peladas';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: Color(0xFF0F5C57),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0x24FFFFFF), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.white24,
                                child: Text(
                                  username.isNotEmpty
                                      ? username.substring(0, 1).toUpperCase()
                                      : 'M',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Painel da pelada',
                                      style: TextStyle(
                                        color: Color(0xD9FFFFFF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'Ola, $username',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _HeaderAction(
                                icon: Icons.search_rounded,
                                onTap: isSeguidor
                                    ? () => context.go('/peladas')
                                    : null,
                              ),
                              const SizedBox(width: 4),
                              _HeaderAction(
                                icon: Icons.refresh_rounded,
                                onTap: _loading ? null : _load,
                              ),
                              const SizedBox(width: 4),
                              _HeaderAction(
                                icon: Icons.logout_rounded,
                                onTap: () => widget.authController.logout(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.sports_soccer_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    followerHeaderLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  followerHeaderCount,
                                  style: const TextStyle(
                                    color: Color(0xE6FFFFFF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isSeguidor) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.34),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.22),
                                    Colors.white.withValues(alpha: 0.1),
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color.fromRGBO(9, 37, 28, 0.22),
                                    blurRadius: 14,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.24,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.radar_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Radar de peladas',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${_homeSearchSuggestions.length} dicas',
                                        style: const TextStyle(
                                          color: Color(0xFFF2FFF9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Busque e siga uma pelada para liberar feed, ranking e historico.',
                                    style: TextStyle(
                                      color: Color(0xE6FFFFFF),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _seguidorSearchController,
                                          onSubmitted: _goToPeladasSearch,
                                          textInputAction:
                                              TextInputAction.search,
                                          style: const TextStyle(
                                            color: Color(0xFF0F3F3C),
                                            fontWeight: FontWeight.w700,
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                'Buscar pelada para seguir',
                                            hintStyle: const TextStyle(
                                              color: Color(0xFF6E8882),
                                              fontSize: 13,
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.search_rounded,
                                              color: AppTheme.accent,
                                              size: 18,
                                            ),
                                            filled: true,
                                            fillColor: const Color(0xF2FFFFFF),
                                            isDense: true,
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Color(0x66B7D1C7),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: AppTheme.accent,
                                                width: 1.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 42,
                                        child: FilledButton(
                                          onPressed: () => _goToPeladasSearch(),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF0F5C57,
                                            ),
                                            foregroundColor: Colors.white,
                                            minimumSize: Size.zero,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                          ),
                                          child: const Text(
                                            'Buscar',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_homeSearchSuggestions.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: _homeSearchSuggestions.map((
                                        suggestion,
                                      ) {
                                        return ActionChip(
                                          onPressed: () =>
                                              _useHomeSuggestion(suggestion),
                                          backgroundColor: const Color(
                                            0xFFE8F3EE,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xA6B8D4C8),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          label: Text(
                                            suggestion,
                                            style: const TextStyle(
                                              color: AppTheme.accent,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (_loading)
                            const _PeladaPillsSkeleton()
                          else if (_peladas.isEmpty)
                            SizedBox(
                              height: 104,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isSeguidor
                                          ? 'Voce ainda nao segue nenhuma pelada'
                                          : 'Nenhuma pelada encontrada',
                                      style: const TextStyle(
                                        color: Color(0xE6FFFFFF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 36,
                                      child: FilledButton.icon(
                                        onPressed: () => isSeguidor
                                            ? context.go('/peladas')
                                            : context.push('/peladas/new'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppTheme.primary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          textStyle: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        icon: Icon(
                                          isSeguidor
                                              ? Icons.search_rounded
                                              : Icons.add_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          isSeguidor
                                              ? 'Buscar peladas'
                                              : 'Criar nova liga',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 72,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _peladas.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final pelada = _peladas[index];
                                  return _PeladaPill(
                                    name: pelada.nome,
                                    imageUrl: widget.config.resolveApiImageUrl(
                                      pelada.logoUrl,
                                    ),
                                    selected:
                                        pelada.id ==
                                        (_selectedPeladaId ?? _peladaId),
                                    onTap: _loading
                                        ? null
                                        : () => _selectPelada(pelada),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isSeguidor) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _HomeQuickStatCard(
                            label: 'Peladas',
                            value: '${_topPeladasAtivas.length}',
                            icon: Icons.workspace_premium_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HomeQuickStatCard(
                            label: 'MVPs',
                            value: '${_topPlayers.length}',
                            icon: Icons.emoji_events_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _HomeQuickStatCard(
                            label: 'Jogos',
                            value: '${_recentMatches.length}',
                            icon: Icons.sports_soccer_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 6),
                  _SectionHeader(
                    title: 'Melhores Peladas',
                    actionLabel: 'Atualizar',
                    onAction: _loading ? null : _load,
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const _TopPeladasSkeletonGrid()
                  else if (_topPeladasAtivas.isEmpty)
                    const CyberCard(
                      child: Text('Nenhuma pelada ativa encontrada no feed.'),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _topPeladasAtivas.length.clamp(0, 6),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.95,
                          ),
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
                      height: 214,
                      child: _TopPlayersSkeletonList(),
                    )
                  else if (_topPlayers.isEmpty)
                    const CyberCard(
                      child: Text('Nenhum jogador ranqueado ainda.'),
                    )
                  else
                    SizedBox(
                      height: 214,
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
                    ),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'Ultimos jogos',
                    actionLabel: 'Ver todos',
                    onAction: () => context.go('/peladas'),
                  ),
                  const SizedBox(height: 10),
                  if (_loading) const _UltimosJogosSkeletonList(),
                  if (_error != null && !_loading)
                    CyberCard(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFDA3F4D)),
                      ),
                    ),
                  if (!_loading && _error == null && _recentMatches.isEmpty)
                    const CyberCard(
                      child: Text('Nenhuma partida recente disponivel.'),
                    ),
                  if (!_loading && _error == null && _recentMatches.isNotEmpty)
                    Column(
                      children: _recentMatches.map((partida) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _UpcomingMatchCard(
                            partida: partida,
                            config: widget.config,
                            onTap: _peladaId == null
                                ? null
                                : () => context.go(
                                    '/peladas/$_peladaId/partidas/${partida.id}',
                                  ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeQuickStatCard extends StatelessWidget {
  const _HomeQuickStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
        ],
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
    final labelColor = selected ? Colors.white : const Color(0xE6FFFFFF);

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
                color: selected
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.15),
                  width: selected ? 1.8 : 1.0,
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
      color: const Color(0x66000000),
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
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
    final palette = _paletteForRank(rank);

    return SizedBox(
      width: 168,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 206,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: palette.gradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: _backgroundLayer(palette)),
                Positioned(
                  top: 8,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      _metaChip('#$rank'),
                      const Spacer(),
                      _metaChip(highlighted ? 'MVP' : 'TOP'),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 114,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _statTile(value: '$vitorias', label: 'vit'),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _statTile(value: '$gols', label: 'gol'),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _statTile(value: '$derrotas', label: 'der'),
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
      ),
    );
  }

  Widget _backgroundLayer(_MvpCardPalette palette) {
    final hasImage = fotoUrl != null && fotoUrl!.trim().isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.22),
              BlendMode.darken,
            ),
            child: Image.network(
              fotoUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) => _fallbackAvatar(),
            ),
          )
        else
          _fallbackAvatar(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.45),
              radius: 0.9,
              stops: const [0.0, 0.58, 1.0],
              colors: [
                palette.pattern.withValues(alpha: 0.46),
                Colors.black.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.45),
              radius: 0.96,
              stops: const [0.0, 0.5, 1.0],
              colors: [
                Colors.black.withValues(alpha: 0.38),
                Colors.black.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 9.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statTile({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1.5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 8.2,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: Colors.black.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: 42,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }

  _MvpCardPalette _paletteForRank(int rank) {
    if (rank == 1) {
      return const _MvpCardPalette(
        gradient: <Color>[
          Color(0xFFA20C46),
          Color(0xFFD70B22),
          Color(0xFF5A1FB3),
        ],
        pattern: Color(0xFFFF9A4F),
      );
    }
    if (rank == 2) {
      return const _MvpCardPalette(
        gradient: <Color>[
          Color(0xFF0F3EA2),
          Color(0xFF2358CC),
          Color(0xFF232F84),
        ],
        pattern: Color(0xFF78A6FF),
      );
    }
    return const _MvpCardPalette(
      gradient: <Color>[
        Color(0xFF7F142E),
        Color(0xFFB91232),
        Color(0xFF4D1A67),
      ],
      pattern: Color(0xFFFF6B84),
    );
  }
}

class _MvpCardPalette {
  const _MvpCardPalette({required this.gradient, required this.pattern});

  final List<Color> gradient;
  final Color pattern;
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
    final cardColor = featured ? const Color(0xFFE9F6ED) : AppTheme.surface;
    final badgeColor = featured
        ? const Color(0xFF1E8D53)
        : const Color(0xFF7A8597);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x11000000)),
                    ),
                    child: iconUrl != null
                        ? Image.network(
                            iconUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.sports_soccer_rounded,
                              color: Color(0xFF8EA0B7),
                              size: 22,
                            ),
                          )
                        : const Icon(
                            Icons.sports_soccer_rounded,
                            color: Color(0xFF8EA0B7),
                            size: 22,
                          ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
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
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.sports_soccer_rounded,
                    size: 12,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$partidasRecentes partidas',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(
                    Icons.event_note_rounded,
                    size: 12,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$rodadasRecentes rodadas',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: FilledButton.icon(
                  onPressed: hasInstagram ? onInstagramTap : null,
                  style: FilledButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
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

  Color _statusColor({required bool isLive, required bool isEnded}) {
    if (isLive) return AppTheme.primary;
    if (isEnded) return AppTheme.textMuted;
    return AppTheme.info;
  }

  String _statusLabelShort({required bool isLive, required bool isEnded}) {
    if (isLive) return 'LIVE';
    if (isEnded) return 'FT';
    return 'PRE';
  }

  String _formatMatchDate(String? raw) {
    final parsed = DateTime.tryParse((raw ?? '').trim());
    if (parsed == null) return '--/--';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String? _teamLogo(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return config.resolveApiImageUrl(value);
  }

  Widget _teamRow({
    required String name,
    required int score,
    required String? logoUrl,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: const Color(0x1A116066),
          backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null,
          child: logoUrl == null
              ? const Icon(
                  Icons.shield_rounded,
                  size: 12,
                  color: AppTheme.accent,
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$score',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeName = partida.timeCasa?.nome ?? 'Time casa';
    final awayName = partida.timeFora?.nome ?? 'Time fora';
    final homeLogo = _teamLogo(
      partida.timeCasa?.escudoUrl ?? partida.timeCasa?.imagemDestaqueUrl,
    );
    final awayLogo = _teamLogo(
      partida.timeFora?.escudoUrl ?? partida.timeFora?.imagemDestaqueUrl,
    );
    final isLive = partida.status == 'em_andamento';
    final isEnded = partida.status == 'finalizada';
    final statusColor = _statusColor(isLive: isLive, isEnded: isEnded);
    final statusLabel = _statusLabelShort(isLive: isLive, isEnded: isEnded);
    final matchDate = _formatMatchDate(partida.dataHora);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.surfaceBorderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    matchDate,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _teamRow(
                name: homeName,
                score: partida.scoreCasa,
                logoUrl: homeLogo,
              ),
              const SizedBox(height: 4),
              _teamRow(
                name: awayName,
                score: partida.scoreFora,
                logoUrl: awayLogo,
              ),
            ],
          ),
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

class _TopPeladasSkeletonGrid extends StatelessWidget {
  const _TopPeladasSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (_, index) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SkeletonBox(width: 44, height: 44, radius: 22),
                  Spacer(),
                  _SkeletonBox(width: 28, height: 16, radius: 10),
                ],
              ),
              SizedBox(height: 10),
              _SkeletonBox(width: 92, height: 13, radius: 6),
              SizedBox(height: 8),
              _SkeletonBox(width: 112, height: 10, radius: 6),
              SizedBox(height: 6),
              _SkeletonBox(width: 98, height: 10, radius: 6),
              Spacer(),
              _SkeletonBox(width: double.infinity, height: 32, radius: 999),
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
        width: 170,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(width: double.infinity, height: 90, radius: 12),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _SkeletonBox(height: 20, radius: 8)),
                SizedBox(width: 6),
                Expanded(child: _SkeletonBox(height: 20, radius: 8)),
                SizedBox(width: 6),
                Expanded(child: _SkeletonBox(height: 20, radius: 8)),
              ],
            ),
            SizedBox(height: 8),
            _SkeletonBox(width: 64, height: 10, radius: 6),
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
    return Column(
      children: const [
        _UltimoJogoSkeletonCard(),
        SizedBox(height: 10),
        _UltimoJogoSkeletonCard(),
      ],
    );
  }
}

class _UltimoJogoSkeletonCard extends StatelessWidget {
  const _UltimoJogoSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorderSoft),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonBox(width: 88, height: 18, radius: 10),
              Spacer(),
              _SkeletonBox(width: 72, height: 18, radius: 10),
            ],
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
    );
  }
}
