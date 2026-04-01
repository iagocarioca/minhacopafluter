import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/core/widgets/jogador_picker_field.dart';
import 'package:frontcopa_flutter/core/widgets/section_label.dart';
import 'package:frontcopa_flutter/domain/models/jogador.dart';
import 'package:frontcopa_flutter/domain/models/partida.dart';
import 'package:frontcopa_flutter/domain/models/rodada.dart';
import 'package:frontcopa_flutter/domain/models/substituicao.dart';
import 'package:frontcopa_flutter/domain/models/time_model.dart';
import 'package:frontcopa_flutter/domain/models/votacao.dart';
import 'package:frontcopa_flutter/features/jogadores/data/jogadores_remote_data_source.dart';
import 'package:frontcopa_flutter/features/partidas/data/partidas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/rodadas/data/rodadas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/substituicoes/data/substituicoes_remote_data_source.dart';
import 'package:frontcopa_flutter/features/times/data/times_remote_data_source.dart';
import 'package:frontcopa_flutter/features/votacoes/data/votacoes_remote_data_source.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RodadaDetailPage extends StatefulWidget {
  const RodadaDetailPage({
    super.key,
    required this.peladaId,
    required this.rodadaId,
    required this.rodadasDataSource,
    required this.partidasDataSource,
    required this.votacoesDataSource,
    required this.substituicoesDataSource,
    required this.timesDataSource,
    required this.jogadoresDataSource,
  });

  final int peladaId;
  final int rodadaId;
  final RodadasRemoteDataSource rodadasDataSource;
  final PartidasRemoteDataSource partidasDataSource;
  final VotacoesRemoteDataSource votacoesDataSource;
  final SubstituicoesRemoteDataSource substituicoesDataSource;
  final TimesRemoteDataSource timesDataSource;
  final JogadoresRemoteDataSource jogadoresDataSource;

  @override
  State<RodadaDetailPage> createState() => _RodadaDetailPageState();
}

class _RodadaDetailPageState extends State<RodadaDetailPage> {
  final AppConfig _config = AppConfig.fromEnvironment();
  Rodada? _rodada;
  int? _numeroRodadaTemporada;

  List<Partida> _partidas = const <Partida>[];
  List<Votacao> _votacoes = const <Votacao>[];
  List<Substituicao> _substituicoes = const <Substituicao>[];
  List<TimeModel> _times = const <TimeModel>[];
  List<Jogador> _jogadoresPelada = const <Jogador>[];

