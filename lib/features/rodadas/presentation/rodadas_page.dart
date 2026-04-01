import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_badge.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/domain/models/rodada.dart';
import 'package:frontcopa_flutter/domain/models/temporada.dart';
import 'package:frontcopa_flutter/features/rodadas/data/rodadas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/temporadas/data/temporadas_remote_data_source.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RodadasPage extends StatefulWidget {
  const RodadasPage({
    super.key,
    required this.peladaId,
    required this.temporadaId,
    required this.dataSource,
    required this.temporadasDataSource,
  });

  final int peladaId;
  final int temporadaId;
  final RodadasRemoteDataSource dataSource;
  final TemporadasRemoteDataSource temporadasDataSource;

  @override
  State<RodadasPage> createState() => _RodadasPageState();
}

class _RodadasPageState extends State<RodadasPage> {
  List<Rodada> _rodadas = const <Rodada>[];
  Map<int, int> _numeroRodadaPorId = const <int, int>{};
  int? _numeroTemporadaAtual;
  Temporada? _temporada;
  bool _loading = true;
  bool _creating = false;
  String? _error;
  String? _createError;

  DateTime? _dataRodada;
  final _quantidadeTimesController = TextEditingController(text: '2');
  final _jogadoresPorTimeController = TextEditingController(text: '5');

