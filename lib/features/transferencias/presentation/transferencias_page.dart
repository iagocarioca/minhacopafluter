import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/core/widgets/jogador_picker_field.dart';
import 'package:frontcopa_flutter/core/widgets/section_label.dart';
import 'package:frontcopa_flutter/domain/models/jogador.dart';
import 'package:frontcopa_flutter/domain/models/temporada.dart';
import 'package:frontcopa_flutter/domain/models/time_model.dart';
import 'package:frontcopa_flutter/domain/models/transferencia.dart';
import 'package:frontcopa_flutter/features/times/data/times_remote_data_source.dart';
import 'package:frontcopa_flutter/features/transferencias/data/transferencias_remote_data_source.dart';
import 'package:intl/intl.dart';

class TransferenciasPage extends StatefulWidget {
  const TransferenciasPage({
    super.key,
    required this.temporadaId,
    required this.transferenciasDataSource,
    required this.timesDataSource,
  });

  final int temporadaId;
  final TransferenciasRemoteDataSource transferenciasDataSource;
  final TimesRemoteDataSource timesDataSource;

  @override
  State<TransferenciasPage> createState() => _TransferenciasPageState();
}

class _TransferenciasPageState extends State<TransferenciasPage> {
  List<Transferencia> _transferencias = const <Transferencia>[];
  List<TimeModel> _times = const <TimeModel>[];
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
      final results = await Future.wait([
        widget.transferenciasDataSource.listTransferencias(
          temporadaId: widget.temporadaId,
          page: 1,
          perPage: 200,
        ),
        widget.timesDataSource.listTimes(
          temporadaId: widget.temporadaId,
          page: 1,
          perPage: 200,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _transferencias = (results[0] as dynamic).items as List<Transferencia>;
        _times = results[1] as List<TimeModel>;
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
    if (value == null || value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
  }

  Future<void> _reverter(Transferencia transferencia) async {
    try {
      await widget.transferenciasDataSource.revertTransferencia(
        temporadaId: widget.temporadaId,
        transferencia: transferencia,
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openCreateDialog() async {
    int? timeOrigemId;
    int? timeDestinoId;
    int? jogadorOrigemId;
    int? jogadorDestinoId;

    List<Jogador> jogadoresOrigem = const <Jogador>[];
    List<Jogador> jogadoresDestino = const <Jogador>[];
    bool loadingJogadoresOrigem = false;
    bool loadingJogadoresDestino = false;
    bool creating = false;
    String? localError;

    Future<List<Jogador>> carregarJogadoresTime(int timeId) async {
      try {
        final data = await widget.transferenciasDataSource.getJogadoresTime(
          temporadaId: widget.temporadaId,
          timeId: timeId,
        );
        final limpos = data
            .where((jogador) => jogador.id > 0)
            .map(
              (jogador) => Jogador(
                id: jogador.id,
                apelido: jogador.apelido,
                nomeCompleto: jogador.nomeCompleto,
                peladaId: jogador.peladaId,
                telefone: jogador.telefone,
                fotoUrl: jogador.fotoUrl,
                posicao: jogador.posicao,
                capitao: jogador.capitao,
                timeId: jogador.timeId ?? timeId,
                timeNome: jogador.timeNome,
                timeEscudoUrl: jogador.timeEscudoUrl,
                ativo: jogador.ativo,
                criadoEm: jogador.criadoEm,
              ),
            )
            .toList();
        if (limpos.isNotEmpty) return limpos;
      } catch (_) {}

      try {
        final detalhe = await widget.timesDataSource.getTime(timeId);
        final fallback = detalhe.jogadores
            .where((jogador) => jogador.id > 0)
            .toList();
        return fallback;
      } catch (_) {
        return const <Jogador>[];
      }
    }

    Future<void> loadJogadoresOrigem(StateSetter setDialogState) async {
      if (timeOrigemId == null) {
        setDialogState(() {
          jogadoresOrigem = const <Jogador>[];
          jogadorOrigemId = null;
          loadingJogadoresOrigem = false;
        });
        return;
      }

      setDialogState(() {
        loadingJogadoresOrigem = true;
        jogadoresOrigem = const <Jogador>[];
        jogadorOrigemId = null;
        localError = null;
      });

      final data = await carregarJogadoresTime(timeOrigemId!);
      setDialogState(() {
        jogadoresOrigem = data;
        loadingJogadoresOrigem = false;
      });
    }

    Future<void> loadJogadoresDestino(StateSetter setDialogState) async {
      if (timeDestinoId == null) {
        setDialogState(() {
          jogadoresDestino = const <Jogador>[];
          jogadorDestinoId = null;
          loadingJogadoresDestino = false;
        });
        return;
      }

      setDialogState(() {
        loadingJogadoresDestino = true;
        jogadoresDestino = const <Jogador>[];
        jogadorDestinoId = null;
        localError = null;
      });

      final data = await carregarJogadoresTime(timeDestinoId!);
      setDialogState(() {
        jogadoresDestino = data;
        loadingJogadoresDestino = false;
      });
    }

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final timesOrigem = _times;
          final timesDestino = _times
              .where((time) => time.id != timeOrigemId)
              .toList();

          return AlertDialog(
            title: const Text('Nova transferência'),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: timeOrigemId,
                      items: timesOrigem
                          .map(
                            (time) => DropdownMenuItem<int>(
                              value: time.id,
                              child: Text(time.nome),
                            ),
                          )
                          .toList(),
                      onChanged: creating
                          ? null
                          : (value) async {
                              setDialogState(() {
                                timeOrigemId = value;
                                jogadorOrigemId = null;
                                jogadoresOrigem = const <Jogador>[];
                              });
                              await loadJogadoresOrigem(setDialogState);
                            },
                      decoration: const InputDecoration(
                        labelText: 'Time origem',
                      ),
                    ),
                    const SizedBox(height: 10),
                    JogadorPickerField(
                      label: 'Jogador origem',
                      value: jogadorDisplayNameById(
                        jogadoresOrigem,
                        jogadorOrigemId,
                        empty: loadingJogadoresOrigem
                            ? 'Carregando jogadores...'
                            : (jogadoresOrigem.isEmpty
                                  ? 'Sem jogadores neste time'
                                  : 'Selecionar jogador'),
                      ),
                      icon: Icons.person_search_rounded,
                      enabled:
                          !creating &&
                          !loadingJogadoresOrigem &&
                          jogadoresOrigem.isNotEmpty,
                      onTap: () async {
                        final selected = await showJogadorPickerModal(
                          context: context,
                          title: 'Selecionar jogador origem',
                          jogadores: jogadoresOrigem,
                          selectedId: jogadorOrigemId,
                        );
                        if (selected == null || !context.mounted) return;
                        setDialogState(() => jogadorOrigemId = selected);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: timeDestinoId,
                      items: timesDestino
                          .map(
                            (time) => DropdownMenuItem<int>(
                              value: time.id,
                              child: Text(time.nome),
                            ),
                          )
                          .toList(),
                      onChanged: creating
                          ? null
                          : (value) async {
                              setDialogState(() {
                                timeDestinoId = value;
                                jogadorDestinoId = null;
                                jogadoresDestino = const <Jogador>[];
                              });
                              await loadJogadoresDestino(setDialogState);
                            },
                      decoration: const InputDecoration(
                        labelText: 'Time destino',
                      ),
                    ),
                    const SizedBox(height: 10),
                    JogadorPickerField(
                      label: 'Jogador destino',
                      value: jogadorDisplayNameById(
                        jogadoresDestino,
                        jogadorDestinoId,
                        empty: loadingJogadoresDestino
                            ? 'Carregando jogadores...'
                            : (jogadoresDestino.isEmpty
                                  ? 'Sem jogadores neste time'
                                  : 'Selecionar jogador'),
                      ),
                      icon: Icons.person_search_rounded,
                      enabled:
                          !creating &&
                          !loadingJogadoresDestino &&
                          jogadoresDestino.isNotEmpty,
                      onTap: () async {
                        final selected = await showJogadorPickerModal(
                          context: context,
                          title: 'Selecionar jogador destino',
                          jogadores: jogadoresDestino,
                          selectedId: jogadorDestinoId,
                        );
                        if (selected == null || !context.mounted) return;
                        setDialogState(() => jogadorDestinoId = selected);
                      },
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        localError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: creating ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: creating
                    ? null
                    : () async {
                        if (timeOrigemId == null ||
                            timeDestinoId == null ||
                            jogadorOrigemId == null ||
                            jogadorDestinoId == null) {
                          setDialogState(
                            () => localError = 'Preencha todos os campos.',
                          );
                          return;
                        }
                        if (timeOrigemId == timeDestinoId) {
                          setDialogState(
                            () => localError =
                                'Os times precisam ser diferentes.',
                          );
                          return;
                        }

                        setDialogState(() {
                          creating = true;
                          localError = null;
                        });

                        try {
                          await widget.transferenciasDataSource
                              .createTransferencia(
                                temporadaId: widget.temporadaId,
                                input: TransferenciaCreateInput(
                                  timeOrigemId: timeOrigemId!,
                                  timeDestinoId: timeDestinoId!,
                                  jogadorOrigemId: jogadorOrigemId!,
                                  jogadorDestinoId: jogadorDestinoId!,
                                ),
                              );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await _load();
                        } catch (error) {
                          setDialogState(() => localError = error.toString());
                        } finally {
                          setDialogState(() => creating = false);
                        }
                      },
                child: creating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Temporada'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            CyberCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TRANSFERÊNCIAS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Troque jogadores entre times da temporada',
                    style: TextStyle(color: AppTheme.textSoft, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _times.length < 2 ? null : _openCreateDialog,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionLabel(label: 'Transferências'),
            const SizedBox(height: 10),
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
            if (!_loading && _error == null && _transferencias.isEmpty)
              const CyberCard(child: Text('Nenhuma transferência registrada.')),
            ..._transferencias.map((transferencia) {
              return CyberCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(transferencia.criadoEm),
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TransferRow(
                      nome: transferencia.jogadorOrigem.nomeExibicao,
                      timeAnterior:
                          transferencia.jogadorOrigem.timeAnterior.nome,
                      timeNovo:
                          transferencia.jogadorOrigem.timeNovo?.nome ?? '-',
                      posicao: transferencia.jogadorOrigem.posicao ?? '',
                    ),
                    const SizedBox(height: 6),
                    _TransferRow(
                      nome: transferencia.jogadorDestino.nomeExibicao,
                      timeAnterior:
                          transferencia.jogadorDestino.timeAnterior.nome,
                      timeNovo:
                          transferencia.jogadorDestino.timeNovo?.nome ?? '-',
                      posicao: transferencia.jogadorDestino.posicao ?? '',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reverter devolve ${transferencia.jogadorOrigem.nomeExibicao} ao '
                      '${transferencia.jogadorOrigem.timeAnterior.nome} e '
                      '${transferencia.jogadorDestino.nomeExibicao} ao '
                      '${transferencia.jogadorDestino.timeAnterior.nome}.',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _reverter(transferencia),
                        icon: const Icon(Icons.undo_rounded),
                        label: const Text('Reverter esta transferência'),
                      ),
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

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.nome,
    required this.timeAnterior,
    required this.timeNovo,
    required this.posicao,
  });

  final String nome;
  final String timeAnterior;
  final String timeNovo;
  final String posicao;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nome, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                '$timeAnterior → $timeNovo',
                style: const TextStyle(color: AppTheme.textSoft, fontSize: 12),
              ),
            ],
          ),
        ),
        if (posicao.trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x24FF4D5E),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.transparent),
            ),
            child: Text(
              posicao,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSoft,
              ),
            ),
          ),
      ],
    );
  }
}
