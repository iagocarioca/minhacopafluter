import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_badge.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/core/widgets/image_file_picker_field.dart';
import 'package:frontcopa_flutter/core/widgets/jogador_picker_field.dart';
import 'package:frontcopa_flutter/domain/models/jogador.dart';
import 'package:frontcopa_flutter/domain/models/time_model.dart';
import 'package:frontcopa_flutter/features/jogadores/data/jogadores_remote_data_source.dart';
import 'package:frontcopa_flutter/features/times/data/times_remote_data_source.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class TimeDetailPage extends StatefulWidget {
  const TimeDetailPage({
    super.key,
    required this.peladaId,
    required this.timeId,
    required this.config,
    required this.timesDataSource,
    required this.jogadoresDataSource,
  });

  final int peladaId;
  final int timeId;
  final AppConfig config;
  final TimesRemoteDataSource timesDataSource;
  final JogadoresRemoteDataSource jogadoresDataSource;

  @override
  State<TimeDetailPage> createState() => _TimeDetailPageState();
}

class _TimeDetailPageState extends State<TimeDetailPage> {
  TimeModel? _time;
  List<Jogador> _jogadoresTime = const <Jogador>[];
  List<Jogador> _jogadoresDisponiveis = const <Jogador>[];

  bool _loading = true;
  bool _saving = false;
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
      final detail = await widget.timesDataSource.getTime(widget.timeId);
      final jogadores = await widget.jogadoresDataSource.listJogadores(
        peladaId: widget.peladaId,
        page: 1,
        perPage: 400,
        ativo: true,
      );
      if (!mounted) return;

