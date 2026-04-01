import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_action_card.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_badge.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_header.dart';
import 'package:frontcopa_flutter/core/widgets/section_label.dart';
import 'package:frontcopa_flutter/domain/models/pelada.dart';
import 'package:frontcopa_flutter/features/peladas/data/peladas_remote_data_source.dart';
import 'package:go_router/go_router.dart';

class PeladaDetailPage extends StatefulWidget {
  const PeladaDetailPage({
    super.key,
    required this.peladaId,
    required this.dataSource,
    required this.config,
  });

  final int peladaId;
  final PeladasRemoteDataSource dataSource;
  final AppConfig config;

  @override
  State<PeladaDetailPage> createState() => _PeladaDetailPageState();
}

class _PeladaDetailPageState extends State<PeladaDetailPage> {
  Pelada? _pelada;
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
      final pelada = await widget.dataSource.getPelada(widget.peladaId);
      if (!mounted) return;
      setState(() => _pelada = pelada);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                              child: InkResponse(
                                onTap: _pelada == null
                                    ? null
                                    : () => context.push(
                                        '/peladas/${widget.peladaId}/edit',
                                      ),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0x66121815),
                                    borderRadius: BorderRadius.circular(10),
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
                  const SectionLabel(label: 'Manage'),
                  const SizedBox(height: 12),
                  CyberActionCard(
                    icon: Icons.emoji_events_rounded,
                    title: 'Temporadas',
                    subtitle: 'Gerencie rodadas e partidas',
                    onTap: () =>
                        context.push('/peladas/${widget.peladaId}/temporadas'),
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
                    onTap: () =>
                        context.push('/peladas/${widget.peladaId}/comparativo'),
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
