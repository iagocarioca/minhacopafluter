import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/domain/models/perfil_publico.dart';
import 'package:frontcopa_flutter/features/perfis/data/perfis_remote_data_source.dart';
import 'package:intl/intl.dart';

class PerfilJogadorPublicoPage extends StatefulWidget {
  const PerfilJogadorPublicoPage({
    super.key,
    required this.jogadorId,
    required this.config,
    required this.perfisDataSource,
  });

  final int jogadorId;
  final AppConfig config;
  final PerfisRemoteDataSource perfisDataSource;

  @override
  State<PerfilJogadorPublicoPage> createState() =>
      _PerfilJogadorPublicoPageState();
}

class _PerfilJogadorPublicoPageState extends State<PerfilJogadorPublicoPage> {
  JogadorPerfilPublico? _perfil;
  JogadorEstatisticasPublicas? _estatisticas;
  List<HistoricoPartidaPublica> _historico = const <HistoricoPartidaPublica>[];

  bool _loading = true;
  String? _error;
  bool _showAllHistorico = false;
  int _tabIndex = 0;

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
        widget.perfisDataSource.getPerfilPublico(widget.jogadorId),
        widget.perfisDataSource.getEstatisticas(widget.jogadorId),
        widget.perfisDataSource.getHistorico(widget.jogadorId),
      ]);
      if (!mounted) return;
      setState(() {
        _perfil = result[0] as JogadorPerfilPublico;
        _estatisticas = result[1] as JogadorEstatisticasPublicas;
        _historico = result[2] as List<HistoricoPartidaPublica>;
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
    return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
  }

  String? _resultadoPartida(HistoricoPartidaPublica partida) {
    final resultadoRaw = partida.resultado?.toLowerCase();
    if (resultadoRaw == 'vitoria' || resultadoRaw == 'vitória')
      return 'vitoria';
    if (resultadoRaw == 'derrota') return 'derrota';

    if ((partida.timeDoJogador ?? '').trim().isEmpty &&
        partida.timeDoJogadorId == null) {
      return null;
    }

    final jogouCasa =
        partida.timeDoJogadorId != null &&
            partida.timeCasaId != null &&
            partida.timeDoJogadorId == partida.timeCasaId ||
        ((partida.timeDoJogador ?? '').trim().isNotEmpty &&
            (partida.timeDoJogador ?? '').trim() ==
                (partida.timeCasa ?? '').trim());

    final jogouFora =
        partida.timeDoJogadorId != null &&
            partida.timeForaId != null &&
            partida.timeDoJogadorId == partida.timeForaId ||
        ((partida.timeDoJogador ?? '').trim().isNotEmpty &&
            (partida.timeDoJogador ?? '').trim() ==
                (partida.timeFora ?? '').trim());

    if (jogouCasa) {
      if (partida.placarCasa > partida.placarFora) return 'vitoria';
      if (partida.placarCasa < partida.placarFora) return 'derrota';
    }
    if (jogouFora) {
      if (partida.placarFora > partida.placarCasa) return 'vitoria';
      if (partida.placarFora < partida.placarCasa) return 'derrota';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil;
    final estatisticas = _estatisticas;
    final image = widget.config.resolveApiImageUrl(perfil?.fotoUrl);
    final historicoVisivel = _showAllHistorico
        ? _historico
        : _historico.take(5).toList();

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Perfil do jogador'),
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
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    padding: const EdgeInsets.all(16),
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      gradient: image == null
                          ? const LinearGradient(
                              colors: [Color(0xFF1A221C), Color(0xFF0F1511)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      image: image != null
                          ? DecorationImage(
                              image: NetworkImage(image),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.black.withValues(alpha: 0.72),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          if ((perfil?.posicao ?? '').isNotEmpty)
                            Text(
                              perfil!.posicao!,
                              style: const TextStyle(
                                color: Color(0xFFE2E7F0),
                                fontSize: 12,
                              ),
                            ),
                          Text(
                            (perfil?.nomeExibicao ?? '').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                          if ((perfil?.nomeCompleto ?? '').isNotEmpty)
                            Text(
                              perfil!.nomeCompleto,
                              style: const TextStyle(
                                color: Color(0xFFE2E7F0),
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if ((perfil?.timeAtual ?? perfil?.timeNome ?? '')
                                  .isNotEmpty)
                                Chip(
                                  label: Text(
                                    perfil?.timeAtual ?? perfil?.timeNome ?? '',
                                  ),
                                ),
                              if ((perfil?.telefone ?? '').isNotEmpty)
                                Chip(label: Text(perfil!.telefone!)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: CyberCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            _StatRow(
                              leftLabel: 'Jogos',
                              leftValue: '${estatisticas?.partidas ?? 0}',
                              centerLabel: 'Gols',
                              centerValue: '${estatisticas?.gols ?? 0}',
                              rightLabel: 'Assist',
                              rightValue: '${estatisticas?.assistencias ?? 0}',
                            ),
                            const SizedBox(height: 14),
                            _StatRow(
                              leftLabel: 'Vitorias',
                              leftValue: '${estatisticas?.vitorias ?? 0}',
                              centerLabel: 'Empates',
                              centerValue: '${estatisticas?.empates ?? 0}',
                              rightLabel: 'Derrotas',
                              rightValue: '${estatisticas?.derrotas ?? 0}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(value: 0, label: Text('Partidas')),
                        ButtonSegment<int>(value: 1, label: Text('Resumo')),
                      ],
                      selected: <int>{_tabIndex},
                      onSelectionChanged: (selection) {
                        setState(() => _tabIndex = selection.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_tabIndex == 1)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: CyberCard(
                        child: Text(
                          'As estatisticas principais estao no card acima. '
                          'Em breve teremos graficos e detalhes por temporada.',
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: _historico.isEmpty
                          ? const CyberCard(
                              child: Text('Nenhuma partida registrada ainda.'),
                            )
                          : Column(
                              children: [
                                ...historicoVisivel.map((partida) {
                                  final resultado = _resultadoPartida(partida);
                                  return CyberCard(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                partida.timeCasa ?? '-',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              child: Text(
                                                '${partida.placarCasa} x ${partida.placarFora}',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                partida.timeFora ?? '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (resultado != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: resultado == 'vitoria'
                                                      ? const Color(0x24FF3B4D)
                                                      : const Color(0x1FFF4D4D),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  resultado == 'vitoria'
                                                      ? 'Vitória'
                                                      : 'Derrota',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        resultado == 'vitoria'
                                                        ? AppTheme.primary
                                                        : const Color(
                                                            0xFFFF4D4D,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatDate(partida.data),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (partida.gols > 0 ||
                                            partida.assistencias > 0) ...[
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              if (partida.gols > 0)
                                                Chip(
                                                  label: Text(
                                                    '${partida.gols} gol${partida.gols == 1 ? '' : 's'}',
                                                  ),
                                                ),
                                              if (partida.assistencias > 0)
                                                Chip(
                                                  label: Text(
                                                    '${partida.assistencias} assist.',
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                                if (_historico.length > 5)
                                  TextButton(
                                    onPressed: () {
                                      setState(
                                        () => _showAllHistorico =
                                            !_showAllHistorico,
                                      );
                                    },
                                    child: Text(
                                      _showAllHistorico
                                          ? 'Ver menos'
                                          : 'Ver todas (${_historico.length})',
                                    ),
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

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.leftLabel,
    required this.leftValue,
    required this.centerLabel,
    required this.centerValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String centerLabel;
  final String centerValue;
  final String rightLabel;
  final String rightValue;

  Widget _cell(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _cell(leftLabel, leftValue),
        _cell(centerLabel, centerValue),
        _cell(rightLabel, rightValue),
      ],
    );
  }
}