      setState(() {
        _time = detail.time;
        _jogadoresTime = detail.jogadores;
        _jogadoresDisponiveis = jogadores.items
            .where((j) => j.timeId == null)
            .toList();
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

  Color _parseColor(String? raw) {
    final value = (raw ?? '').trim();
    if (value.startsWith('#') && value.length == 7) {
      final hex = value.substring(1);
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) {
        return Color(0xFF000000 | parsed);
      }
    }
    return const Color(0xFF2A2C35);
  }

  String _jogadorLabel(Jogador jogador) {
    return jogador.apelido.isNotEmpty ? jogador.apelido : jogador.nomeCompleto;
  }

  String _jogadorInicial(Jogador jogador) {
    final label = _jogadorLabel(jogador).trim();
    if (label.isEmpty) return 'J';
    return label.substring(0, 1).toUpperCase();
  }

  List<Jogador> _sortedJogadoresForField(List<Jogador> jogadores) {
    final list = List<Jogador>.from(jogadores);
    list.sort((a, b) {
      if (a.capitao == true && b.capitao != true) return -1;
      if (a.capitao != true && b.capitao == true) return 1;
      return _jogadorLabel(
        a,
      ).toLowerCase().compareTo(_jogadorLabel(b).toLowerCase());
    });
    return list;
  }

  Future<void> _openJogadorActions(Jogador jogador) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final fotoUrl = widget.config.resolveApiImageUrl(jogador.fotoUrl);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: fotoUrl != null
                        ? NetworkImage(fotoUrl)
                        : null,
                    child: fotoUrl == null
                        ? Text(_jogadorInicial(jogador))
                        : null,
                  ),
                  title: Text(_jogadorLabel(jogador)),
                  subtitle: Text(jogador.posicao ?? 'Sem posicao'),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Editar posicao'),
                  onTap: () => Navigator.of(context).pop('edit_posicao'),
                ),
                if (jogador.capitao != true)
                  ListTile(
                    leading: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFD97706),
                    ),
                    title: const Text('Tornar capitao'),
                    onTap: () => Navigator.of(context).pop('capitao'),
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC3B3B),
                  ),
                  title: const Text('Remover do time'),
                  onTap: () => Navigator.of(context).pop('remover'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;
    if (action == 'edit_posicao') {
      await _updatePosicao(jogador);
      return;
    }
    if (action == 'capitao') {
      await _toggleCapitao(jogador);
      return;
    }
    if (action == 'remover') {
      await _removeJogador(jogador);
      return;
    }
  }

  Future<void> _openEditTeamDialog() async {
    final nomeController = TextEditingController(text: _time?.nome ?? '');
    final corController = TextEditingController(text: _time?.cor ?? '#2A2C35');

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar time'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome do time'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: corController,
                decoration: const InputDecoration(labelText: 'Cor (#RRGGBB)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    final nome = nomeController.text.trim();
                    final cor = corController.text.trim();
                    if (nome.isEmpty) return;
                    setState(() => _saving = true);
                    try {
                      await widget.timesDataSource.updateTime(
                        timeId: widget.timeId,
                        input: TimeUpdateInput(nome: nome, cor: cor),
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      await _load();
                    } finally {
                      if (mounted) {
                        setState(() => _saving = false);
                      }
                    }
                  },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    nomeController.dispose();
    corController.dispose();
  }

  Future<void> _openEscudoDialog() async {
    XFile? escudoFile;
    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Atualizar escudo'),
            content: ImageFilePickerField(
              label: 'Imagem do escudo',
              onChanged: (file) => setDialogState(() => escudoFile = file),
              initialImageUrl: widget.config.resolveApiImageUrl(
                _time?.escudoUrl,
              ),
            ),
            actions: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _saving || escudoFile == null
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await widget.timesDataSource.updateEscudo(
                            timeId: widget.timeId,
                            escudoFile: escudoFile!,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await _load();
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAddJogadorDialog() async {
    int? jogadorId;
    final posicaoController = TextEditingController();
    bool capitao = false;
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Adicionar jogador'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  JogadorPickerField(
                    label: 'Jogador',
                    value: jogadorDisplayNameById(
                      _jogadoresDisponiveis,
                      jogadorId,
                      empty: _jogadoresDisponiveis.isEmpty
                          ? 'Sem jogadores disponiveis'
                          : 'Selecionar jogador',
                    ),
                    icon: Icons.person_add_alt_1_rounded,
                    enabled: _jogadoresDisponiveis.isNotEmpty && !_saving,
                    onTap: () async {
                      final selected = await showJogadorPickerModal(
                        context: context,
                        title: 'Selecionar jogador',
                        jogadores: _jogadoresDisponiveis,
                        selectedId: jogadorId,
                      );
                      if (selected == null || !context.mounted) return;
                      setDialogState(() => jogadorId = selected);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: posicaoController,
                    decoration: const InputDecoration(labelText: 'Posicao'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: capitao,
                        onChanged: (value) =>
                            setDialogState(() => capitao = value ?? false),
                      ),
                      const Text('Marcar como capitao'),
                    ],
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      localError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        if (jogadorId == null) {
                          setDialogState(
                            () => localError = 'Selecione um jogador.',
                          );
                          return;
                        }
                        setState(() => _saving = true);
                        try {
                          await widget.timesDataSource.addJogador(
                            timeId: widget.timeId,
                            jogadorId: jogadorId!,
                            posicao: posicaoController.text.trim(),
                            capitao: capitao,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await _load();
                        } catch (error) {
                          setDialogState(() => localError = error.toString());
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: const Text('Adicionar'),
              ),
            ],
          );
        },
      ),
    );

    posicaoController.dispose();
  }

  Future<void> _updatePosicao(Jogador jogador) async {
    final controller = TextEditingController(text: jogador.posicao ?? '');

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Atualizar posicao'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Posicao'),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await widget.timesDataSource.updateJogador(
                        timeId: widget.timeId,
                        jogadorId: jogador.id,
                        posicao: controller.text.trim(),
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      await _load();
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _toggleCapitao(Jogador jogador) async {
    setState(() => _saving = true);
    try {
      await widget.timesDataSource.updateJogador(
        timeId: widget.timeId,
        jogadorId: jogador.id,
        capitao: true,
      );
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeJogador(Jogador jogador) async {
    setState(() => _saving = true);
    try {
      await widget.timesDataSource.removeJogador(
        timeId: widget.timeId,
        jogadorId: jogador.id,
      );
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = _time;
    final escudoUrl = widget.config.resolveApiImageUrl(time?.escudoUrl);
    final color = _parseColor(time?.cor);
    final jogadoresOrdenados = _sortedJogadoresForField(_jogadoresTime);

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Time'),
        actions: [
          IconButton(
            onPressed: _openEditTeamDialog,
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Editar time',
          ),
        ],
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
                  CyberCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: color.withValues(alpha: 0.2),
                          backgroundImage: escudoUrl != null
                              ? NetworkImage(escudoUrl)
                              : null,
                          child: escudoUrl == null
                              ? Text(
                                  time?.nome.isNotEmpty == true
                                      ? time!.nome[0].toUpperCase()
                                      : 'T',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                time?.nome ?? 'Time',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cor: ${time?.cor ?? '-'}',
                                style: const TextStyle(
                                  color: Color(0xFF98A0AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _openEscudoDialog,
                          icon: const Icon(Icons.upload_rounded),
                          tooltip: 'Atualizar escudo',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Campo',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      CyberBadge(
                        label: '${_jogadoresTime.length} jogadores',
                        variant: CyberBadgeVariant.info,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _openAddJogadorDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_jogadoresTime.isEmpty)
                    const CyberCard(child: Text('Nenhum jogador no time.'))
                  else
                    _TeamPlayersField(
                      jogadores: jogadoresOrdenados,
                      config: widget.config,
                      jogadorLabel: _jogadorLabel,
                      saving: _saving,
                      onTapJogador: _openJogadorActions,
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/peladas/${widget.peladaId}/temporadas/${time?.temporadaId ?? 0}/times',
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Voltar para Times'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TeamPlayersField extends StatelessWidget {
  const _TeamPlayersField({
    required this.jogadores,
    required this.config,
    required this.jogadorLabel,
    required this.saving,
    required this.onTapJogador,
  });

  final List<Jogador> jogadores;
  final AppConfig config;
  final String Function(Jogador jogador) jogadorLabel;
  final bool saving;
  final Future<void> Function(Jogador jogador) onTapJogador;

  bool _isGoleiro(Jogador jogador) {
    final raw = (jogador.posicao ?? '').trim().toLowerCase();
    return raw.contains('goleiro') || raw == 'gk' || raw == 'gol';
  }

  List<int> _formationByCount(int count, {required bool hasGoalkeeper}) {
    final c = count.clamp(0, hasGoalkeeper ? 10 : 11);
    const withGk = <int, List<int>>{
      0: <int>[],
      1: <int>[1],
      2: <int>[2],
      3: <int>[2, 1],
      4: <int>[2, 2],
      5: <int>[2, 2, 1],
      6: <int>[2, 2, 2],
      7: <int>[3, 2, 2],
      8: <int>[3, 3, 2],
      9: <int>[3, 3, 3],
      10: <int>[3, 4, 3],
    };
    const withoutGk = <int, List<int>>{
      0: <int>[],
      1: <int>[1],
      2: <int>[2],
      3: <int>[2, 1],
      4: <int>[2, 2],
      5: <int>[2, 2, 1],
      6: <int>[2, 2, 2],
      7: <int>[3, 2, 2],
      8: <int>[3, 3, 2],
      9: <int>[3, 3, 3],
      10: <int>[3, 4, 3],
      11: <int>[3, 4, 4],
    };
    return List<int>.from((hasGoalkeeper ? withGk : withoutGk)[c] ?? <int>[]);
  }

  List<double> _lineYPositions(int lineCount, {required bool hasGoalkeeper}) {
    if (lineCount <= 0) return const <double>[];

    final top = -0.72;
    final bottom = hasGoalkeeper ? 0.14 : 0.52;
    if (lineCount == 1) {
      return <double>[(top + bottom) / 2];
    }

    final step = (bottom - top) / (lineCount - 1);
    return List<double>.generate(lineCount, (index) => top + step * index);
  }

  double _resolveCardWidth(double fieldWidth, int maxInLine) {
    if (maxInLine <= 1) return 88;
    const horizontalGap = 8.0;
    const horizontalPadding = 10.0;
    const minWidth = 64.0;
    const maxWidth = 88.0;

    final available =
        fieldWidth -
        (horizontalPadding * 2) -
        ((maxInLine - 1) * horizontalGap);
    final fitted = available / maxInLine;
    return fitted.clamp(minWidth, maxWidth);
  }

  List<double> _lineXPositions(
    int count, {
    required double fieldWidth,
    required double cardWidth,
  }) {
    if (count <= 0) return const <double>[];
    if (count == 1) return const <double>[0];

    const sidePadding = 10.0;
    final minCenterX = sidePadding + (cardWidth / 2);
    final maxCenterX = fieldWidth - sidePadding - (cardWidth / 2);
    if (maxCenterX <= minCenterX) {
      return List<double>.filled(count, 0);
    }

    final step = (maxCenterX - minCenterX) / (count - 1);
    return List<double>.generate(count, (index) {
      final centerX = minCenterX + (step * index);
      return ((centerX / fieldWidth) * 2) - 1;
    });
  }

  List<Jogador> _seededShuffle(List<Jogador> players, int seedBase) {
    final shuffled = List<Jogador>.from(players);
    final random = math.Random(seedBase);
    for (var i = shuffled.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }
    return shuffled;
  }

  _FieldLayout _buildLayout(
    List<Jogador> source, {
    required double fieldWidth,
  }) {
    if (source.isEmpty) {
      return const _FieldLayout(spots: <_FieldSpot>[], cardWidth: 80);
    }

    Jogador? goleiro;
    for (final item in source) {
      if (_isGoleiro(item)) {
        goleiro = item;
        break;
      }
    }
    final seedBase = source.fold<int>(
      17,
      (hash, item) => ((hash * 31) ^ item.id) & 0x7fffffff,
    );

    final semGoleiro = source
        .where((jogador) => goleiro == null || jogador.id != goleiro.id)
        .toList();

    final displayed = <Jogador>[];
    if (goleiro != null) {
      displayed.add(goleiro);
    }
    displayed.addAll(semGoleiro.take(goleiro != null ? 10 : 11));

    final outfield = displayed
        .where((jogador) => goleiro == null || jogador.id != goleiro.id)
        .toList();
    final outfieldShuffled = _seededShuffle(outfield, seedBase ^ 0x6D2B79F5);
    final hasGk = goleiro != null;
    final formation = _formationByCount(
      outfieldShuffled.length,
      hasGoalkeeper: hasGk,
    );
    final maxPlayersInLine = formation.isEmpty
        ? 1
        : formation.reduce((a, b) => a > b ? a : b);
    final cardWidth = _resolveCardWidth(fieldWidth, maxPlayersInLine);
    final yPositions = _lineYPositions(formation.length, hasGoalkeeper: hasGk);

    final spots = <_FieldSpot>[];
    var cursor = 0;
    for (var line = 0; line < formation.length; line++) {
      final countInLine = formation[line];
      final xPositions = _lineXPositions(
        countInLine,
        fieldWidth: fieldWidth,
        cardWidth: cardWidth,
      );
      for (
        var i = 0;
        i < countInLine && cursor < outfieldShuffled.length;
        i++
      ) {
        spots.add(
          _FieldSpot(
            jogador: outfieldShuffled[cursor],
            alignment: Offset(xPositions[i], yPositions[line]),
          ),
        );
        cursor++;
      }
    }

    if (goleiro != null) {
      spots.add(_FieldSpot(jogador: goleiro, alignment: const Offset(0, 0.78)));
    }

    return _FieldLayout(spots: spots, cardWidth: cardWidth);
  }

  @override
  Widget build(BuildContext context) {
    final fieldHeight = MediaQuery.sizeOf(context).height * 0.6;

    return CyberCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Campo organizado automaticamente por quantidade de jogadores.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Container(
            height: fieldHeight.clamp(360.0, 620.0),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F3EA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = _buildLayout(
                  jogadores,
                  fieldWidth: constraints.maxWidth,
                );
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _FieldPainter()),
                    ),
                    ...layout.spots.map((spot) {
                      return Align(
                        alignment: Alignment(
                          spot.alignment.dx,
                          spot.alignment.dy,
                        ),
                        child: _FormationPlayerCard(
                          jogador: spot.jogador,
                          config: config,
                          jogadorLabel: jogadorLabel,
                          saving: saving,
                          width: layout.cardWidth,
                          onTap: () => onTapJogador(spot.jogador),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FormationPlayerCard extends StatelessWidget {
  const _FormationPlayerCard({
    required this.jogador,
    required this.config,
    required this.jogadorLabel,
    required this.saving,
    required this.width,
    required this.onTap,
  });

  final Jogador jogador;
  final AppConfig config;
  final String Function(Jogador jogador) jogadorLabel;
  final bool saving;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fotoUrl = config.resolveApiImageUrl(jogador.fotoUrl);
    final avatarRadius = width < 72 ? 17.0 : 20.0;
    final nameFontSize = width < 72 ? 10.5 : 11.5;
    final hasPosicao = (jogador.posicao ?? '').trim().isNotEmpty;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: saving ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: const Color(0xFFEAF0EC),
                        backgroundImage: fotoUrl != null
                            ? NetworkImage(fotoUrl)
                            : null,
                        child: fotoUrl == null
                            ? Text(
                                _initialFromLabel(jogadorLabel(jogador)),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              )
                            : null,
                      ),
                    ),
                    if (jogador.capitao == true)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFD97706),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        jogadorLabel(jogador),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          height: 1.05,
                        ),
                      ),
                      if (hasPosicao) ...[
                        const SizedBox(height: 2),
                        Text(
                          jogador.posicao!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: nameFontSize - 1,
                            fontWeight: FontWeight.w500,
                            color: Colors.black.withValues(alpha: 0.7),
                            height: 1.0,
                          ),
                        ),
                      ],
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

  String _initialFromLabel(String label) {
    final value = label.trim();
    if (value.isEmpty) return 'J';
    return value.substring(0, 1).toUpperCase();
  }
}

class _FieldLayout {
  const _FieldLayout({required this.spots, required this.cardWidth});

  final List<_FieldSpot> spots;
  final double cardWidth;
}

class _FieldSpot {
  const _FieldSpot({required this.jogador, required this.alignment});

  final Jogador jogador;
  final Offset alignment;
}

class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0x6F7BC79A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), linePaint);
    canvas.drawCircle(Offset(centerX, centerY), 18, linePaint);

    final borderPaint = Paint()
      ..color = const Color(0x4D68B186)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
