import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_tabs.dart';
import 'package:frontcopa_flutter/core/widgets/jogador_picker_field.dart';
import 'package:frontcopa_flutter/domain/models/comparativo.dart';
import 'package:frontcopa_flutter/domain/models/jogador.dart';
import 'package:frontcopa_flutter/features/comparativo/data/comparativo_remote_data_source.dart';
import 'package:frontcopa_flutter/features/jogadores/data/jogadores_remote_data_source.dart';

class ComparativoPage extends StatefulWidget {
  const ComparativoPage({
    super.key,
    required this.peladaId,
    required this.config,
    required this.comparativoDataSource,
    required this.jogadoresDataSource,
  });

  final int peladaId;
  final AppConfig config;
  final ComparativoRemoteDataSource comparativoDataSource;
  final JogadoresRemoteDataSource jogadoresDataSource;

  @override
  State<ComparativoPage> createState() => _ComparativoPageState();
}

class _ComparativoPageState extends State<ComparativoPage> {
  List<Jogador> _jogadores = const <Jogador>[];
  ComparativoJogadoresData? _comparativo;

  int? _jogadorAId;
  int? _jogadorBId;
  String _escopo = 'atual';

  bool _loading = true;
  bool _loadingComparativo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJogadores();
  }

  Future<void> _loadJogadores() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.jogadoresDataSource.listJogadores(
        peladaId: widget.peladaId,
        page: 1,
        perPage: 200,
        ativo: true,
      );
      final jogadores = response.items;
      if (!mounted) return;
      setState(() {
        _jogadores = jogadores;
        if (_jogadorAId == null && jogadores.isNotEmpty) {
          _jogadorAId = jogadores.first.id;
        }
        if (_jogadorBId == null && jogadores.length > 1) {
          _jogadorBId = jogadores[1].id;
        }
      });
      if (_canCompare) {
        await _compare();
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

  bool get _canCompare =>
      _jogadorAId != null && _jogadorBId != null && _jogadorAId != _jogadorBId;

  Future<void> _compare() async {
    if (!_canCompare) return;
    setState(() {
      _loadingComparativo = true;
      _error = null;
    });
    try {
      final data = await widget.comparativoDataSource.compararJogadores(
        peladaId: widget.peladaId,
        jogadorIds: <int>[_jogadorAId!, _jogadorBId!],
        escopo: _escopo,
      );
      if (!mounted) return;
      setState(() => _comparativo = data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingComparativo = false);
      }
    }
  }

  bool _winnerForKey(String key, int jogadorId) {
    final winner = _comparativo?.vencedores[key];
    if (winner == null || winner.jogadoresIds.isEmpty) {
      return false;
    }
    return winner.jogadoresIds.contains(jogadorId);
  }

  Widget _metricRow({
    required String label,
    required int leftValue,
    required int rightValue,
    required bool leftWinner,
    required bool rightWinner,
  }) {
    Color bgFor(bool isWinner) =>
        isWinner ? const Color(0x24FF3B4D) : AppTheme.surfaceAlt;

    Color textFor(bool isWinner) =>
        isWinner ? const Color(0xFFFF3B4D) : AppTheme.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Color(0xFF131722),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 36,
            decoration: BoxDecoration(
              color: bgFor(leftWinner && !rightWinner),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '$leftValue',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: textFor(leftWinner && !rightWinner),
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 36,
            decoration: BoxDecoration(
              color: bgFor(rightWinner && !leftWinner),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rightValue',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: textFor(rightWinner && !leftWinner),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final comparativo = _comparativo;
    final jogadoresComparados =
        comparativo?.comparativo ?? const <ComparativoJogadorEntry>[];

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Comparativo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadJogadores,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  CyberCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: JogadorPickerField(
                                label: 'Jogador A',
                                value: jogadorDisplayNameById(
                                  _jogadores,
                                  _jogadorAId,
                                  empty: 'Selecionar jogador',
                                ),
                                icon: Icons.person_rounded,
                                enabled: _jogadores
                                    .where((item) => item.id != _jogadorBId)
                                    .isNotEmpty,
                                onTap: () async {
                                  final candidatos = _jogadores
                                      .where((item) => item.id != _jogadorBId)
                                      .toList();
                                  final selected = await showJogadorPickerModal(
                                    context: context,
                                    title: 'Selecionar jogador A',
                                    jogadores: candidatos,
                                    selectedId: _jogadorAId,
                                  );
                                  if (selected == null || !context.mounted) {
                                    return;
                                  }
                                  setState(() => _jogadorAId = selected);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: JogadorPickerField(
                                label: 'Jogador B',
                                value: jogadorDisplayNameById(
                                  _jogadores,
                                  _jogadorBId,
                                  empty: 'Selecionar jogador',
                                ),
                                icon: Icons.person_rounded,
                                enabled: _jogadores
                                    .where((item) => item.id != _jogadorAId)
                                    .isNotEmpty,
                                onTap: () async {
                                  final candidatos = _jogadores
                                      .where((item) => item.id != _jogadorAId)
                                      .toList();
                                  final selected = await showJogadorPickerModal(
                                    context: context,
                                    title: 'Selecionar jogador B',
                                    jogadores: candidatos,
                                    selectedId: _jogadorBId,
                                  );
                                  if (selected == null || !context.mounted) {
                                    return;
                                  }
                                  setState(() => _jogadorBId = selected);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: CyberTabs(
                                labels: const ['Atual', 'Todas'],
                                selectedIndex: _escopo == 'atual' ? 0 : 1,
                                onChanged: (index) {
                                  setState(
                                    () => _escopo = index == 0
                                        ? 'atual'
                                        : 'todas',
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _loadingComparativo || !_canCompare
                                  ? null
                                  : _compare,
                              child: _loadingComparativo
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Comparar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    CyberCard(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (jogadoresComparados.length != 2)
                    const CyberCard(
                      child: Text('Escolha dois jogadores para comparar.'),
                    )
                  else ...[
                    CyberCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF22131B), Color(0xFF0C0E14)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _PlayerHeader(
                                    jogador: jogadoresComparados[0].jogador,
                                    config: widget.config,
                                    alignEnd: true,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'VS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _PlayerHeader(
                                    jogador: jogadoresComparados[1].jogador,
                                    config: widget.config,
                                    alignEnd: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _metricRow(
                            label: 'Ranking',
                            leftValue: jogadoresComparados[0].posicao,
                            rightValue: jogadoresComparados[1].posicao,
                            leftWinner: _winnerForKey(
                              'melhor_rank',
                              jogadoresComparados[0].jogador.id,
                            ),
                            rightWinner: _winnerForKey(
                              'melhor_rank',
                              jogadoresComparados[1].jogador.id,
                            ),
                          ),
                          _metricRow(
                            label: 'Vitorias',
                            leftValue:
                                jogadoresComparados[0].estatisticas.vitorias,
                            rightValue:
                                jogadoresComparados[1].estatisticas.vitorias,
                            leftWinner: _winnerForKey(
                              'mais_vitorias',
                              jogadoresComparados[0].jogador.id,
                            ),
                            rightWinner: _winnerForKey(
                              'mais_vitorias',
                              jogadoresComparados[1].jogador.id,
                            ),
                          ),
                          _metricRow(
                            label: 'Gols',
                            leftValue: jogadoresComparados[0]
                                .estatisticas
                                .golsMarcados,
                            rightValue: jogadoresComparados[1]
                                .estatisticas
                                .golsMarcados,
                            leftWinner: _winnerForKey(
                              'mais_gols',
                              jogadoresComparados[0].jogador.id,
                            ),
                            rightWinner: _winnerForKey(
                              'mais_gols',
                              jogadoresComparados[1].jogador.id,
                            ),
                          ),
                          _metricRow(
                            label: 'Assistencias',
                            leftValue: jogadoresComparados[0]
                                .estatisticas
                                .assistencias,
                            rightValue: jogadoresComparados[1]
                                .estatisticas
                                .assistencias,
                            leftWinner: _winnerForKey(
                              'mais_assistencias',
                              jogadoresComparados[0].jogador.id,
                            ),
                            rightWinner: _winnerForKey(
                              'mais_assistencias',
                              jogadoresComparados[1].jogador.id,
                            ),
                          ),
                          _metricRow(
                            label: 'Titulos',
                            leftValue:
                                jogadoresComparados[0].estatisticas.titulos,
                            rightValue:
                                jogadoresComparados[1].estatisticas.titulos,
                            leftWinner: _winnerForKey(
                              'mais_titulos',
                              jogadoresComparados[0].jogador.id,
                            ),
                            rightWinner: _winnerForKey(
                              'mais_titulos',
                              jogadoresComparados[1].jogador.id,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({
    required this.jogador,
    required this.config,
    required this.alignEnd,
  });

  final ComparativoJogadorResumo jogador;
  final AppConfig config;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final image = config.resolveApiImageUrl(jogador.fotoUrl);
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (!alignEnd) ...[
          CircleAvatar(
            radius: 20,
            backgroundImage: image != null ? NetworkImage(image) : null,
            child: image == null ? const Icon(Icons.person, size: 18) : null,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            jogador.nomeExibicao,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (alignEnd) ...[
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundImage: image != null ? NetworkImage(image) : null,
            child: image == null ? const Icon(Icons.person, size: 18) : null,
          ),
        ],
      ],
    );
  }
}
