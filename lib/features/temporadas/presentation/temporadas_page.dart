import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_badge.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/domain/models/temporada.dart';
import 'package:frontcopa_flutter/features/temporadas/data/temporadas_remote_data_source.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TemporadasPage extends StatefulWidget {
  const TemporadasPage({
    super.key,
    required this.peladaId,
    required this.dataSource,
  });

  final int peladaId;
  final TemporadasRemoteDataSource dataSource;

  @override
  State<TemporadasPage> createState() => _TemporadasPageState();
}

class _TemporadasPageState extends State<TemporadasPage> {
  List<Temporada> _temporadas = const <Temporada>[];
  Map<int, int> _numeroTemporadaPorId = const <int, int>{};
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
      _numeroTemporadaPorId = const <int, int>{};
    });
    try {
      final response = await widget.dataSource.listTemporadas(
        peladaId: widget.peladaId,
        page: 1,
        perPage: 50,
      );
      final items = List<Temporada>.from(response.items);
      final numeroPorId = _buildNumeroTemporadaMap(items);
      items.sort((a, b) {
        final numeroA = numeroPorId[a.id] ?? 0;
        final numeroB = numeroPorId[b.id] ?? 0;
        return numeroB.compareTo(numeroA);
      });
      if (!mounted) return;
      setState(() {
        _temporadas = items;
        _numeroTemporadaPorId = numeroPorId;
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

  Future<void> _openCreateDialog() async {
    DateTime? inicio;
    DateTime? fim;
    String? createError;
    bool creating = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pick({required bool start}) async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                initialDate: start ? (inicio ?? now) : (fim ?? inicio ?? now),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                locale: const Locale('pt', 'BR'),
              );
              if (selected == null) return;
              setDialogState(() {
                if (start) {
                  inicio = selected;
                } else {
                  fim = selected;
                }
              });
            }

            final dateFormat = DateFormat('dd/MM/yyyy');

            Future<void> submit() async {
              if (creating) return;
              if (inicio == null || fim == null) {
                setDialogState(() {
                  createError = 'Selecione inicio e fim';
                });
                return;
              }
              if (fim!.isBefore(inicio!)) {
                setDialogState(() {
                  createError = 'Data final deve ser maior que inicial';
                });
                return;
              }

              setDialogState(() {
                creating = true;
                createError = null;
              });

              try {
                final formatter = DateFormat('yyyy-MM-dd');
                await widget.dataSource.createTemporada(
                  peladaId: widget.peladaId,
                  input: TemporadaCreateInput(
                    inicio: formatter.format(inicio!),
                    fim: formatter.format(fim!),
                  ),
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              } catch (error) {
                if (!context.mounted) return;
                setDialogState(() => createError = error.toString());
              } finally {
                if (context.mounted) {
                  setDialogState(() => creating = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Nova Temporada'),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: () => pick(start: true),
                      child: Text(
                        inicio == null
                            ? 'Selecionar data de inicio'
                            : 'Inicio: ${dateFormat.format(inicio!)}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => pick(start: false),
                      child: Text(
                        fim == null
                            ? 'Selecionar data de termino'
                            : 'Fim: ${dateFormat.format(fim!)}',
                      ),
                    ),
                    if (createError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        createError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: creating
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: creating ? null : submit,
                  child: creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Criar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && mounted) {
      await _load();
    }
  }

  Future<void> _encerrarTemporada(int id) async {
    try {
      await widget.dataSource.encerrarTemporada(id);
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _excluirTemporada(int id) async {
    try {
      await widget.dataSource.excluirTemporada(id);
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat('dd/MM/yyyy').format(date);
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

  Map<int, int> _buildNumeroTemporadaMap(List<Temporada> temporadas) {
    final ordenadas = List<Temporada>.from(temporadas)
      ..sort(_compareTemporadas);
    final resultado = <int, int>{};
    for (var i = 0; i < ordenadas.length; i++) {
      resultado[ordenadas[i].id] = i + 1;
    }
    return resultado;
  }

  Future<void> _showTemporadaActions(Temporada item) async {
    final ativa = item.status == 'ativa';
    final numero = _numeroTemporadaPorId[item.id] ?? item.id;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF0F1511),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Temporada $numero',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${_formatDate(item.inicioMes ?? item.inicio)} - ${_formatDate(item.fimMes ?? item.fim)}',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ),
                if (ativa)
                  ListTile(
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: const Text('Encerrar temporada'),
                    onTap: () => Navigator.of(context).pop('encerrar'),
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Excluir temporada'),
                  onTap: () => Navigator.of(context).pop('excluir'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'encerrar') {
      await _encerrarTemporada(item.id);
    }
    if (action == 'excluir') {
      await _excluirTemporada(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const SizedBox.shrink(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova temporada'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null && !_loading)
              CyberCard(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (!_loading && _error == null && _temporadas.isEmpty)
              const CyberCard(child: Text('Nenhuma temporada cadastrada')),
            ..._temporadas.map((item) {
              final inicio = _formatDate(item.inicioMes ?? item.inicio);
              final fim = _formatDate(item.fimMes ?? item.fim);
              final ativa = item.status == 'ativa';
              final numero = _numeroTemporadaPorId[item.id] ?? item.id;
              return CyberCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                onTap: () => context.push(
                  '/peladas/${widget.peladaId}/temporadas/${item.id}',
                ),
                onLongPress: () => _showTemporadaActions(item),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF17151C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.transparent),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Temporada $numero',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$inicio - $fim',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CyberBadge(
                          label: ativa ? 'Active' : 'Ended',
                          variant: ativa
                              ? CyberBadgeVariant.active
                              : CyberBadgeVariant.ended,
                        ),
                        if (ativa) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _encerrarTemporada(item.id),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Encerrar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