  bool _loading = true;
  String? _error;
  int _tabIndex = 0;
  String _matchSearch = '';
  String _matchStatusFilter = 'todos';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
      _numeroRodadaTemporada = null;
    });

    try {
      final rodada = await widget.rodadasDataSource.getRodada(widget.rodadaId);
      final results = await Future.wait([
        widget.partidasDataSource.listPartidas(widget.rodadaId),
        widget.votacoesDataSource.listVotacoes(rodadaId: widget.rodadaId),
        widget.substituicoesDataSource.listSubstituicoes(widget.rodadaId),
        widget.timesDataSource.listTimes(
          temporadaId: rodada.temporadaId,
          page: 1,
          perPage: 80,
        ),
        widget.jogadoresDataSource.listJogadores(
          peladaId: widget.peladaId,
          page: 1,
          perPage: 500,
          ativo: true,
        ),
        widget.rodadasDataSource.listRodadas(
          temporadaId: rodada.temporadaId,
          page: 1,
          perPage: 120,
        ),
      ]);

      final rodadasResponse = results[5] as dynamic;
      final rodadasTemporada = List<Rodada>.from(rodadasResponse.items as List);
      final numeroRodada = _resolveNumeroRodadaTemporada(
        rodadasTemporada,
        rodada.id,
      );

      if (!mounted) return;
      setState(() {
        _rodada = rodada;
        _numeroRodadaTemporada = numeroRodada;
        _partidas = results[0] as List<Partida>;
        _votacoes = results[1] as List<Votacao>;
        _substituicoes = results[2] as List<Substituicao>;
        _times = results[3] as List<TimeModel>;
        _jogadoresPelada = (results[4] as dynamic).items as List<Jogador>;
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

  String _formatDateTime(String? value) {
    if (value == null || value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
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

  int _resolveNumeroRodadaTemporada(List<Rodada> rodadas, int rodadaId) {
    if (rodadas.isEmpty) return rodadaId;
    final ordenadas = List<Rodada>.from(rodadas)
      ..sort(_compareRodadasTemporada);
    for (var i = 0; i < ordenadas.length; i++) {
      if (ordenadas[i].id == rodadaId) return i + 1;
    }
    return rodadaId;
  }

  String _votacaoLabel(String tipo) {
    const labels = <String, String>{
      'craque': 'Craque da rodada',
      'destaque': 'Destaque da rodada',
      'goleiro': 'Goleiro da rodada',
      'fair_play': 'Fair Play',
      'mvp': 'MVP',
      'jogador_noite': 'Jogador da noite',
      'goleiro_noite': 'Goleiro da noite',
    };
    return labels[tipo] ?? tipo;
  }

  String _statusLabel(String status) {
    const labels = <String, String>{
      'finalizada': 'Finalizada',
      'em_andamento': 'Em andamento',
      'agendada': 'Agendada',
    };
    return labels[status] ??
        status
            .replaceAll('_', ' ')
            .replaceFirstMapped(
              RegExp(r'^\w'),
              (m) => m.group(0)!.toUpperCase(),
            );
  }

  String _formatKickoff(Partida partida) {
    final raw = partida.dataHora ?? partida.inicio;
    if (raw == null || raw.isEmpty) return 'Sem data definida';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd/MM HH:mm').format(parsed.toLocal());
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

  String? _resolveTeamImage({
    required Partida partida,
    required PartidaTeam? team,
    required int teamId,
  }) {
    final direct = _config.resolveApiImageUrl(team?.escudoUrl);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    for (final time in _times) {
      if (time.id != teamId) continue;
      final timeImage = _config.resolveApiImageUrl(time.escudoUrl);
      if (timeImage != null && timeImage.isNotEmpty) {
        return timeImage;
      }
    }

    for (final gol in partida.gols) {
      if (gol.timeId != teamId) continue;
      final jogadorFoto = _config.resolveApiImageUrl(gol.jogadorFotoUrl);
      if (jogadorFoto != null && jogadorFoto.isNotEmpty) {
        return jogadorFoto;
      }
      final assistFoto = _config.resolveApiImageUrl(gol.assistenciaFotoUrl);
      if (assistFoto != null && assistFoto.isNotEmpty) {
        return assistFoto;
      }
    }

    return null;
  }

  Widget _teamAvatar({
    required PartidaTeam? team,
    required String? imageUrl,
    double size = 58,
  }) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final color = _teamColor(team?.cor);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.transparent),
      ),
      alignment: Alignment.center,
      child: CircleAvatar(
        radius: (size / 2) - 5,
        backgroundColor: color.withValues(alpha: 0.18),
        backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
        child: hasImage
            ? null
            : Icon(Icons.shield_rounded, color: color, size: size * 0.38),
      ),
    );
  }

  List<Partida> _filteredPartidas() {
    final search = _matchSearch.trim().toLowerCase();
    return _partidas.where((partida) {
      final byStatus = switch (_matchStatusFilter) {
        'ao_vivo' => partida.status == 'em_andamento',
        'finalizada' => partida.status == 'finalizada',
        'agendada' => partida.status == 'agendada',
        _ => true,
      };
      if (!byStatus) return false;

      if (search.isEmpty) return true;
      final casa = (partida.timeCasa?.nome ?? '').toLowerCase();
      final fora = (partida.timeFora?.nome ?? '').toLowerCase();
      final data = _formatKickoff(partida).toLowerCase();
      return casa.contains(search) ||
          fora.contains(search) ||
          data.contains(search);
    }).toList();
  }

  Future<void> _openCreatePartidaDialog() async {
    if (_times.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre ao menos 2 times na temporada.'),
        ),
      );
      return;
    }

    int? timeCasaId;
    int? timeForaId;
    String? localError;
    bool creating = false;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nova partida'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: timeCasaId,
                    items: _times
                        .map(
                          (time) => DropdownMenuItem<int>(
                            value: time.id,
                            child: Text(time.nome),
                          ),
                        )
                        .toList(),
                    onChanged: creating
                        ? null
                        : (value) => setDialogState(() => timeCasaId = value),
                    decoration: const InputDecoration(labelText: 'Time casa'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: timeForaId,
                    items: _times
                        .where((time) => time.id != timeCasaId)
                        .map(
                          (time) => DropdownMenuItem<int>(
                            value: time.id,
                            child: Text(time.nome),
                          ),
                        )
                        .toList(),
                    onChanged: creating
                        ? null
                        : (value) => setDialogState(() => timeForaId = value),
                    decoration: const InputDecoration(
                      labelText: 'Time visitante',
                    ),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      localError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
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
                        if (timeCasaId == null || timeForaId == null) {
                          setDialogState(
                            () => localError = 'Selecione os dois times.',
                          );
                          return;
                        }
                        if (timeCasaId == timeForaId) {
                          setDialogState(
                            () => localError = 'Os times devem ser diferentes.',
                          );
                          return;
                        }

                        setDialogState(() {
                          creating = true;
                          localError = null;
                        });

                        try {
                          await widget.partidasDataSource.createPartida(
                            rodadaId: widget.rodadaId,
                            input: PartidaCreateInput(
                              timeCasaId: timeCasaId!,
                              timeForaId: timeForaId!,
                            ),
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await _loadAll();
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
                    : const Text('Criar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCreateVotacaoDialog() async {
    String tipo = 'craque';
    DateTime? abreEm = DateTime.now();
    DateTime? fechaEm = DateTime.now().add(const Duration(days: 1));
    bool creating = false;
    String? localError;

    Future<DateTime?> pickDateTime(DateTime initial) async {
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        locale: const Locale('pt', 'BR'),
      );
      if (date == null || !mounted) return null;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    String toApiDate(DateTime value) =>
        DateFormat("yyyy-MM-ddTHH:mm:ss").format(value);

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nova votação'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: tipo,
                    items: const [
                      DropdownMenuItem(value: 'craque', child: Text('Craque')),
                      DropdownMenuItem(
                        value: 'destaque',
                        child: Text('Destaque'),
                      ),
                      DropdownMenuItem(
                        value: 'goleiro',
                        child: Text('Goleiro'),
                      ),
                      DropdownMenuItem(
                        value: 'fair_play',
                        child: Text('Fair Play'),
                      ),
                    ],
                    onChanged: creating
                        ? null
                        : (value) =>
                              setDialogState(() => tipo = value ?? 'craque'),
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: creating
                        ? null
                        : () async {
                            final picked = await pickDateTime(
                              abreEm ?? DateTime.now(),
                            );
                            if (picked == null) return;
                            setDialogState(() => abreEm = picked);
                          },
                    child: Text(
                      abreEm == null
                          ? 'Data de abertura'
                          : 'Abre: ${_formatDateTime(abreEm!.toIso8601String())}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: creating
                        ? null
                        : () async {
                            final picked = await pickDateTime(
                              fechaEm ?? DateTime.now(),
                            );
                            if (picked == null) return;
                            setDialogState(() => fechaEm = picked);
                          },
                    child: Text(
                      fechaEm == null
                          ? 'Data de fechamento'
                          : 'Fecha: ${_formatDateTime(fechaEm!.toIso8601String())}',
                    ),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      localError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
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
                        if (abreEm == null || fechaEm == null) {
                          setDialogState(
                            () => localError = 'Selecione as duas datas.',
                          );
                          return;
                        }
                        if (fechaEm!.isBefore(abreEm!)) {
                          setDialogState(
                            () => localError =
                                'Fechamento deve ser após abertura.',
                          );
                          return;
                        }
                        setDialogState(() {
                          creating = true;
                          localError = null;
                        });

                        try {
                          await widget.votacoesDataSource.createVotacao(
                            rodadaId: widget.rodadaId,
                            input: VotacaoCreateInput(
                              tipo: tipo,
                              abreEm: toApiDate(abreEm!),
                              fechaEm: toApiDate(fechaEm!),
                            ),
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await _loadAll();
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
                    : const Text('Criar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCreateSubstituicaoDialog() async {
    int? timeId;
    int? jogadorAusenteId;
    int? jogadorSubstitutoId;
    List<Jogador> jogadoresTime = const <Jogador>[];
    bool loadingJogadoresTime = false;
    bool creating = false;
    String? localError;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final substitutos = _jogadoresPelada
              .where((jogador) => jogador.id != jogadorAusenteId)
              .toList();

          Future<void> loadJogadoresDoTime(int selectedTimeId) async {
            setDialogState(() {
              loadingJogadoresTime = true;
              jogadoresTime = const <Jogador>[];
              jogadorAusenteId = null;
              jogadorSubstitutoId = null;
            });
            try {
              final detail = await widget.timesDataSource.getTime(
                selectedTimeId,
              );
              setDialogState(() {
                jogadoresTime = detail.jogadores;
                loadingJogadoresTime = false;
              });
            } catch (_) {
              setDialogState(() {
                jogadoresTime = const <Jogador>[];
                loadingJogadoresTime = false;
              });
            }
          }

          return AlertDialog(
            title: const Text('Nova substituição'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: timeId,
                    items: _times
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
                              timeId = value;
                              jogadorAusenteId = null;
                              jogadorSubstitutoId = null;
                              jogadoresTime = const <Jogador>[];
                            });
                            if (value != null) {
                              await loadJogadoresDoTime(value);
                            }
                          },
                    decoration: const InputDecoration(labelText: 'Time'),
                  ),
                  const SizedBox(height: 10),
                  JogadorPickerField(
                    label: 'Jogador ausente',
                    value: jogadorDisplayNameById(
                      jogadoresTime,
                      jogadorAusenteId,
                      empty: loadingJogadoresTime
                          ? 'Carregando jogadores...'
                          : (jogadoresTime.isEmpty
                                ? 'Sem jogadores neste time'
                                : 'Selecionar jogador'),
                    ),
                    icon: Icons.person_remove_alt_1_rounded,
                    enabled:
                        !creating &&
                        !loadingJogadoresTime &&
                        jogadoresTime.isNotEmpty,
                    onTap: () async {
                      final selected = await showJogadorPickerModal(
                        context: context,
                        title: 'Selecionar jogador ausente',
                        jogadores: jogadoresTime,
                        selectedId: jogadorAusenteId,
                      );
                      if (selected == null || !context.mounted) return;
                      setDialogState(() {
                        jogadorAusenteId = selected;
                        if (jogadorSubstitutoId == selected) {
                          jogadorSubstitutoId = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  JogadorPickerField(
                    label: 'Jogador substituto',
                    value: jogadorDisplayNameById(
                      substitutos,
                      jogadorSubstitutoId,
                      empty: substitutos.isEmpty
                          ? 'Sem jogadores disponíveis'
                          : 'Selecionar jogador',
                    ),
                    icon: Icons.swap_horiz_rounded,
                    enabled: !creating && substitutos.isNotEmpty,
                    onTap: () async {
                      final selected = await showJogadorPickerModal(
                        context: context,
                        title: 'Selecionar jogador substituto',
                        jogadores: substitutos,
                        selectedId: jogadorSubstitutoId,
                      );
                      if (selected == null || !context.mounted) return;
                      setDialogState(() => jogadorSubstitutoId = selected);
                    },
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      localError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
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
                        if (timeId == null ||
                            jogadorAusenteId == null ||
                            jogadorSubstitutoId == null) {
                          setDialogState(
                            () => localError = 'Preencha todos os campos.',
                          );
                          return;
                        }
                        if (jogadorAusenteId == jogadorSubstitutoId) {
                          setDialogState(
                            () => localError = 'Escolha jogadores diferentes.',
                          );
                          return;
                        }

                        setDialogState(() {
                          creating = true;
                          localError = null;
                        });

                        try {
                          await widget.substituicoesDataSource
                              .createSubstituicao(
                                rodadaId: widget.rodadaId,
                                input: SubstituicaoCreateInput(
                                  timeId: timeId!,
                                  jogadorAusenteId: jogadorAusenteId!,
                                  jogadorSubstitutoId: jogadorSubstitutoId!,
                                ),
                              );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await _loadAll();
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

  Future<void> _deleteSubstituicao(int substituicaoId) async {
    try {
      await widget.substituicoesDataSource.deleteSubstituicao(substituicaoId);
      if (!mounted) return;
      await _loadAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _buildPartidasTab() {
    final partidas = _filteredPartidas();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SectionLabel(label: 'Partidas'),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => _matchSearch = value),
          decoration: InputDecoration(
            hintText: 'Buscar por time ou data',
            prefixIcon: Icon(Icons.search_rounded),
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.1),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _MatchStatusChip(
                label: 'Todas',
                selected: _matchStatusFilter == 'todos',
                onTap: () => setState(() => _matchStatusFilter = 'todos'),
              ),
              const SizedBox(width: 8),
              _MatchStatusChip(
                label: 'Ao vivo',
                selected: _matchStatusFilter == 'ao_vivo',
                onTap: () => setState(() => _matchStatusFilter = 'ao_vivo'),
              ),
              const SizedBox(width: 8),
              _MatchStatusChip(
                label: 'Finalizadas',
                selected: _matchStatusFilter == 'finalizada',
                onTap: () => setState(() => _matchStatusFilter = 'finalizada'),
              ),
              const SizedBox(width: 8),
              _MatchStatusChip(
                label: 'Agendadas',
                selected: _matchStatusFilter == 'agendada',
                onTap: () => setState(() => _matchStatusFilter = 'agendada'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_partidas.isEmpty)
          const _InlineEmptyState(
            icon: Icons.sports_soccer_rounded,
            message: 'Nenhuma partida cadastrada para esta rodada.',
          ),
        if (_partidas.isNotEmpty && partidas.isEmpty)
          const _InlineEmptyState(
            icon: Icons.filter_alt_off_rounded,
            message: 'Nenhuma partida encontrada com esse filtro.',
          ),
        ...partidas.map((partida) {
          final status = _statusLabel(partida.status);
          final isLive = partida.status == 'em_andamento';
          final isEnded = partida.status == 'finalizada';
          final statusBg = isLive
              ? const Color(0x1A18C76F)
              : isEnded
              ? const Color(0x147A8597)
              : const Color(0x163B82F6);
          final statusColor = isLive
              ? const Color(0xFF0F9F55)
              : isEnded
              ? AppTheme.textMuted
              : AppTheme.info;
          final scoreAccent = isEnded
              ? const Color(0xFFE14A52)
              : AppTheme.primary;
          final homeImage = _resolveTeamImage(
            partida: partida,
            team: partida.timeCasa,
            teamId: partida.timeCasaId,
          );
          final awayImage = _resolveTeamImage(
            partida: partida,
            team: partida.timeFora,
            teamId: partida.timeForaId,
          );

          return CyberCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            onTap: () => context.push(
              '/peladas/${widget.peladaId}/partidas/${partida.id}',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        color: const Color(0x1A7A8597),
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        size: 13.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatKickoff(partida),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        size: 17,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _teamAvatar(
                            team: partida.timeCasa,
                            imageUrl: homeImage,
                            size: 50,
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 104,
                            child: Text(
                              partida.timeCasa?.nome ?? 'Time casa',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 92,
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${partida.scoreCasa} - ${partida.scoreFora}',
                              style: const TextStyle(
                                fontSize: 32,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 26,
                            height: 3,
                            decoration: BoxDecoration(
                              color: scoreAccent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        children: [
                          _teamAvatar(
                            team: partida.timeFora,
                            imageUrl: awayImage,
                            size: 50,
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 104,
                            child: Text(
                              partida.timeFora?.nome ?? 'Time visitante',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVotacoesTab() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel(label: 'Votações'),
            OutlinedButton.icon(
              onPressed: _openCreateVotacaoDialog,
              icon: const Icon(Icons.how_to_vote_rounded, size: 18),
              label: const Text('Nova votação'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_votacoes.isEmpty)
          const _InlineEmptyState(
            icon: Icons.how_to_vote_rounded,
            message: 'Ainda não existe votação nesta rodada.',
          ),
        ..._votacoes.map((votacao) {
          return CyberCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => context.push(
              '/peladas/${widget.peladaId}/votacoes/${votacao.id}',
            ),
            child: Row(
              children: [
                const Icon(Icons.how_to_vote_rounded, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _votacaoLabel(votacao.tipo),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${votacao.status.toUpperCase()} - Fecha em: ${_formatDateTime(votacao.fechaEm)}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSubstituicoesTab() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionLabel(label: 'Substituições'),
            OutlinedButton.icon(
              onPressed: _openCreateSubstituicaoDialog,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Nova substituição'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_substituicoes.isEmpty)
          const _InlineEmptyState(
            icon: Icons.swap_horiz_rounded,
            message: 'Nenhuma substituição registrada nesta rodada.',
          ),
        ..._substituicoes.map((substituicao) {
          return CyberCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${substituicao.jogadorAusente.nomeExibicao} -> ${substituicao.jogadorSubstituto.nomeExibicao}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time #${substituicao.timeId} - ${_formatDateTime(substituicao.criadoEm)}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteSubstituicao(substituicao.id),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMainTabButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final selected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0x1A18C76F) : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppTheme.primary : AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppTheme.textPrimary : AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildMainTabButton(
            index: 0,
            label: 'Partidas',
            icon: Icons.flag_rounded,
          ),
          const SizedBox(width: 6),
          _buildMainTabButton(
            index: 1,
            label: 'Votações',
            icon: Icons.star_rounded,
          ),
          const SizedBox(width: 6),
          _buildMainTabButton(
            index: 2,
            label: 'Substituições',
            icon: Icons.swap_horiz_rounded,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final numeroRodadaAtual =
        _numeroRodadaTemporada ?? _rodada?.numero ?? _rodada?.id;
    final rodadaTitulo = _rodada == null
        ? 'Rodada'
        : 'Rodada $numeroRodadaAtual';
    final rodadaFinalizada = _rodada?.status == 'finalizada';

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: Text(rodadaTitulo),
        centerTitle: true,
      ),
      floatingActionButton: !_loading && _error == null && _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openCreatePartidaDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova partida'),
            )
          : null,
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: CyberCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0x1A18C76F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x4018C76F)),
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
                                rodadaTitulo.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 13,
                                    color: AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _rodada == null
                                          ? '-'
                                          : _formatDateTime(
                                              _rodada?.dataRodada.isNotEmpty ==
                                                      true
                                                  ? _rodada?.dataRodada
                                                  : _rodada?.data,
                                            ),
                                      style: const TextStyle(
                                        color: AppTheme.textSoft,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: rodadaFinalizada
                                ? const Color(0x1A18C76F)
                                : AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: rodadaFinalizada
                                  ? const Color(0x4018C76F)
                                  : AppTheme.surfaceBorderSoft,
                            ),
                          ),
                          child: Icon(
                            rodadaFinalizada
                                ? Icons.check_rounded
                                : Icons.schedule_rounded,
                            size: 18,
                            color: rodadaFinalizada
                                ? AppTheme.primary
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildMainTabs(),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RefreshIndicator(
                      onRefresh: _loadAll,
                      child: switch (_tabIndex) {
                        0 => _buildPartidasTab(),
                        1 => _buildVotacoesTab(),
                        _ => _buildSubstituicoesTab(),
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Icon(icon, size: 46, color: const Color(0xFF98A0AF)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF98A0AF)),
          ),
        ],
      ),
    );
  }
}

class _MatchStatusChip extends StatelessWidget {
  const _MatchStatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0x2018C76F) : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0x4518C76F) : AppTheme.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.primary : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
