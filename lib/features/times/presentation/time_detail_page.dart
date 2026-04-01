import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
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
                        'Jogadores',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
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
                    ..._jogadoresTime.map((jogador) {
                      final fotoUrl = widget.config.resolveApiImageUrl(
                        jogador.fotoUrl,
                      );
                      return CyberCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: fotoUrl != null
                                ? NetworkImage(fotoUrl)
                                : null,
                            child: fotoUrl == null
                                ? Text(
                                    _jogadorLabel(
                                      jogador,
                                    ).substring(0, 1).toUpperCase(),
                                  )
                                : null,
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(_jogadorLabel(jogador))),
                              if (jogador.capitao == true)
                                const CyberBadge(
                                  label: 'Capitao',
                                  variant: CyberBadgeVariant.info,
                                ),
                            ],
                          ),
                          subtitle: Text(jogador.posicao ?? 'Sem posicao'),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              IconButton(
                                onPressed: _saving
                                    ? null
                                    : () => _updatePosicao(jogador),
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                tooltip: 'Editar posicao',
                              ),
                              if (jogador.capitao != true)
                                IconButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _toggleCapitao(jogador),
                                  icon: const Icon(
                                    Icons.emoji_events_rounded,
                                    size: 18,
                                    color: Color(0xFFD97706),
                                  ),
                                  tooltip: 'Tornar capitao',
                                ),
                              IconButton(
                                onPressed: _saving
                                    ? null
                                    : () => _removeJogador(jogador),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFDC3B3B),
                                ),
                                tooltip: 'Remover',
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
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
