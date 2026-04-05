import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/network/api_exception.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/domain/models/pelada_publica.dart';
import 'package:frontcopa_flutter/domain/models/ranking.dart';
import 'package:frontcopa_flutter/domain/models/seguidor_feed.dart';
import 'package:frontcopa_flutter/features/auth/state/auth_controller.dart';
import 'package:frontcopa_flutter/features/peladas/data/peladas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/rankings/data/rankings_remote_data_source.dart';
import 'package:frontcopa_flutter/features/seguidores/data/seguidores_remote_data_source.dart';

class PeladaPublicaPage extends StatefulWidget {
  const PeladaPublicaPage({
    super.key,
    required this.peladaId,
    required this.config,
    required this.authController,
    required this.seguidoresDataSource,
    required this.peladasDataSource,
    required this.rankingsDataSource,
  });

  final int peladaId;
  final AppConfig config;
  final AuthController authController;
  final SeguidoresRemoteDataSource seguidoresDataSource;
  final PeladasRemoteDataSource peladasDataSource;
  final RankingsRemoteDataSource rankingsDataSource;

  @override
  State<PeladaPublicaPage> createState() => _PeladaPublicaPageState();
}

class _PeladaPublicaPageState extends State<PeladaPublicaPage> {
  static const int _playersBatchSize = 12;
  static const int _seasonsBatchSize = 8;

  PeladaPublicProfile? _profile;

  bool _loading = true;
  bool _loadingRankings = false;
  bool _followLoading = false;
  bool _loadingFeed = false;
  bool? _segue;
  String? _error;
  String? _rankingError;
  String? _feedError;
  int _rankingTabIndex = 0;
  int _publicTabIndex = 0;
  int _visiblePlayers = _playersBatchSize;
  int _visibleSeasons = _seasonsBatchSize;

