import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/domain/models/jogador.dart';
import 'package:frontcopa_flutter/domain/models/partida.dart';
import 'package:frontcopa_flutter/features/partidas/data/partidas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/rodadas/data/rodadas_remote_data_source.dart';
import 'package:intl/intl.dart';

class PartidaDetailPage extends StatefulWidget {
  const PartidaDetailPage({
    super.key,
    required this.peladaId,
    required this.partidaId,
    required this.config,
    required this.partidasDataSource,
    required this.rodadasDataSource,
  });

  final int peladaId;
  final int partidaId;
  final AppConfig config;
  final PartidasRemoteDataSource partidasDataSource;
  final RodadasRemoteDataSource rodadasDataSource;

  @override
  State<PartidaDetailPage> createState() => _PartidaDetailPageState();
}

class _PartidaDetailPageState extends State<PartidaDetailPage> {
  Partida? _partida;
  List<Jogador> _jogadoresRodada = const <Jogador>[];
  Timer? _ticker;
  DateTime _now = DateTime.now();
  DateTime? _liveStartFallback;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _contentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final partida = await widget.partidasDataSource.getPartida(
        widget.partidaId,
      );
      final jogadoresRodada = await widget.rodadasDataSource
          .listJogadoresRodada(partida.rodadaId, apenasAtivos: true);

      if (!mounted) return;
      setState(() {
        _partida = partida;
        _jogadoresRodada = jogadoresRodada;
        final start = _parseStartDate(partida.inicio ?? partida.dataHora);
        if (partida.status == 'em_andamento') {
          _liveStartFallback = start ?? _liveStartFallback ?? DateTime.now();
        } else if (partida.status == 'agendada') {
          _liveStartFallback = null;
        } else {
          _liveStartFallback = start ?? _liveStartFallback;
        }
      });
      _syncTicker();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      _syncTicker(forceStop: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _syncTicker({bool forceStop = false}) {
    if (forceStop) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }

    final partida = _partida;
    final shouldTick = partida != null && partida.status == 'em_andamento';

    if (shouldTick) {
      if (_ticker != null) return;
      setState(() => _now = DateTime.now());
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
      return;
    }

    _ticker?.cancel();
    _ticker = null;
  }

  DateTime? _parseStartDate(String? raw) {
    final parsed = DateTime.tryParse(raw ?? '');
    return parsed?.toLocal();
  }