  @override
  void dispose() {
    _quantidadeTimesController.dispose();
    _jogadoresPorTimeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _numeroRodadaPorId = const <int, int>{};
      _numeroTemporadaAtual = null;
    });

    try {
      final results = await Future.wait([
        widget.dataSource.listRodadas(
          temporadaId: widget.temporadaId,
          page: 1,
          perPage: 100,
        ),
        widget.temporadasDataSource.getTemporada(widget.temporadaId),
        widget.temporadasDataSource.listTemporadas(
          peladaId: widget.peladaId,
          page: 1,
          perPage: 100,
        ),
      ]);

      final response = results[0] as dynamic;
      final temporada = results[1] as Temporada;
      final temporadasResponse = results[2] as dynamic;
      final items = List<Rodada>.from(response.items as List);
      final temporadas = List<Temporada>.from(temporadasResponse.items as List);
      final numeros = _buildNumeroRodadaMap(items);
      final numeroTemporada = _resolveNumeroTemporada(
        temporadas,
        widget.temporadaId,
      );
      items.sort((a, b) {
        final numeroA = numeros[a.id] ?? 0;
        final numeroB = numeros[b.id] ?? 0;
        return numeroB.compareTo(numeroA);
      });
      if (!mounted) return;
      setState(() {
        _rodadas = items;
        _numeroRodadaPorId = numeros;
        _numeroTemporadaAtual = numeroTemporada;
        _temporada = temporada;
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

  DateTime? _parseRodadaDate(Rodada rodada) {
    final raw = rodada.dataRodada.isNotEmpty ? rodada.dataRodada : rodada.data;
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int _compareRodadasTemporada(Rodada a, Rodada b) {
    final dateA = _parseRodadaDate(a);
    final dateB = _parseRodadaDate(b);

    if (dateA != null && dateB != null) {
      final byDate = dateA.compareTo(dateB);
      if (byDate != 0) return byDate;
    } else if (dateA != null) {
      return -1;
    } else if (dateB != null) {
      return 1;
    }

    final numeroA = a.numero;
    final numeroB = b.numero;
    if (numeroA != null && numeroB != null) {
      final byNumero = numeroA.compareTo(numeroB);
      if (byNumero != 0) return byNumero;
    } else if (numeroA != null) {
      return -1;
    } else if (numeroB != null) {
      return 1;
    }

    return a.id.compareTo(b.id);
  }

  Map<int, int> _buildNumeroRodadaMap(List<Rodada> rodadas) {
    final ordenadas = List<Rodada>.from(rodadas)
      ..sort(_compareRodadasTemporada);
    final resultado = <int, int>{};
    for (var i = 0; i < ordenadas.length; i++) {
      resultado[ordenadas[i].id] = i + 1;
    }
    return resultado;
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

  Future<void> _openCreateDialog() async {
    _createError = null;
    _dataRodada = DateTime.now();
    _quantidadeTimesController.text = '2';
    _jogadoresPorTimeController.text = '5';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDate() async {
              final selected = await showDatePicker(
                context: context,
                initialDate: _dataRodada ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                locale: const Locale('pt', 'BR'),
              );
              if (selected == null) return;
              setDialogState(() => _dataRodada = selected);
            }

            return AlertDialog(
              title: const Text('Nova Rodada'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: pickDate,
                      icon: const Icon(Icons.event),
                      label: Text(
                        _dataRodada == null
                            ? 'Selecionar data'
                            : DateFormat('dd/MM/yyyy').format(_dataRodada!),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _quantidadeTimesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade de times',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _jogadoresPorTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jogadores por time',
                      ),
                    ),
                    if (_createError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _createError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _creating
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: _creating
                      ? null
                      : () async {
                          await _createRodada();
                          if (!mounted) return;
                          setDialogState(() {});
                        },
                  child: _creating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Criar rodada'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createRodada() async {
    final data = _dataRodada;
    final quantidadeTimes = int.tryParse(
      _quantidadeTimesController.text.trim(),
    );
    final jogadoresPorTime = int.tryParse(
      _jogadoresPorTimeController.text.trim(),
    );

    if (data == null || quantidadeTimes == null || jogadoresPorTime == null) {
      setState(() => _createError = 'Preencha todos os campos corretamente.');
      return;
    }

    if (quantidadeTimes < 2 || jogadoresPorTime < 1) {
      setState(
        () => _createError = 'Quantidade de times e jogadores deve ser válida.',
      );
      return;
    }

    setState(() {
      _creating = true;
      _createError = null;
    });

    try {
      await widget.dataSource.createRodada(
        temporadaId: widget.temporadaId,
        input: RodadaCreateInput(
          dataRodada: DateFormat('yyyy-MM-dd').format(data),
          quantidadeTimes: quantidadeTimes,
          jogadoresPorTime: jogadoresPorTime,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _createError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _deleteRodada(Rodada rodada) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir rodada'),
        content: const Text('Deseja realmente excluir esta rodada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.dataSource.deleteRodada(rodada.id);
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Temporada'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova rodada'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            CyberCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF17151C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Temporada ${_numeroTemporadaAtual ?? widget.temporadaId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _temporada == null
                              ? 'Carregando...'
                              : '${_formatDate(_temporada?.inicioMes ?? _temporada?.inicio)} - ${_formatDate(_temporada?.fimMes ?? _temporada?.fim)}',
                          style: const TextStyle(
                            color: AppTheme.textSoft,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CyberBadge(
                    label: _temporada?.status == 'ativa'
                        ? 'Ativa'
                        : 'Encerrada',
                    variant: _temporada?.status == 'ativa'
                        ? CyberBadgeVariant.active
                        : CyberBadgeVariant.ended,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _NavTile(
                    icon: Icons.groups_rounded,
                    label: 'Gerenciar Times',
                    accentColor: AppTheme.primary,
                    onTap: () => context.push(
                      '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}/times',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NavTile(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Transferências',
                    accentColor: AppTheme.info,
                    onTap: () => context.push(
                      '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}/transferencias',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NavTile(
                    icon: Icons.emoji_events_rounded,
                    label: 'Classificação',
                    accentColor: AppTheme.primary,
                    onTap: () => context.push(
                      '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}/rankings',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Rodadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null && !_loading)
              CyberCard(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (!_loading && _error == null && _rodadas.isEmpty)
              const CyberCard(
                child: Text('Nenhuma rodada cadastrada nessa temporada.'),
              ),
            ..._rodadas.map((rodada) {
              final data = _formatDate(
                rodada.dataRodada.isNotEmpty ? rodada.dataRodada : rodada.data,
              );
              final numero =
                  _numeroRodadaPorId[rodada.id] ?? rodada.numero ?? rodada.id;
              return _RodadaTile(
                numero: numero,
                data: data,
                onTap: () => context.push(
                  '/peladas/${widget.peladaId}/rodadas/${rodada.id}',
                ),
                onLongPress: () => _deleteRodada(rodada),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RodadaTile extends StatefulWidget {
  const _RodadaTile({
    required this.numero,
    required this.data,
    required this.onTap,
    required this.onLongPress,
  });

  final int numero;
  final String data;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_RodadaTile> createState() => _RodadaTileState();
}

class _RodadaTileState extends State<_RodadaTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final titleColor = _hovering ? AppTheme.primary : AppTheme.textPrimary;
    final hintColor = _hovering ? AppTheme.textSoft : AppTheme.textMuted;

    return Tooltip(
      message: 'Toque para abrir. Pressione e segure para excluir.',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          scale: _hovering ? 1.01 : 1,
          child: CyberCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _hovering
                        ? const Color(0xFF1A261A)
                        : AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.transparent),
                  ),
                  child: Text(
                    '${widget.numero}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: titleColor,
                          height: 1.15,
                        ),
                        child: Text('Rodada ${widget.numero}'),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.event_rounded,
                                size: 13,
                                color: AppTheme.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.data,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 13,
                                color: hintColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Abrir',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hintColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedSlide(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  offset: _hovering ? const Offset(0.18, 0) : Offset.zero,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: _hovering ? AppTheme.primary : AppTheme.textMuted,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      glow: false,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF17151C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.transparent),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}
