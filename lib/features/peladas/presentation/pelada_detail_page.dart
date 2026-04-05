import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/network/api_exception.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_action_card.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_badge.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_header.dart';
import 'package:frontcopa_flutter/core/widgets/section_label.dart';
import 'package:frontcopa_flutter/domain/models/pelada.dart';
import 'package:frontcopa_flutter/features/auth/state/auth_controller.dart';
import 'package:frontcopa_flutter/features/peladas/data/peladas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/seguidores/data/seguidores_remote_data_source.dart';
import 'package:go_router/go_router.dart';

class PeladaDetailPage extends StatefulWidget {
  const PeladaDetailPage({
    super.key,
    required this.peladaId,
    required this.dataSource,
    required this.seguidoresDataSource,
    required this.authController,
    required this.config,
  });

  final int peladaId;
  final PeladasRemoteDataSource dataSource;
  final SeguidoresRemoteDataSource seguidoresDataSource;
  final AuthController authController;
  final AppConfig config;

  @override
  State<PeladaDetailPage> createState() => _PeladaDetailPageState();
}

class _PeladaDetailPageState extends State<PeladaDetailPage> {
  Pelada? _pelada;
  bool? _segue;
  int? _temporadaAtivaId;
  bool _followLoading = false;
  bool _loading = true;
  String? _error;
  bool get _isSeguidor => widget.authController.isSeguidor;

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
      final pelada = await widget.dataSource.getPelada(widget.peladaId);
      if (!mounted) return;
      setState(() => _pelada = pelada);
      await _loadProfileContext();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (_isSeguidor && error.statusCode == 403) {
        try {
          final profile = await widget.dataSource.getPeladaProfile(
            widget.peladaId,
          );
          if (!mounted) return;
          setState(() {
            _pelada = profile.pelada;
            _temporadaAtivaId = profile.temporadaAtiva?.id;
          });
        } catch (_) {
          setState(() => _error = error.message);
        }
      } else {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (_isSeguidor) {
        await _loadFollowStatus();
      }
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadProfileContext() async {
    try {
      final profile = await widget.dataSource.getPeladaProfile(widget.peladaId);
      if (!mounted) return;
      setState(() => _temporadaAtivaId = profile.temporadaAtiva?.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _temporadaAtivaId = null);
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

  Future<void> _toggleFollow() async {
    if (_followLoading) return;

    setState(() => _followLoading = true);
    try {
      if (_segue == true) {
        await widget.seguidoresDataSource.deixarDeSeguirPelada(widget.peladaId);
        if (!mounted) return;
        setState(() => _segue = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voce deixou de seguir esta pelada.')),
        );
      } else {
        await widget.seguidoresDataSource.seguirPelada(widget.peladaId);
        if (!mounted) return;
        setState(() => _segue = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pelada seguida com sucesso.')),
        );
        await _load();
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

  void _openRankingMenu() {
    final temporadaId = _temporadaAtivaId;
    if (temporadaId != null && temporadaId > 0) {
      context.push(
        '/peladas/${widget.peladaId}/temporadas/$temporadaId/rankings',
      );
      return;
    }
    context.push('/peladas/${widget.peladaId}/publico');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Abrimos o perfil publico porque nao ha temporada ativa.',
        ),
      ),
    );
  }

  void _openPlayerStatsMenu() {
    if (_isSeguidor) {
      context.push('/peladas/${widget.peladaId}/publico');
      return;
    }
    context.push('/peladas/${widget.peladaId}/jogadores');
  }

  @override
  Widget build(BuildContext context) {
    final isSeguidor = _isSeguidor;
    final logoUrl = widget.config.resolveApiImageUrl(_pelada?.logoUrl);
    final coverUrl = widget.config.resolveApiImageUrl(_pelada?.perfilUrl);

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Pelada'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  CyberHeader(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              child: coverUrl != null
                                  ? Image.network(
                                      coverUrl,
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 140,
                                      width: double.infinity,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF27161A),
                                            Color(0xFF0B0F0C),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.sports_soccer_rounded,
                                        color: AppTheme.primary,
                                        size: 48,
                                      ),
                                    ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: isSeguidor
                                  ? const SizedBox.shrink()
                                  : InkResponse(
                                      onTap: _pelada == null
                                          ? null
                                          : () => context.push(
                                              '/peladas/${widget.peladaId}/edit',
                                            ),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0x66121815),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.transparent,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF17151C),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.transparent),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: logoUrl != null
                                      ? Image.network(
                                          logoUrl,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Icons.shield_rounded,
                                          color: AppTheme.primary,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (_pelada?.nome ?? '').toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        CyberBadge(
                                          label: _pelada?.ativa == true
                                              ? 'Ativa'
                                              : 'Inativa',
                                          variant: _pelada?.ativa == true
                                              ? CyberBadgeVariant.active
                                              : CyberBadgeVariant.ended,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.place_rounded,
                                          size: 14,
                                          color: AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _pelada?.cidade ?? '-',
                                            style: const TextStyle(
                                              color: AppTheme.textSoft,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _pelada?.fusoHorario ?? '-',
                                          style: const TextStyle(
                                            color: AppTheme.textSoft,
                                            fontSize: 12,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionLabel(label: isSeguidor ? 'Acompanhar' : 'Manage'),
                  const SizedBox(height: 12),
                  if (isSeguidor) ...[
                    CyberActionCard(
                      icon: _segue == true
                          ? Icons.notifications_off_rounded
                          : Icons.notifications_active_rounded,
                      title: _followLoading
                          ? 'Atualizando...'
                          : (_segue == true
                                ? 'Deixar de seguir'
                                : 'Seguir pelada'),
                      subtitle:
                          'Ative ou desative o acompanhamento desta pelada',
                      onTap: _followLoading ? null : _toggleFollow,
                    ),
                  ] else ...[
                    CyberActionCard(
                      icon: Icons.emoji_events_rounded,
                      title: 'Temporadas',
                      subtitle: 'Gerencie rodadas e partidas',
                      onTap: () => context.push(
                        '/peladas/${widget.peladaId}/temporadas',
                      ),
                    ),
                    const SizedBox(height: 10),
                    CyberActionCard(
                      icon: Icons.group,
                      title: 'Jogadores',
                      subtitle: 'Cadastro e estatisticas',
                      onTap: () =>
                          context.push('/peladas/${widget.peladaId}/jogadores'),
                    ),
                    const SizedBox(height: 10),
                    CyberActionCard(
                      icon: Icons.compare_arrows_rounded,
                      title: 'Comparativo',
                      subtitle: 'Duelo moderno entre jogadores',
                      onTap: () => context.push(
                        '/peladas/${widget.peladaId}/comparativo',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const SectionLabel(label: 'Analise'),
                  const SizedBox(height: 12),
                  CyberActionCard(
                    icon: Icons.emoji_events_rounded,
                    title: 'Ranking da pelada',
                    subtitle: 'Times, artilheiros e assistencias',
                    onTap: _openRankingMenu,
                  ),
                  const SizedBox(height: 10),
                  CyberActionCard(
                    icon: Icons.query_stats_rounded,
                    title: 'Estatisticas por jogador',
                    subtitle: _isSeguidor
                        ? 'Veja desempenho individual no perfil publico'
                        : 'Acesse numeros e desempenho dos atletas',
                    onTap: _openPlayerStatsMenu,
                  ),
                  const SizedBox(height: 10),
                  CyberActionCard(
                    icon: Icons.public_rounded,
                    title: 'Perfil Publico',
                    subtitle: 'Visualizacao externa da pelada',
                    onTap: () =>
                        context.push('/peladas/${widget.peladaId}/publico'),
                  ),
                ],
              ),
            ),
    );
  }
}