  String? _elapsedLabel(Partida? partida) {
    if (partida == null) return null;
    if (partida.status != 'em_andamento') {
      return null;
    }

    final inicio =
        _parseStartDate(partida.inicio ?? partida.dataHora) ??
        _liveStartFallback;
    if (inicio == null) {
      return partida.status == 'em_andamento' ? '00:00:00' : null;
    }

    final diff = _now.difference(inicio);
    if (diff.isNegative) return '00:00:00';
    final totalSeconds = diff.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _formatDateTime(String? value) {
    if (value == null || value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
  }

  String _statusLabel(String status) {
    const labels = <String, String>{
      'finalizada': 'Finalizada',
      'em_andamento': 'Em andamento',
      'agendada': 'Agendada',
    };
    return labels[status] ?? status.replaceAll('_', ' ');
  }

  String _goalEventLabel(GolEvent gol) {
    final jogador = gol.jogadorNome ?? 'Jogador #${gol.jogadorId}';
    final minuto = gol.minuto != null ? " ${gol.minuto}'" : '';
    final golContra = gol.golContra ? ' (GC)' : '';
    return '$jogador$minuto$golContra';
  }

  List<String> _goalEventsForTeam(Partida partida, int teamId) {
    final items = partida.gols.where((gol) => gol.timeId == teamId).toList()
      ..sort((a, b) => (a.minuto ?? 999).compareTo(b.minuto ?? 999));
    return items.map(_goalEventLabel).toList();
  }

  Color _parseHexColor(String? raw, {Color fallback = AppTheme.primary}) {
    final value = (raw ?? '').trim();
    if (value.startsWith('#') && value.length == 7) {
      final parsed = int.tryParse(value.substring(1), radix: 16);
      if (parsed != null) {
        return Color(0xFF000000 | parsed);
      }
    }
    return fallback;
  }

  String _teamNameById(Partida partida, int teamId) {
    if (teamId == partida.timeCasaId) {
      return partida.timeCasa?.nome ?? 'Time Casa';
    }
    return partida.timeFora?.nome ?? 'Time Visitante';
  }

  Color _teamColorById(Partida partida, int teamId) {
    if (teamId == partida.timeCasaId) {
      return _parseHexColor(partida.timeCasa?.cor, fallback: AppTheme.primary);
    }
    return _parseHexColor(partida.timeFora?.cor, fallback: AppTheme.info);
  }

  String _jogadorLabel(Jogador jogador) {
    return jogador.apelido.isNotEmpty ? jogador.apelido : jogador.nomeCompleto;
  }

  String _jogadorLabelById(int? id, {String empty = 'Selecionar jogador'}) {
    if (id == null) return empty;
    if (id == 0) return 'Sem assist\u00eancia';
    for (final jogador in _jogadoresRodada) {
      if (jogador.id == id) return _jogadorLabel(jogador);
    }
    return 'Jogador #$id';
  }

  Future<int?> _showJogadorPicker({
    required String title,
    required List<Jogador> jogadores,
    int? selectedId,
    bool allowNone = false,
  }) async {
    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final normalized = query.trim().toLowerCase();
            final filtered = jogadores.where((jogador) {
              if (normalized.isEmpty) return true;
              final apelido = jogador.apelido.toLowerCase();
              final nome = jogador.nomeCompleto.toLowerCase();
              final time = (jogador.timeNome ?? '').toLowerCase();
              return apelido.contains(normalized) ||
                  nome.contains(normalized) ||
                  time.contains(normalized);
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.74,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBorderStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${filtered.length}',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: TextField(
                          onChanged: (value) =>
                              setModalState(() => query = value),
                          decoration: InputDecoration(
                            hintText: 'Buscar jogador...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            fillColor: AppTheme.surfaceAlt,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (allowNone)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: _HoverPlayerOptionTile(
                            label: 'Sem assist\u00eancia',
                            subtitle: 'Sem jogador de assist\u00eancia',
                            selected: selectedId == 0,
                            onTap: () => Navigator.of(context).pop(0),
                          ),
                        ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nenhum jogador encontrado.',
                                  style: TextStyle(color: AppTheme.textMuted),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  0,
                                  10,
                                  12,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final jogador = filtered[index];
                                  return _HoverPlayerOptionTile(
                                    label: _jogadorLabel(jogador),
                                    subtitle: jogador.timeNome ?? 'Sem time',
                                    selected: selectedId == jogador.id,
                                    onTap: () =>
                                        Navigator.of(context).pop(jogador.id),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
    return result;
  }

  Future<void> _iniciarPartida() async {
    if (_partida == null) return;
    setState(() {
      _saving = true;
      _liveStartFallback = DateTime.now();
    });
    try {
      await widget.partidasDataSource.iniciarPartida(_partida!.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _showModernConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required IconData icon,
    Color accent = AppTheme.primary,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: accent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSoft,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(backgroundColor: accent),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return confirmed == true;
  }

  Future<void> _finalizarPartida() async {
    if (_partida == null) return;
    final confirm = await _showModernConfirmDialog(
      title: 'Finalizar partida',
      message: 'Deseja finalizar esta partida agora?',
      confirmLabel: 'Finalizar',
      icon: Icons.flag_rounded,
      accent: AppTheme.warning,
    );

    if (!confirm) return;

    setState(() => _saving = true);
    try {
      await widget.partidasDataSource.finalizarPartida(_partida!.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteGol(int golId) async {
    final confirm = await _showModernConfirmDialog(
      title: 'Remover gol',
      message: 'Deseja remover este gol?',
      confirmLabel: 'Remover',
      icon: Icons.delete_outline_rounded,
      accent: const Color(0xFFE14A52),
    );

    if (!confirm) return;

    setState(() => _saving = true);
    try {
      await widget.partidasDataSource.removerGol(golId);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openRegistrarGolDialog() async {
    if (_partida == null) return;

    int? timeId = _partida!.timeCasaId;
    int? jogadorId;
    int? assistenciaId;
    int marcadorScope = 0; // 0: time selecionado, 1: outros times
    int assistenciaScope = 0; // 0: time selecionado, 1: outros times
    final minutoController = TextEditingController();
    bool golContra = false;
    String? localError;
    bool savingDialog = false;

    List<Jogador> jogadoresDoTime(int? selectedTimeId) {
      if (selectedTimeId == null) return const <Jogador>[];
      return _jogadoresRodada
          .where((jogador) => jogador.timeId == selectedTimeId)
          .toList();
    }

    List<Jogador> jogadoresOutrosTimes(int? selectedTimeId) {
      if (selectedTimeId == null) {
        return List<Jogador>.from(_jogadoresRodada);
      }
      return _jogadoresRodada
          .where((jogador) => jogador.timeId != selectedTimeId)
          .toList();
    }

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final jogadoresTime = jogadoresDoTime(timeId);
          final jogadoresOutros = jogadoresOutrosTimes(timeId);
          final marcadores = marcadorScope == 0
              ? jogadoresTime
              : jogadoresOutros;
          final assistBase = assistenciaScope == 0
              ? jogadoresTime
              : jogadoresOutros;
          final assistentes = assistBase
              .where((jogador) => jogador.id != jogadorId)
              .toList();

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Registrar gol',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Selecione o time e informe marcador e assist\u00eancia.',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TeamTabSelector(
                      homeLabel: _partida!.timeCasa?.nome ?? 'Time casa',
                      awayLabel: _partida!.timeFora?.nome ?? 'Time visitante',
                      homeId: _partida!.timeCasaId,
                      awayId: _partida!.timeForaId,
                      selectedId: timeId ?? _partida!.timeCasaId,
                      onChanged: savingDialog
                          ? null
                          : (value) {
                              setDialogState(() {
                                timeId = value;
                                jogadorId = null;
                                assistenciaId = null;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Marcador',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(value: 0, label: Text('Time')),
                        ButtonSegment<int>(value: 1, label: Text('Outros')),
                      ],
                      selected: <int>{marcadorScope},
                      onSelectionChanged: savingDialog
                          ? null
                          : (selection) {
                              final nextScope = selection.first;
                              final nextMarcadores = nextScope == 0
                                  ? jogadoresTime
                                  : jogadoresOutros;
                              setDialogState(() {
                                marcadorScope = nextScope;
                                if (!nextMarcadores.any(
                                  (j) => j.id == jogadorId,
                                )) {
                                  jogadorId = null;
                                }
                                if (assistenciaId == jogadorId) {
                                  assistenciaId = null;
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    _PickerFieldButton(
                      label: marcadorScope == 0
                          ? 'Artilheiro (time)'
                          : 'Artilheiro (outros)',
                      value: _jogadorLabelById(
                        jogadorId,
                        empty: marcadores.isEmpty
                            ? 'Nenhum jogador dispon\u00edvel'
                            : 'Selecionar marcador',
                      ),
                      icon: Icons.person_pin_circle_outlined,
                      enabled:
                          !savingDialog &&
                          timeId != null &&
                          marcadores.isNotEmpty,
                      onTap: () async {
                        final selected = await _showJogadorPicker(
                          title: marcadorScope == 0
                              ? 'Selecionar marcador do time'
                              : 'Selecionar marcador de outros times',
                          jogadores: marcadores,
                          selectedId: jogadorId,
                        );
                        if (selected == null || !context.mounted) return;
                        setDialogState(() {
                          jogadorId = selected;
                          if (assistenciaId == jogadorId) {
                            assistenciaId = null;
                          }
                          localError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Assist\u00eancia',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(value: 0, label: Text('Time')),
                        ButtonSegment<int>(value: 1, label: Text('Outros')),
                      ],
                      selected: <int>{assistenciaScope},
                      onSelectionChanged: savingDialog
                          ? null
                          : (selection) {
                              final nextScope = selection.first;
                              final nextAssistBase = nextScope == 0
                                  ? jogadoresTime
                                  : jogadoresOutros;
                              final nextAssistentes = nextAssistBase
                                  .where((jogador) => jogador.id != jogadorId)
                                  .toList();
                              setDialogState(() {
                                assistenciaScope = nextScope;
                                if (assistenciaId != 0 &&
                                    !nextAssistentes.any(
                                      (jogador) => jogador.id == assistenciaId,
                                    )) {
                                  assistenciaId = null;
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    _PickerFieldButton(
                      label: assistenciaScope == 0
                          ? 'Assist\u00eancia (time)'
                          : 'Assist\u00eancia (outros)',
                      value: _jogadorLabelById(
                        assistenciaId,
                        empty: 'Selecionar assist\u00eancia (opcional)',
                      ),
                      icon: Icons.assistant_rounded,
                      enabled: !savingDialog && timeId != null,
                      onTap: () async {
                        final selected = await _showJogadorPicker(
                          title: assistenciaScope == 0
                              ? 'Selecionar assist\u00eancia do time'
                              : 'Selecionar assist\u00eancia de outros times',
                          jogadores: assistentes,
                          selectedId: assistenciaId,
                          allowNone: true,
                        );
                        if (selected == null || !context.mounted) return;
                        setDialogState(() {
                          assistenciaId = selected;
                          if (assistenciaId == jogadorId) {
                            assistenciaId = null;
                          }
                          localError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: minutoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minuto (opcional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: golContra,
                      contentPadding: EdgeInsets.zero,
                      onChanged: savingDialog
                          ? null
                          : (value) => setDialogState(() => golContra = value),
                      title: const Text('Gol contra'),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        localError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: savingDialog
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: savingDialog
                                ? null
                                : () async {
                                    if (timeId == null || jogadorId == null) {
                                      setDialogState(
                                        () => localError =
                                            'Selecione time e artilheiro.',
                                      );
                                      return;
                                    }

                                    setDialogState(() {
                                      localError = null;
                                      savingDialog = true;
                                    });

                                    try {
                                      await widget.partidasDataSource
                                          .registrarGol(
                                            partidaId: widget.partidaId,
                                            input: GolCreateInput(
                                              timeId: timeId!,
                                              jogadorId: jogadorId!,
                                              assistenciaId: assistenciaId == 0
                                                  ? null
                                                  : assistenciaId,
                                              minuto: int.tryParse(
                                                minutoController.text.trim(),
                                              ),
                                              golContra: golContra,
                                            ),
                                          );
                                      if (!context.mounted) return;
                                      Navigator.of(context).pop();
                                      await _load();
                                    } catch (error) {
                                      setDialogState(
                                        () => localError = error.toString(),
                                      );
                                    } finally {
                                      setDialogState(
                                        () => savingDialog = false,
                                      );
                                    }
                                  },
                            child: savingDialog
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Salvar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    minutoController.dispose();
  }

  Widget _buildSectionTabs() {
    final labels = <String>['Vis\u00e3o geral', 'Gols', 'A\u00e7\u00f5es'];
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _contentTabIndex == index;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _contentTabIndex = index),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? const Color(0xFFE14A52)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOverviewSection(Partida? partida, String? elapsedLabel) {
    if (partida == null) {
      return const CyberCard(
        child: Text('Partida indispon\u00edvel no momento.'),
      );
    }

    final totalGols = partida.gols.length;
    final showLiveTime = partida.status == 'em_andamento';
    final maiorMinuto = partida.gols
        .map((item) => item.minuto ?? 0)
        .fold<int>(0, (prev, next) => next > prev ? next : prev);
    final ultimoRegistro = maiorMinuto > 0 ? "$maiorMinuto'" : '--';

    return CyberCard(
      child: Column(
        children: [
          _OverviewRow(
            label: 'Status',
            value: _statusLabel(partida.status),
            valueColor: AppTheme.textPrimary,
          ),
          if (showLiveTime) ...[
            const SizedBox(height: 8),
            _OverviewRow(
              label: 'Tempo',
              value: elapsedLabel ?? '00:00:00',
              valueColor: AppTheme.primary,
            ),
          ],
          const SizedBox(height: 8),
          _OverviewRow(
            label: 'Total de gols',
            value: '$totalGols',
            valueColor: AppTheme.textPrimary,
          ),
          const SizedBox(height: 8),
          _OverviewRow(
            label: '\u00daltimo registro',
            value: ultimoRegistro,
            valueColor: AppTheme.textSoft,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsSection(Partida? partida) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Hist\u00f3rico de gols',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            if (partida != null && partida.gols.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x1EFF3B4D),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.transparent),
                ),
                child: Text(
                  '${partida.gols.length}',
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
        if (partida == null || partida.gols.isEmpty)
          const CyberCard(child: Text('Nenhum gol registrado nesta partida.')),
        if (partida != null && partida.gols.isNotEmpty)
          ...(() {
            final items = List<GolEvent>.from(partida.gols)
              ..sort((a, b) => (b.minuto ?? -1).compareTo(a.minuto ?? -1));
            return items.asMap().entries.map((entry) {
              final index = entry.key;
              final gol = entry.value;
              return _AnimatedGoalTile(
                index: index,
                gol: gol,
                teamName: _teamNameById(partida, gol.timeId),
                teamColor: _teamColorById(partida, gol.timeId),
                onDelete: _saving ? null : () => _deleteGol(gol.id),
              );
            });
          })(),
      ],
    );
  }

  Widget _buildActionsSection(Partida? partida) {
    final status = partida?.status ?? '';
    final canStart = !_saving && status == 'agendada';
    final canFinish = !_saving && status == 'em_andamento';
    final canGoal = !_saving && partida != null;

    return CyberCard(
      child: Column(
        children: [
          _OverviewRow(
            label: 'Iniciar',
            value: canStart ? 'Dispon\u00edvel' : 'Indispon\u00edvel',
            valueColor: canStart ? AppTheme.primary : AppTheme.textMuted,
          ),
          const SizedBox(height: 8),
          _OverviewRow(
            label: 'Finalizar',
            value: canFinish ? 'Dispon\u00edvel' : 'Indispon\u00edvel',
            valueColor: canFinish ? AppTheme.primary : AppTheme.textMuted,
          ),
          const SizedBox(height: 8),
          _OverviewRow(
            label: 'Registrar gol',
            value: canGoal ? 'Dispon\u00edvel' : 'Indispon\u00edvel',
            valueColor: canGoal ? AppTheme.primary : AppTheme.textMuted,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partida = _partida;
    final elapsedLabel = _elapsedLabel(partida);

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Detalhes da partida'),
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
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    children: [
                      if (partida != null)
                        _MatchScoreboardHeader(
                          partida: partida,
                          config: widget.config,
                          dateLabel: _formatDateTime(
                            partida.dataHora ?? partida.inicio,
                          ),
                          statusLabel: _statusLabel(partida.status),
                          elapsedLabel: elapsedLabel,
                          homeEvents: _goalEventsForTeam(
                            partida,
                            partida.timeCasaId,
                          ),
                          awayEvents: _goalEventsForTeam(
                            partida,
                            partida.timeForaId,
                          ),
                        )
                      else
                        const CyberCard(
                          child: Text('Partida indispon\u00edvel no momento.'),
                        ),
                      const SizedBox(height: 14),
                      _buildSectionTabs(),
                      const SizedBox(height: 12),
                      switch (_contentTabIndex) {
                        0 => _buildOverviewSection(partida, elapsedLabel),
                        1 => _buildGoalsSection(partida),
                        _ => _buildActionsSection(partida),
                      },
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _MatchActionBar(
                    status: partida?.status ?? '',
                    saving: _saving,
                    onStart: _iniciarPartida,
                    onFinish: _finalizarPartida,
                    onAddGoal: _openRegistrarGolDialog,
                  ),
                ),
              ],
            ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.label,
    required this.value,
    this.valueColor = AppTheme.textPrimary,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TeamTabSelector extends StatelessWidget {
  const _TeamTabSelector({
    required this.homeLabel,
    required this.awayLabel,
    required this.homeId,
    required this.awayId,
    required this.selectedId,
    required this.onChanged,
  });

  final String homeLabel;
  final String awayLabel;
  final int homeId;
  final int awayId;
  final int selectedId;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorderSoft),
      ),
      child: Row(
        children: [
          _TeamTabItem(
            label: homeLabel,
            selected: selectedId == homeId,
            onTap: onChanged == null ? null : () => onChanged!(homeId),
          ),
          const SizedBox(width: 6),
          _TeamTabItem(
            label: awayLabel,
            selected: selectedId == awayId,
            onTap: onChanged == null ? null : () => onChanged!(awayId),
          ),
        ],
      ),
    );
  }
}

class _TeamTabItem extends StatelessWidget {
  const _TeamTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchActionBar extends StatelessWidget {
  const _MatchActionBar({
    required this.status,
    required this.saving,
    required this.onStart,
    required this.onFinish,
    required this.onAddGoal,
  });

  final String status;
  final bool saving;
  final VoidCallback onStart;
  final VoidCallback onFinish;
  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) {
    final canStart = !saving && status == 'agendada';
    final canFinish = !saving && status == 'em_andamento';
    final canAddGoal = !saving;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionPillButton(
                label: 'Iniciar',
                icon: Icons.play_arrow_rounded,
                enabled: canStart,
                onTap: onStart,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionPillButton(
                label: 'Finalizar',
                icon: Icons.stop_rounded,
                enabled: canFinish,
                onTap: onFinish,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ActionPillButton(
          label: saving ? 'Salvando...' : 'Registrar Gol',
          icon: Icons.sports_soccer_rounded,
          enabled: canAddGoal,
          onTap: onAddGoal,
          primary: true,
          fullWidth: true,
        ),
      ],
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.primary = false,
    this.fullWidth = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool primary;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final background = primary ? AppTheme.primary : AppTheme.surface;
    final textColor = primary ? Colors.white : AppTheme.textPrimary;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: enabled ? background : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? Colors.transparent : AppTheme.surfaceBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: enabled ? textColor : AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: enabled ? textColor : AppTheme.textSoft,
            ),
          ),
        ],
      ),
    );

    return IgnorePointer(
      ignoring: !enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }
}

class _PickerFieldButton extends StatefulWidget {
  const _PickerFieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool enabled;
  final Future<void> Function() onTap;

  @override
  State<_PickerFieldButton> createState() => _PickerFieldButtonState();
}

class _PickerFieldButtonState extends State<_PickerFieldButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && _hovered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.enabled ? () => widget.onTap() : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? (active ? AppTheme.surface : AppTheme.surfaceAlt)
                      : AppTheme.surfaceAlt.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? AppTheme.primary : AppTheme.surfaceBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 18,
                      color: widget.enabled
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.enabled
                              ? AppTheme.textPrimary
                              : AppTheme.textMuted.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      color: widget.enabled
                          ? (active ? AppTheme.primary : AppTheme.textSoft)
                          : AppTheme.textMuted.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HoverPlayerOptionTile extends StatefulWidget {
  const _HoverPlayerOptionTile({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_HoverPlayerOptionTile> createState() => _HoverPlayerOptionTileState();
}

class _HoverPlayerOptionTileState extends State<_HoverPlayerOptionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _hovered;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.selected
                    ? const Color(0x1A18C76F)
                    : (highlighted ? AppTheme.surfaceAlt : AppTheme.surface),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.selected
                      ? const Color(0x3518C76F)
                      : AppTheme.surfaceBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.selected
                          ? const Color(0x2A18C76F)
                          : AppTheme.surfaceAlt,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.person_rounded,
                      size: 17,
                      color: widget.selected
                          ? AppTheme.primary
                          : AppTheme.textSoft.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.selected
                                ? AppTheme.textPrimary
                                : AppTheme.textSoft,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: widget.selected ? 1 : 0.35,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      widget.selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 18,
                      color: widget.selected
                          ? AppTheme.primary
                          : AppTheme.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedGoalTile extends StatelessWidget {
  const _AnimatedGoalTile({
    required this.index,
    required this.gol,
    required this.teamName,
    required this.teamColor,
    required this.onDelete,
  });

  final int index;
  final GolEvent gol;
  final String teamName;
  final Color teamColor;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scorer = gol.jogadorNome ?? 'Jogador #${gol.jogadorId}';
    final minute = gol.minuto != null ? "${gol.minuto}'" : '--';
    final assist = gol.assistenciaNome;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index * 90)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: CyberCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 66,
              decoration: BoxDecoration(
                color: teamColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x20FF4D5E),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          minute,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                      if (gol.golContra)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1EFF8C3B),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.transparent),
                          ),
                          child: const Text(
                            'GC',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFD8BE),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.sports_soccer_rounded,
                        size: 16,
                        color: AppTheme.textSoft,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          scorer,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (assist != null && assist.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.assistant_rounded,
                          size: 15,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Assist\u00eancia: $assist',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.textMuted,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchScoreboardHeader extends StatelessWidget {
  const _MatchScoreboardHeader({
    required this.partida,
    required this.config,
    required this.dateLabel,
    required this.statusLabel,
    required this.elapsedLabel,
    required this.homeEvents,
    required this.awayEvents,
  });

  final Partida partida;
  final AppConfig config;
  final String dateLabel;
  final String statusLabel;
  final String? elapsedLabel;
  final List<String> homeEvents;
  final List<String> awayEvents;

  bool _isAbsoluteUrl(String? value) {
    final url = value ?? '';
    return url.startsWith('http://') || url.startsWith('https://');
  }

  Color _teamColor(String? raw) {
    final value = (raw ?? '').trim();
    if (value.startsWith('#') && value.length == 7) {
      final parsed = int.tryParse(value.substring(1), radix: 16);
      if (parsed != null) {
        return Color(0xFF000000 | parsed);
      }
    }
    return AppTheme.primary;
  }

  String? _resolveImageUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;

    final resolved = config.resolveApiImageUrl(value);
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    return _isAbsoluteUrl(value) ? value : null;
  }

  String? _teamImageUrl(PartidaTeam? team) {
    final escudo = _resolveImageUrl(team?.escudoUrl);
    if (escudo != null) return escudo;

    final capitao = _resolveImageUrl(team?.imagemDestaqueUrl);
    if (capitao != null) return capitao;

    return null;
  }

  Widget _teamBadge(PartidaTeam? team) {
    final imageUrl = _teamImageUrl(team);
    final color = _teamColor(team?.cor);

    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A1E28),
        border: Border.all(color: Colors.transparent),
      ),
      alignment: Alignment.center,
      child: CircleAvatar(
        radius: 26,
        backgroundColor: color.withValues(alpha: 0.16),
        child: ClipOval(
          child: SizedBox(
            width: 52,
            height: 52,
            child: imageUrl == null
                ? Icon(Icons.shield_rounded, color: color, size: 24)
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.shield_rounded, color: color, size: 24),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasEvents = homeEvents.isNotEmpty || awayEvents.isNotEmpty;
    final homeTop = homeEvents.take(4).toList();
    final awayTop = awayEvents.take(4).toList();
    final accentColor = partida.status == 'finalizada'
        ? const Color(0xFFE14A52)
        : AppTheme.primary;

    return CyberCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _teamBadge(partida.timeCasa),
                    const SizedBox(height: 8),
                    Text(
                      partida.timeCasa?.nome ?? 'Time Casa',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Casa',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    '${partida.scoreCasa} - ${partida.scoreFora}',
                    style: const TextStyle(
                      fontSize: 42,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      color: AppTheme.textSoft,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 34,
                    height: 3,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  if (elapsedLabel != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Tempo $elapsedLabel',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    _teamBadge(partida.timeFora),
                    const SizedBox(height: 8),
                    Text(
                      partida.timeFora?.nome ?? 'Time Visitante',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Visitante',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasEvents) ...[
            const SizedBox(height: 14),
            const Divider(color: AppTheme.surfaceBorder, height: 1),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: homeTop
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              item,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.sports_soccer_rounded,
                    size: 15,
                    color: AppTheme.textMuted,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: awayTop
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
