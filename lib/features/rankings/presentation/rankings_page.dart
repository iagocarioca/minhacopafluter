import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/domain/models/ranking.dart';
import 'package:frontcopa_flutter/features/rankings/data/rankings_remote_data_source.dart';
import 'package:go_router/go_router.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({
    super.key,
    required this.peladaId,
    required this.temporadaId,
    required this.dataSource,
    required this.config,
  });

  final int peladaId;
  final int temporadaId;
  final RankingsRemoteDataSource dataSource;
  final AppConfig config;

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  int _tabIndex = 0;
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([
        widget.dataSource.getRankingTimes(widget.temporadaId),
        widget.dataSource.getRankingArtilheiros(widget.temporadaId),
        widget.dataSource.getRankingAssistencias(widget.temporadaId),
      ]);
      if (!mounted) return;
      setState(() {
        _rankingTimes = results[0] as List<RankingTimeEntry>;
        _artilheiros = results[1] as List<RankingJogadorEntry>;
        _assistencias = results[2] as List<RankingJogadorEntry>;
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

  List<RankingTimeEntry> get _timesOrdenados {
    final items = List<RankingTimeEntry>.from(_rankingTimes);
    items.sort((a, b) {
      final byPontos = b.pontos.compareTo(a.pontos);
      if (byPontos != 0) return byPontos;
      final bySaldo = b.saldoGols.compareTo(a.saldoGols);
      if (bySaldo != 0) return bySaldo;
      final byGols = b.golsFeitos.compareTo(a.golsFeitos);
      if (byGols != 0) return byGols;
      return a.timeNome.toLowerCase().compareTo(b.timeNome.toLowerCase());
    });
    return items;
  }

  Color _parseTeamColor(String? raw, {Color fallback = AppTheme.primary}) {
    final value = (raw ?? '').trim();
    if (value.startsWith('#') && value.length == 7) {
      final parsed = int.tryParse(value.substring(1), radix: 16);
      if (parsed != null) {
        return Color(0xFF000000 | parsed);
      }
    }
    return fallback;
  }

  Widget _buildRankingTimes() {
    if (_rankingTimes.isEmpty) {
      return const _RankingEmpty(
        message: 'Ainda nao ha classificacao de times.',
      );
    }

    final tabela = _timesOrdenados;
    final lider = tabela.first;
    final mediaPontos =
        tabela.fold<int>(0, (sum, item) => sum + item.pontos) / tabela.length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            Expanded(
              child: _HeroMetricCard(
                label: 'Lider',
                value: lider.timeNome,
                helper: '${lider.pontos} pts',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HeroMetricCard(
                label: 'Times',
                value: '${tabela.length}',
                helper: 'na disputa',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HeroMetricCard(
                label: 'Media',
                value: mediaPontos.toStringAsFixed(1),
                helper: 'pts por time',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final statWidth = ((constraints.maxWidth - 178) / 4)
                .clamp(36.0, 54.0)
                .toDouble();
            final compactHeader = statWidth < 44;
            return CyberCard(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Classificacao',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x1A18C76F),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.transparent),
                        ),
                        child: Text(
                          '${tabela.length} times',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Text(
                          'Clube',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      _RankHeaderStat(
                        label: compactHeader ? 'V' : 'Vitoria',
                        width: statWidth,
                      ),
                      _RankHeaderStat(
                        label: compactHeader ? 'E' : 'Empate',
                        width: statWidth,
                      ),
                      _RankHeaderStat(
                        label: compactHeader ? 'D' : 'Derrota',
                        width: statWidth,
                      ),
                      _RankHeaderStat(
                        label: compactHeader ? 'P' : 'Pts',
                        width: statWidth,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(height: 1, color: AppTheme.surfaceBorderSoft),
                  const SizedBox(height: 8),
                  ...tabela.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final posicao = index + 1;
                    final escudoUrl = widget.config.resolveApiImageUrl(
                      item.timeEscudoUrl,
                    );
                    final accent = _parseTeamColor(item.timeCor);
                    final isTop = posicao <= 3;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isTop
                            ? const Color(0x1418C76F)
                            : AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0x2212161F),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.transparent,
                                    ),
                                  ),
                                  child: Text(
                                    '$posicao',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isTop
                                          ? AppTheme.primary
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 2.5,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage: escudoUrl != null
                                      ? NetworkImage(escudoUrl)
                                      : null,
                                  child: escudoUrl == null
                                      ? const Icon(
                                          Icons.shield_rounded,
                                          size: 14,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.timeNome,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _RankStatCell(
                            value: item.vitorias.toString(),
                            width: statWidth,
                          ),
                          _RankStatCell(
                            value: item.empates.toString(),
                            width: statWidth,
                          ),
                          _RankStatCell(
                            value: item.derrotas.toString(),
                            width: statWidth,
                          ),
                          _RankStatCell(
                            value: item.pontos.toString(),
                            width: statWidth,
                            highlight: true,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      _LegendDot(color: AppTheme.primary, label: 'Top 3'),
                      SizedBox(width: 12),
                      _LegendDot(color: Color(0xFF6B7A6E), label: 'Demais'),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRankingJogadores({
    required List<RankingJogadorEntry> data,
    required String titulo,
    required String unidade,
    required IconData icon,
  }) {
    if (data.isEmpty) {
      return const _RankingEmpty(message: 'Sem dados disponiveis ainda.');
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        CyberCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final fotoUrl = widget.config.resolveApiImageUrl(item.jogadorFotoUrl);
          final rank = index + 1;
          final isTop = rank <= 3;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: CyberCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isTop
                          ? const Color(0x1A18C76F)
                          : const Color(0x1F141923),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: isTop ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 17,
                    backgroundImage: fotoUrl != null
                        ? NetworkImage(fotoUrl)
                        : null,
                    child: fotoUrl == null
                        ? const Icon(Icons.person, size: 16)
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
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.timeNome ?? 'Sem time',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1A18C76F),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: Text(
                      '${item.quantidade} $unidade',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        toolbarHeight: 66,
        leading: const AppBackButton(),
        title: const Text('Classificacoes'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => context.push(
              '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}/rankings/anual',
            ),
            tooltip: 'Ranking anual',
            icon: const Icon(Icons.insights_rounded),
          ),
          const SizedBox(width: 8),
        ],
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.transparent),
                      color: AppTheme.surface,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _RankingTabSelector(
                        labels: const [
                          'Classificacao',
                          'Artilheiros',
                          'Assistencias',
                        ],
                        selectedIndex: _tabIndex,
                        onChanged: (index) => setState(() => _tabIndex = index),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: switch (_tabIndex) {
                        0 => _buildRankingTimes(),
                        1 => _buildRankingJogadores(
                          data: _artilheiros,
                          titulo: 'Ranking de artilheiros',
                          unidade: 'gols',
                          icon: Icons.sports_soccer_rounded,
                        ),
                        _ => _buildRankingJogadores(
                          data: _assistencias,
                          titulo: 'Ranking de assistencias',
                          unidade: 'assist.',
                          icon: Icons.assistant_rounded,
                        ),
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RankingTabSelector extends StatelessWidget {
  const _RankingTabSelector({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = index == selectedIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == labels.length - 1 ? 0 : 4,
              ),
              child: InkWell(
                onTap: () => onChanged(index),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0x1A18C76F)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.transparent),
                  ),
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RankingEmpty extends StatelessWidget {
  const _RankingEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF98A0AF)),
          ),
        ),
      ],
    );
  }
}

class _HeroMetricCard extends StatelessWidget {
  const _HeroMetricCard({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankHeaderStat extends StatelessWidget {
  const _RankHeaderStat({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RankStatCell extends StatelessWidget {
  const _RankStatCell({
    required this.value,
    required this.width,
    this.highlight = false,
  });

  final String value;
  final double width;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: highlight ? AppTheme.primary : AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