  List<RankingTimeEntry> _rankingTimes = const <RankingTimeEntry>[];
  List<RankingJogadorEntry> _artilheiros = const <RankingJogadorEntry>[];
  List<RankingJogadorEntry> _assistencias = const <RankingJogadorEntry>[];
  SeguidorPeladaFeed? _followerFeed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _rankingError = null;
      _feedError = null;
    });

    try {
      final profile = await widget.peladasDataSource.getPeladaProfile(
        widget.peladaId,
      );
      if (!mounted) return;

      setState(() {
        _profile = profile;
        _visiblePlayers = _playersBatchSize;
        _visibleSeasons = _seasonsBatchSize;
      });

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

      if (widget.authController.isSeguidor) {
        await _loadFollowStatus();
        if (_segue == true) {
          await _loadFollowerFeed();
        } else {
          _clearFollowerFeed();
        }
      } else {
        _clearFollowerFeed();
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

  Future<void> _loadFollowStatus() async {
    try {
      final status = await widget.seguidoresDataSource.getStatusPelada(
        widget.peladaId,
      );
      if (!mounted) return;
      setState(() => _segue = status.segue);
    } catch (_) {
      if (!mounted) return;
      setState(() => _segue = false);
    }
  }

  void _clearFollowerFeed() {
    if (!mounted) return;
    setState(() {
      _followerFeed = null;
      _feedError = null;
      _loadingFeed = false;
    });
  }

  Future<void> _loadFollowerFeed() async {
    setState(() {
      _loadingFeed = true;
      _feedError = null;
    });
    try {
      final feed = await widget.seguidoresDataSource.getPeladaFeed(
        peladaId: widget.peladaId,
        limitPartidas: 10,
        limitVotacoes: 6,
      );
      if (!mounted) return;
      setState(() {
        _followerFeed = feed;
        _feedError = null;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : error.toString();
      setState(() {
        _followerFeed = null;
        _feedError = message;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingFeed = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_followLoading || !widget.authController.isSeguidor) return;

    setState(() => _followLoading = true);
    try {
      if (_segue == true) {
        await widget.seguidoresDataSource.deixarDeSeguirPelada(widget.peladaId);
        if (!mounted) return;
        setState(() => _segue = false);
        _clearFollowerFeed();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voce deixou de seguir a pelada.')),
        );
      } else {
        await widget.seguidoresDataSource.seguirPelada(widget.peladaId);
        if (!mounted) return;
        setState(() => _segue = true);
        await _loadFollowerFeed();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agora voce segue esta pelada.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : error.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _followLoading = false);
      }
    }
  }

  Future<void> _loadRankings(int temporadaId) async {
    setState(() => _loadingRankings = true);
    try {
      final result = await Future.wait([
        widget.rankingsDataSource.getRankingTimes(
          temporadaId,
          forcePublic: true,
        ),
        widget.rankingsDataSource.getRankingArtilheiros(
          temporadaId,
          forcePublic: true,
        ),
        widget.rankingsDataSource.getRankingAssistencias(
          temporadaId,
          forcePublic: true,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _rankingTimes = result[0] as List<RankingTimeEntry>;
        _artilheiros = result[1] as List<RankingJogadorEntry>;
        _assistencias = result[2] as List<RankingJogadorEntry>;
        _rankingError = null;
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : error.toString();
      setState(() {
        _rankingTimes = const <RankingTimeEntry>[];
        _artilheiros = const <RankingJogadorEntry>[];
        _assistencias = const <RankingJogadorEntry>[];
        _rankingError = message;
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

  String _formatDateTimeShort(String? raw) {
    final parsed = (raw ?? '').trim();
    if (parsed.isEmpty) return '-';
    final dt = DateTime.tryParse(parsed);
    if (dt == null) return parsed;
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month ${hour}h$minute';
  }

  Widget _buildFollowerFeedSection() {
    if (_loadingFeed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_feedError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Feed indisponivel no momento.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loadFollowerFeed,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Tentar de novo'),
          ),
        ],
      );
    }

    final feed = _followerFeed;
    if (feed == null || feed.isEmpty) {
      return const Text(
        'Sem atualizacoes recentes no feed desta pelada.',
        style: TextStyle(
          color: AppTheme.textMuted,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (feed.ultimasPartidas.isNotEmpty) ...[
          const Text(
            'Ultimas partidas',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...feed.ultimasPartidas.take(4).map(_buildFeedMatchTile),
        ],
        if (feed.ultimosGanhadoresVotacao.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text(
            'Ultimos ganhadores de votacao',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _buildFeedWinnersPodium(feed.ultimosGanhadoresVotacao),
        ],
      ],
    );
  }

  Color _feedStatusColor(String? statusRaw) {
    final status = (statusRaw ?? '').trim().toLowerCase();
    if (status.contains('andamento') || status.contains('live')) {
      return AppTheme.primary;
    }
    if (status.contains('final') || status.contains('encerr')) {
      return AppTheme.textMuted;
    }
    return AppTheme.info;
  }

  String _feedStatusLabelShort(String? statusRaw) {
    final status = (statusRaw ?? '').trim().toLowerCase();
    if (status.contains('andamento') || status.contains('live')) return 'LIVE';
    if (status.contains('final') || status.contains('encerr')) return 'FT';
    return 'PRE';
  }

  String _formatMatchDateShort(String? raw) {
    final parsed = DateTime.tryParse((raw ?? '').trim());
    if (parsed == null) return '--/--';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String? _resolveTeamLogo(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return widget.config.resolveApiImageUrl(value);
  }

  Widget _buildFeedTeamRow({
    required String name,
    required String score,
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
          score,
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

  Widget _buildFeedMatchTile(SeguidorUltimaPartida item) {
    final statusColor = _feedStatusColor(item.status);
    final statusLabel = _feedStatusLabelShort(item.status);
    final matchDate = _formatMatchDateShort(item.dataHora);
    final scoreCasa = item.golsCasa?.toString() ?? '-';
    final scoreFora = item.golsFora?.toString() ?? '-';
    final casaLogo = _resolveTeamLogo(item.timeCasaEscudoUrl);
    final foraLogo = _resolveTeamLogo(item.timeForaEscudoUrl);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
            _buildFeedTeamRow(
              name: item.timeCasaNome,
              score: scoreCasa,
              logoUrl: casaLogo,
            ),
            const SizedBox(height: 4),
            _buildFeedTeamRow(
              name: item.timeForaNome,
              score: scoreFora,
              logoUrl: foraLogo,
            ),
          ],
        ),
      ),
    );
  }

  Color _podiumAccent(int rank) {
    return switch (rank) {
      1 => AppTheme.primary,
      2 => AppTheme.accent,
      _ => AppTheme.warning,
    };
  }

  Widget _buildPodiumWinnerSlot(SeguidorUltimoGanhadorVotacao? item, int rank) {
    final accent = _podiumAccent(rank);
    final pedestalHeight = switch (rank) {
      1 => 76.0,
      2 => 60.0,
      _ => 52.0,
    };

    if (item == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(height: 90),
          Container(
            width: double.infinity,
            height: pedestalHeight,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              color: const Color(0x0F116066),
              border: Border.all(color: const Color(0x1F116066)),
            ),
          ),
        ],
      );
    }

    final winnerImageUrl = widget.config.resolveApiImageUrl(
      item.vencedorFotoUrl,
    );
    final winner = item.vencedorNome ?? 'Jogador';
    final label = item.tipoVotacao == null || item.tipoVotacao!.trim().isEmpty
        ? 'Votacao'
        : item.tipoVotacao!;
    final subtitle = _formatDateTimeShort(item.encerradaEm);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (rank == 1) ...[
          Icon(Icons.workspace_premium_rounded, color: accent, size: 20),
          const SizedBox(height: 2),
        ],
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            CircleAvatar(
              radius: rank == 1 ? 32 : 26,
              backgroundColor: accent.withValues(alpha: 0.15),
              backgroundImage: winnerImageUrl != null
                  ? NetworkImage(winnerImageUrl)
                  : null,
              child: winnerImageUrl == null
                  ? Icon(Icons.person_rounded, size: rank == 1 ? 30 : 24)
                  : null,
            ),
            Positioned(
              bottom: -8,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          winner,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: pedestalHeight,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: 0.28),
                accent.withValues(alpha: 0.12),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedWinnersPodium(List<SeguidorUltimoGanhadorVotacao> items) {
    final top3 = items.take(3).toList();
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0ECE6)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF9FDFC), Color(0xFFF1F8F5)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _buildPodiumWinnerSlot(second, 2)),
          const SizedBox(width: 8),
          Expanded(child: _buildPodiumWinnerSlot(first, 1)),
          const SizedBox(width: 8),
          Expanded(child: _buildPodiumWinnerSlot(third, 3)),
        ],
      ),
    );
  }

  Widget _buildRankingTimeRow(
    RankingTimeEntry item,
    int position, {
    bool compact = false,
  }) {
    final image = widget.config.resolveApiImageUrl(item.timeEscudoUrl);
    final pointsColor = position <= 3 ? AppTheme.primary : AppTheme.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1ECE6)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: position <= 3
                  ? const Color(0x2117A76F)
                  : const Color(0x14000000),
            ),
            child: Text(
              '$position',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: pointsColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundImage: image != null ? NetworkImage(image) : null,
            child: image == null
                ? const Icon(Icons.shield_rounded, size: 14)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.timeNome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!compact) ...[
            SizedBox(
              width: 28,
              child: Text(
                '${item.vitorias}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '${item.empates}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '${item.derrotas}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          Container(
            width: 40,
            alignment: Alignment.centerRight,
            child: Text(
              '${item.pontos}',
              style: TextStyle(
                color: pointsColor,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingTab({int limit = 8}) {
    if (_loadingRankings) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_rankingError != null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Ranking indisponivel no momento.',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_rankingTabIndex == 0) {
      if (_rankingTimes.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text('Sem classificacao disponivel.'),
        );
      }

      final tableRows = _rankingTimes.take(limit).toList();
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7F3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0ECE6)),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Clube',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    'V',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    'E',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    'D',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    'P',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...tableRows.asMap().entries.map((entry) {
            return _buildRankingTimeRow(entry.value, entry.key + 1);
          }),
        ],
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
      children: items.take(limit).toList().asMap().entries.map((entry) {
        final position = entry.key + 1;
        final item = entry.value;
        final image = widget.config.resolveApiImageUrl(item.jogadorFotoUrl);
        final isTop = position <= 3;

        return CyberCard(
          margin: const EdgeInsets.only(bottom: 8),
          onTap: () => context.push('/perfil/${item.jogadorId}'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isTop
                      ? const Color(0x2117A76F)
                      : const Color(0x14000000),
                ),
                child: Text(
                  '$position',
                  style: TextStyle(
                    color: isTop ? AppTheme.primary : AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundImage: image != null ? NetworkImage(image) : null,
                child: image == null
                    ? const Icon(Icons.person_rounded, size: 15)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.jogadorNome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.timeNome ?? 'Sem time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x1A17A76F),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${item.quantidade} $unidade',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrimaryTabs() {
    const tabs = <String>['Visao geral', 'Ranking', 'Jogadores', 'Temporadas'];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _publicTabIndex == index;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _publicTabIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0x2117A76F)
                    : const Color(0xFFF1F6F4),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? const Color(0x5517A76F)
                      : const Color(0xFFDCE8E2),
                ),
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  color: selected ? AppTheme.accent : AppTheme.textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(PeladaPublicProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.authController.isSeguidor && _segue == true) ...[
          CyberCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.dynamic_feed_rounded,
                      size: 18,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Feed da pelada seguida',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadingFeed ? null : _loadFollowerFeed,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Atualizar feed',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildFollowerFeedSection(),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.68,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _KpiCard(
              icon: Icons.groups_rounded,
              label: 'Jogadores',
              value:
                  '${profile.estatisticas?.totalJogadores ?? profile.jogadores.length}',
            ),
            _KpiCard(
              icon: Icons.event_note_rounded,
              label: 'Temporadas',
              value:
                  '${profile.estatisticas?.totalTemporadas ?? profile.temporadas.length}',
            ),
            _KpiCard(
              icon: Icons.calendar_view_week_rounded,
              label: 'Rodadas',
              value: '${profile.estatisticas?.rodadasRealizadas ?? 0}',
            ),
            _KpiCard(
              icon: Icons.sports_soccer_rounded,
              label: 'Partidas',
              value: '${profile.estatisticas?.partidasRealizadas ?? 0}',
            ),
          ],
        ),
        if (profile.temporadaAtiva != null) ...[
          const SizedBox(height: 16),
          CyberCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Placar da temporada',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _periodoTemporada(profile.temporadaAtiva),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                if (_loadingRankings)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_rankingTimes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sem classificacao disponivel.'),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7F3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0ECE6)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Clube',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            'P',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._rankingTimes.take(4).toList().asMap().entries.map((
                    entry,
                  ) {
                    return _buildRankingTimeRow(
                      entry.value,
                      entry.key + 1,
                      compact: true,
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRankingSection(PeladaPublicProfile profile) {
    if (profile.temporadaAtiva == null) {
      return const CyberCard(
        child: Text('A pelada ainda nao possui temporada ativa para ranking.'),
      );
    }

    return CyberCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ranking da temporada',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            _periodoTemporada(profile.temporadaAtiva),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('Tabela')),
              ButtonSegment<int>(value: 1, label: Text('Artilharia')),
              ButtonSegment<int>(value: 2, label: Text('Assistencias')),
            ],
            selected: <int>{_rankingTabIndex},
            onSelectionChanged: (selection) {
              setState(() => _rankingTabIndex = selection.first);
            },
          ),
          const SizedBox(height: 10),
          _buildRankingTab(limit: 10),
        ],
      ),
    );
  }

  Widget _buildPlayersSection(PeladaPublicProfile profile) {
    final totalJogadores = profile.jogadores.length;
    final visibleJogadores = _visiblePlayers < totalJogadores
        ? _visiblePlayers
        : totalJogadores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Jogadores',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$totalJogadores total',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (profile.jogadores.isEmpty)
          const CyberCard(child: Text('Nenhum jogador cadastrado.'))
        else
          ...profile.jogadores
              .take(visibleJogadores)
              .toList()
              .asMap()
              .entries
              .map((entry) {
                final index = entry.key;
                final jogador = entry.value;
                final image = widget.config.resolveApiImageUrl(jogador.fotoUrl);
                final badgeColor = jogador.ativo == false
                    ? const Color(0x1FD64C57)
                    : const Color(0x1F17A76F);
                final badgeTextColor = jogador.ativo == false
                    ? const Color(0xFFD64C57)
                    : AppTheme.primary;

                return CyberCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () => context.push('/perfil/${jogador.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: const Color(0x15116066),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0x1A17A76F),
                        backgroundImage: image != null
                            ? NetworkImage(image)
                            : null,
                        child: image == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: AppTheme.accent,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jogador.apelido.isNotEmpty
                                  ? jogador.apelido
                                  : jogador.nomeCompleto,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (jogador.timeNome ?? '').trim().isNotEmpty
                                  ? jogador.timeNome!
                                  : 'Sem time definido',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          jogador.ativo == false ? 'INATIVO' : 'ATIVO',
                          style: TextStyle(
                            color: badgeTextColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
        if (visibleJogadores < totalJogadores) ...[
          const SizedBox(height: 4),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                final next = (_visiblePlayers + _playersBatchSize)
                    .clamp(0, totalJogadores)
                    .toInt();
                setState(() => _visiblePlayers = next);
              },
              icon: const Icon(Icons.expand_more_rounded, size: 16),
              label: Text('Ver mais (${totalJogadores - visibleJogadores})'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSeasonsSection(PeladaPublicProfile profile) {
    final totalTemporadas = profile.temporadas.length;
    final visibleTemporadas = _visibleSeasons < totalTemporadas
        ? _visibleSeasons
        : totalTemporadas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Historico de temporadas',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$totalTemporadas total',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (profile.temporadas.isEmpty)
          const CyberCard(child: Text('Nenhuma temporada encontrada.'))
        else
          ...profile.temporadas.take(visibleTemporadas).map((temporada) {
            final ativa = temporada.status.trim().toLowerCase() == 'ativa';
            return CyberCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ativa
                          ? AppTheme.primary
                          : AppTheme.surfaceBorderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _periodoTemporada(temporada),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ativa ? 'Temporada ativa' : 'Encerrada',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: ativa
                          ? const Color(0x1E17A76F)
                          : const Color(0x1A8A95A5),
                    ),
                    child: Text(
                      ativa ? 'ATIVA' : 'ENCERRADA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: ativa ? AppTheme.primary : AppTheme.textMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        if (visibleTemporadas < totalTemporadas) ...[
          const SizedBox(height: 4),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                final next = (_visibleSeasons + _seasonsBatchSize)
                    .clamp(0, totalTemporadas)
                    .toInt();
                setState(() => _visibleSeasons = next);
              },
              icon: const Icon(Icons.expand_more_rounded, size: 16),
              label: Text('Ver mais (${totalTemporadas - visibleTemporadas})'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabBody(PeladaPublicProfile profile) {
    return switch (_publicTabIndex) {
      0 => _buildOverviewTab(profile),
      1 => _buildRankingSection(profile),
      2 => _buildPlayersSection(profile),
      _ => _buildSeasonsSection(profile),
    };
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
        title: const Text('Liga Publica'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _PublicErrorState(message: _error!, onRetry: _load)
          : (profile == null || pelada == null)
          ? _PublicErrorState(
              message: 'Nao foi possivel carregar o perfil da liga.',
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  CyberCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 186,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (cover != null)
                              Image.network(
                                cover,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) => Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF0F5C57),
                                        Color(0xFF116066),
                                        Color(0xFF17A76F),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF0F5C57),
                                      Color(0xFF116066),
                                      Color(0xFF17A76F),
                                    ],
                                  ),
                                ),
                              ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x2A0D2B26),
                                    Color(0xB3142120),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              top: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  pelada.ativa ? 'Liga ativa' : 'Liga inativa',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Spacer(),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          color: Colors.white.withValues(
                                            alpha: 0.22,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.32,
                                            ),
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: logo != null
                                              ? Image.network(
                                                  logo,
                                                  fit: BoxFit.cover,
                                                  filterQuality:
                                                      FilterQuality.low,
                                                  gaplessPlayback: true,
                                                  errorBuilder: (_, _, _) =>
                                                      const Icon(
                                                        Icons.shield_rounded,
                                                        color: Colors.white,
                                                        size: 28,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.shield_rounded,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pelada.nome,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                if (pelada.cidade.isNotEmpty)
                                                  _HeroTag(
                                                    icon: Icons.place_rounded,
                                                    label: pelada.cidade,
                                                  ),
                                                if ((profile
                                                            .gerente
                                                            ?.username ??
                                                        '')
                                                    .isNotEmpty)
                                                  _HeroTag(
                                                    icon: Icons.person_rounded,
                                                    label:
                                                        'Gerente ${profile.gerente!.username}',
                                                  ),
                                              ],
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
                  ),
                  const SizedBox(height: 14),
                  if (widget.authController.isSeguidor) ...[
                    CyberCard(
                      glow: _segue == true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0x1E17A76F),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _segue == true
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _segue == true
                                      ? 'Voce ja segue esta pelada'
                                      : 'Seguir esta pelada',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _segue == true
                                      ? 'Voce recebera novidades e podera acessar os dados de seguidor.'
                                      : 'Siga para liberar conteudos privados de seguidor.',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 116),
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _followLoading ? null : _toggleFollow,
                              icon: Icon(
                                _segue == true
                                    ? Icons.remove_circle_outline_rounded
                                    : Icons.add_rounded,
                                size: 16,
                              ),
                              label: Text(
                                _followLoading
                                    ? '...'
                                    : (_segue == true ? 'Deixar' : 'Seguir'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _buildPrimaryTabs(),
                  const SizedBox(height: 12),
                  _buildTabBody(profile),
                ],
              ),
            ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicErrorState extends StatelessWidget {
  const _PublicErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: CyberCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFD64C57),
                  size: 30,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
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
          Icon(icon, color: AppTheme.accent, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
