import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_action_card.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_header.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_stat_card.dart';
import 'package:frontcopa_flutter/core/widgets/section_label.dart';
import 'package:frontcopa_flutter/domain/models/temporada.dart';
import 'package:frontcopa_flutter/features/rodadas/data/rodadas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/temporadas/data/temporadas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/times/data/times_remote_data_source.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TemporadaDashboardPage extends StatefulWidget {
  const TemporadaDashboardPage({
    super.key,
    required this.peladaId,
    required this.temporadaId,
    required this.temporadasDataSource,
    required this.rodadasDataSource,
    required this.timesDataSource,
  });

  final int peladaId;
  final int temporadaId;
  final TemporadasRemoteDataSource temporadasDataSource;
  final RodadasRemoteDataSource rodadasDataSource;
  final TimesRemoteDataSource timesDataSource;

  @override
  State<TemporadaDashboardPage> createState() => _TemporadaDashboardPageState();
}

class _TemporadaDashboardPageState extends State<TemporadaDashboardPage> {
  Temporada? _temporada;
  int? _numeroTemporada;
  int _rodadasCount = 0;
  int _timesCount = 0;
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
      _numeroTemporada = null;
    });

    try {
      final temporada = await widget.temporadasDataSource.getTemporada(
        widget.temporadaId,
        peladaId: widget.peladaId,
      );
      final results = await Future.wait([
        widget.rodadasDataSource.listRodadas(
          temporadaId: widget.temporadaId,
          page: 1,
          perPage: 200,
        ),
        widget.timesDataSource.listTimes(
          temporadaId: widget.temporadaId,
          page: 1,
          perPage: 200,
        ),
        widget.temporadasDataSource.listTemporadas(
          peladaId: widget.peladaId,
          page: 1,
          perPage: 100,
        ),
      ]);

      final temporadasResponse = results[2] as dynamic;
      final temporadas = List<Temporada>.from(temporadasResponse.items as List);
      final numeroTemporada = _resolveNumeroTemporada(
        temporadas,
        widget.temporadaId,
      );

      if (!mounted) return;
      setState(() {
        _temporada = temporada;
        _numeroTemporada = numeroTemporada;
        _rodadasCount = (results[0] as dynamic).items.length as int;
        _timesCount = (results[1] as List).length;
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

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  DateTime? _parseTemporadaInicio(Temporada temporada) {
    final raw = temporada.inicioMes ?? temporada.inicio;
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int _compareTemporadas(Temporada a, Temporada b) {
    final inicioA = _parseTemporadaInicio(a);
    final inicioB = _parseTemporadaInicio(b);

    if (inicioA != null && inicioB != null) {
      final byInicio = inicioA.compareTo(inicioB);
      if (byInicio != 0) return byInicio;
    } else if (inicioA != null) {
      return -1;
    } else if (inicioB != null) {
      return 1;
    }

    return a.id.compareTo(b.id);
  }

  int _resolveNumeroTemporada(List<Temporada> temporadas, int temporadaId) {
    if (temporadas.isEmpty) return temporadaId;
    final ordenadas = List<Temporada>.from(temporadas)
      ..sort(_compareTemporadas);
    for (var i = 0; i < ordenadas.length; i++) {
      if (ordenadas[i].id == temporadaId) return i + 1;
    }
    return temporadaId;
  }

  Widget _statusChip(String? status) {
    final normalized = (status ?? '').toLowerCase().trim();
    final isActive = normalized == 'ativa' || normalized == 'ativo';
    final label = normalized.isEmpty
        ? 'Indefinido'
        : normalized[0].toUpperCase() + normalized.substring(1);
    final color = isActive ? const Color(0xFFFF3B4D) : const Color(0xFFF5C451);
    final background = color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.transparent),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return CyberActionCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      glow: false,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final temporada = _temporada;
    final inicio = _formatDate(temporada?.inicioMes ?? temporada?.inicio);
    final fim = _formatDate(temporada?.fimMes ?? temporada?.fim);

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Temporada'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                children: [
                  CyberHeader(
                    glow: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Temporada ${_numeroTemporada ?? widget.temporadaId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_month_rounded,
                                          size: 16,
                                          color: AppTheme.textSoft,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$inicio - $fim',
                                          style: const TextStyle(
                                            color: AppTheme.textSoft,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              _statusChip(temporada?.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: CyberStatCard(
                          label: 'Rodadas',
                          value: '$_rodadasCount',
                          glow: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CyberStatCard(
                          label: 'Times',
                          value: '$_timesCount',
                          highlight: true,
                          glow: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionLabel(label: 'Gerenciar'),
                  const SizedBox(height: 16),
                  _menuCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Rodadas',
                    subtitle: 'Criação e gestão das rodadas da temporada',
                    onTap: () => context.push(
                      '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}/rodadas',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _menuCard(
                    icon: Icons.groups_rounded,
                    title: 'Times',
                    subtitle: 'Elencos e estrutura dos times',
                    onTap: () => context.push(
                      '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}/times',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _menuCard(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Transferências',
                    subtitle: 'Troca de jogadores entre os times',
                    onTap: () => context.push(
                      '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}/transferencias',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _menuCard(
                    icon: Icons.emoji_events_rounded,
                    title: 'Rankings',
                    subtitle: 'Tabela, artilheiros e assistências',
                    onTap: () => context.push(
                      '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}/rankings',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _menuCard(
                    icon: Icons.query_stats_rounded,
                    title: 'Estatísticas',
                    subtitle: 'Resumo geral e destaques da temporada',
                    onTap: () => context.push(
                      '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}/estatisticas',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
