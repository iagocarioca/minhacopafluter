import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/core/utils/json_parsing.dart';
import 'package:frontcopa_flutter/domain/models/ranking.dart';
import 'package:frontcopa_flutter/domain/models/rodada.dart';
import 'package:frontcopa_flutter/domain/models/temporada.dart';
import 'package:frontcopa_flutter/features/rankings/data/rankings_remote_data_source.dart';
import 'package:frontcopa_flutter/features/rodadas/data/rodadas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/temporadas/data/temporadas_remote_data_source.dart';
import 'package:intl/intl.dart';

class PlayerAnnualRankingsPage extends StatefulWidget {
  const PlayerAnnualRankingsPage({
    super.key,
    required this.peladaId,
    required this.temporadaId,
    required this.config,
    required this.rankingsDataSource,
    required this.temporadasDataSource,
    required this.rodadasDataSource,
  });

  final int peladaId;
  final int temporadaId;
  final AppConfig config;
  final RankingsRemoteDataSource rankingsDataSource;
  final TemporadasRemoteDataSource temporadasDataSource;
  final RodadasRemoteDataSource rodadasDataSource;

  @override
  State<PlayerAnnualRankingsPage> createState() =>
      _PlayerAnnualRankingsPageState();
}

class _PlayerAnnualRankingsPageState extends State<PlayerAnnualRankingsPage> {
  static const int _sortTotal = 0;
  static const int _sortGols = 1;
  static const int _sortAssistencias = 2;

  bool _bootLoading = true;
  bool _rankingLoading = false;
  String? _error;
  String? _rankingError;

  int _selectedYear = 0;
  int _selectedTemporadaId = 0;
  int _selectedRodadaId = 0;
  int _selectedSort = _sortTotal;
  bool _filtersExpanded = false;

  List<Temporada> _temporadas = const <Temporada>[];
  List<int> _years = const <int>[];
  List<Rodada> _rodadasTemporadaSelecionada = const <Rodada>[];
  Map<int, int> _numeroRodadaPorId = const <int, int>{};
  List<_PlayerAnnualEntry> _ranking = const <_PlayerAnnualEntry>[];

  final Map<int, _SeasonRankingBundle> _seasonRankingCache =
      <int, _SeasonRankingBundle>{};
  final Map<int, RodadaFullResponse> _rodadaFullCache =
      <int, RodadaFullResponse>{};
  final Map<int, List<Rodada>> _rodadasCache = <int, List<Rodada>>{};
  final Map<int, Map<int, int>> _numeroRodadaCache = <int, Map<int, int>>{};

  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _bootLoading = true;
      _error = null;
    });

    try {
      final response = await widget.temporadasDataSource.listTemporadas(
        peladaId: widget.peladaId,
        page: 1,
        perPage: 200,
      );
      final temporadas = List<Temporada>.from(response.items)
        ..sort(_compareTemporadasDesc);

      final years =
          temporadas
              .map(_extractTemporadaYear)
              .whereType<int>()
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));

      var selectedTemporada = 0;
      if (temporadas.any((item) => item.id == widget.temporadaId)) {
        selectedTemporada = widget.temporadaId;
      }

      final initialYear = selectedTemporada != 0
          ? _extractTemporadaYear(
              temporadas.firstWhere((item) => item.id == selectedTemporada),
            )
          : null;

      setState(() {
        _temporadas = temporadas;
        _years = years;
        _selectedTemporadaId = selectedTemporada;
        _selectedYear = initialYear ?? (years.isNotEmpty ? years.first : 0);
        _selectedRodadaId = 0;
        _rodadasTemporadaSelecionada = const <Rodada>[];
        _numeroRodadaPorId = const <int, int>{};
      });

      if (_selectedTemporadaId != 0) {
        await _ensureRodadasLoaded(_selectedTemporadaId);
      }

      await _loadRanking();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _bootLoading = false);
      }
    }
  }

  Future<void> _ensureRodadasLoaded(int temporadaId) async {
    if (_rodadasCache.containsKey(temporadaId) &&
        _numeroRodadaCache.containsKey(temporadaId)) {
      if (!mounted) return;
      setState(() {
        _rodadasTemporadaSelecionada = _rodadasCache[temporadaId]!;
        _numeroRodadaPorId = _numeroRodadaCache[temporadaId]!;
      });
      return;
    }

    final response = await widget.rodadasDataSource.listRodadas(
      temporadaId: temporadaId,
      page: 1,
      perPage: 200,
    );
    final rodadas = List<Rodada>.from(response.items)
      ..sort(_compareRodadasTemporada);
    final numeroPorId = _buildNumeroRodadaMap(rodadas);

    _rodadasCache[temporadaId] = rodadas;
    _numeroRodadaCache[temporadaId] = numeroPorId;

    if (!mounted) return;
    if (_selectedTemporadaId == temporadaId) {
      setState(() {
        _rodadasTemporadaSelecionada = rodadas;
        _numeroRodadaPorId = numeroPorId;
      });
    }
  }

  Future<_SeasonRankingBundle> _getSeasonBundle(int temporadaId) async {
    final cached = _seasonRankingCache[temporadaId];
    if (cached != null) return cached;

    final result = await Future.wait<List<RankingJogadorEntry>>([
      widget.rankingsDataSource.getRankingArtilheiros(temporadaId),
      widget.rankingsDataSource.getRankingAssistencias(temporadaId),
    ]);

    final bundle = _SeasonRankingBundle(
      temporadaId: temporadaId,
      artilheiros: result[0],
      assistencias: result[1],
    );
    _seasonRankingCache[temporadaId] = bundle;
    return bundle;
  }

  Future<RodadaFullResponse> _getRodadaFullCached(int rodadaId) async {
    final cached = _rodadaFullCache[rodadaId];
    if (cached != null) return cached;
    final response = await widget.rodadasDataSource.getRodadaFull(rodadaId);
    _rodadaFullCache[rodadaId] = response;
    return response;
  }

  Future<void> _loadRanking() async {
    final requestId = ++_requestSerial;
    setState(() {
      _rankingLoading = true;
      _rankingError = null;
    });

    try {
      final merged = <int, _PlayerAnnualEntry>{};
      if (_selectedRodadaId != 0) {
        final rodadaFull = await _getRodadaFullCached(_selectedRodadaId);
        final gols = _parseRodadaRanking(
          rodadaFull.rankingGols,
          assistencias: false,
        );
        final assists = _parseRodadaRanking(
          rodadaFull.rankingAssistencias,
          assistencias: true,
        );
        _mergePlayers(merged, gols, assistencias: false);
        _mergePlayers(merged, assists, assistencias: true);
      } else {
        final temporadasAlvo = _selectedTemporadaId != 0
            ? _temporadas.where((item) => item.id == _selectedTemporadaId)
            : _temporadasFiltradasPorAno;
        final bundles = await Future.wait(
          temporadasAlvo.map((item) => _getSeasonBundle(item.id)),
        );
        for (final bundle in bundles) {
          _mergePlayers(merged, bundle.artilheiros, assistencias: false);
          _mergePlayers(merged, bundle.assistencias, assistencias: true);
        }
      }

      final ranking = _sortRanking(merged.values.toList());

      if (!mounted || requestId != _requestSerial) return;
      setState(() => _ranking = ranking);
    } catch (error) {
      if (!mounted || requestId != _requestSerial) return;
      setState(() => _rankingError = error.toString());
    } finally {
      if (mounted && requestId == _requestSerial) {
        setState(() => _rankingLoading = false);
      }
    }
  }

  Future<void> _onYearSelected(int value) async {
    if (value == _selectedYear) return;

    final filtradas = value == 0
        ? _temporadas
        : _temporadas.where((item) => _extractTemporadaYear(item) == value);
    final temporadaValida = _selectedTemporadaId == 0
        ? true
        : filtradas.any((item) => item.id == _selectedTemporadaId);

    setState(() {
      _selectedYear = value;
      if (!temporadaValida) {
        _selectedTemporadaId = 0;
        _selectedRodadaId = 0;
        _rodadasTemporadaSelecionada = const <Rodada>[];
        _numeroRodadaPorId = const <int, int>{};
      }
    });

    await _loadRanking();
  }

  Future<void> _onTemporadaSelected(int value) async {
    if (value == _selectedTemporadaId) return;

    setState(() {
      _selectedTemporadaId = value;
      _selectedRodadaId = 0;
      _rodadasTemporadaSelecionada = const <Rodada>[];
      _numeroRodadaPorId = const <int, int>{};
    });

    if (value != 0) {
      await _ensureRodadasLoaded(value);
    }
    await _loadRanking();
  }

  Future<void> _onRodadaSelected(int value) async {
    if (value == _selectedRodadaId) return;
    setState(() => _selectedRodadaId = value);
    await _loadRanking();
  }

  void _onSortSelected(int value) {
    if (value == _selectedSort) return;
    setState(() {
      _selectedSort = value;
      _ranking = _sortRanking(List<_PlayerAnnualEntry>.from(_ranking));
    });
  }

  List<_PlayerAnnualEntry> _sortRanking(List<_PlayerAnnualEntry> ranking) {
    ranking.sort((a, b) {
      switch (_selectedSort) {
        case _sortGols:
          final byGols = b.gols.compareTo(a.gols);
          if (byGols != 0) return byGols;
          final byAssists = b.assistencias.compareTo(a.assistencias);
          if (byAssists != 0) return byAssists;
          final byTotal = b.total.compareTo(a.total);
          if (byTotal != 0) return byTotal;
          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        case _sortAssistencias:
          final byAssists = b.assistencias.compareTo(a.assistencias);
          if (byAssists != 0) return byAssists;
          final byGols = b.gols.compareTo(a.gols);
          if (byGols != 0) return byGols;
          final byTotal = b.total.compareTo(a.total);
          if (byTotal != 0) return byTotal;
          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        case _sortTotal:
        default:
          final byTotal = b.total.compareTo(a.total);
          if (byTotal != 0) return byTotal;
          final byGols = b.gols.compareTo(a.gols);
          if (byGols != 0) return byGols;
          final byAssists = b.assistencias.compareTo(a.assistencias);
          if (byAssists != 0) return byAssists;
          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      }
    });
    return ranking;
  }

  void _mergePlayers(
    Map<int, _PlayerAnnualEntry> target,
    List<RankingJogadorEntry> source, {
    required bool assistencias,
  }) {
    for (final item in source) {
      final id = item.jogadorId;
      if (id <= 0) continue;

      final current = target.putIfAbsent(
        id,
        () => _PlayerAnnualEntry(
          jogadorId: id,
          nome: item.jogadorNome,
          fotoUrl: item.jogadorFotoUrl,
          timeNome: item.timeNome,
        ),
      );
      if (current.fotoUrl == null || current.fotoUrl!.isEmpty) {
        current.fotoUrl = item.jogadorFotoUrl;
      }
      if (current.timeNome == null || current.timeNome!.isEmpty) {
        current.timeNome = item.timeNome;
      }
      if (assistencias) {
        current.assistencias += item.quantidade;
      } else {
        current.gols += item.quantidade;
      }
    }
  }

  List<RankingJogadorEntry> _parseRodadaRanking(
    List<Map<String, dynamic>> raw, {
    required bool assistencias,
  }) {
    return raw
        .map((item) {
          final jogador = item.containsKey('jogador')
              ? parseMap(item['jogador'])
              : item;
          final time = parseMap(jogador['time']);
          final quantidade = assistencias
              ? parseInt(item['total_assistencias']) ??
                    parseInt(jogador['total_assistencias']) ??
                    parseInt(item['assistencias']) ??
                    parseInt(item['quantidade']) ??
                    parseInt(item['total']) ??
                    0
              : parseInt(item['total_gols']) ??
                    parseInt(jogador['total_gols']) ??
                    parseInt(item['gols']) ??
                    parseInt(item['quantidade']) ??
                    parseInt(item['total']) ??
                    0;
          return RankingJogadorEntry(
            jogadorId:
                parseInt(jogador['id']) ??
                parseInt(item['jogador_id']) ??
                parseInt(item['id']) ??
                0,
            jogadorNome:
                parseString(jogador['apelido']) ??
                parseString(jogador['nome_completo']) ??
                parseString(item['jogador_nome']) ??
                'Sem nome',
            jogadorFotoUrl:
                parseString(jogador['foto_url']) ??
                parseString(jogador['foto']) ??
                parseString(item['jogador_foto_url']),
            quantidade: quantidade,
            timeNome:
                parseString(jogador['time_nome']) ??
                parseString(time['nome']) ??
                parseString(item['time_nome']),
          );
        })
        .where((item) => item.jogadorId > 0 && item.quantidade > 0)
        .toList();
  }

  DateTime? _parseTemporadaInicio(Temporada temporada) {
    final raw = temporada.inicioMes ?? temporada.inicio;
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int _compareTemporadasDesc(Temporada a, Temporada b) {
    final inicioA = _parseTemporadaInicio(a);
    final inicioB = _parseTemporadaInicio(b);
    if (inicioA != null && inicioB != null) {
      final byDate = inicioB.compareTo(inicioA);
      if (byDate != 0) return byDate;
    } else if (inicioA != null) {
      return -1;
    } else if (inicioB != null) {
      return 1;
    }
    return b.id.compareTo(a.id);
  }

  int? _extractTemporadaYear(Temporada temporada) {
    return _parseTemporadaInicio(temporada)?.year;
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
    return a.id.compareTo(b.id);
  }

  Map<int, int> _buildNumeroRodadaMap(List<Rodada> rodadas) {
    final result = <int, int>{};
    for (var i = 0; i < rodadas.length; i++) {
      result[rodadas[i].id] = i + 1;
    }
    return result;
  }

  List<Temporada> get _temporadasFiltradasPorAno {
    if (_selectedYear == 0) return _temporadas;
    return _temporadas
        .where((item) => _extractTemporadaYear(item) == _selectedYear)
        .toList();
  }

  int get _totalGols => _ranking.fold<int>(0, (sum, item) => sum + item.gols);
  int get _totalAssistencias =>
      _ranking.fold<int>(0, (sum, item) => sum + item.assistencias);
  int get _totalContribuicoes =>
      _ranking.fold<int>(0, (sum, item) => sum + item.total);

  String _temporadaLabel(Temporada temporada) {
    final year = _extractTemporadaYear(temporada);
    if (year == null) return 'Temporada ${temporada.id}';
    return 'Temporada $year';
  }

  String _formatDateShort(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM').format(parsed);
  }

  String _rodadaLabel(Rodada rodada) {
    final numero = _numeroRodadaPorId[rodada.id] ?? rodada.numero ?? rodada.id;
    final raw = rodada.dataRodada.isNotEmpty ? rodada.dataRodada : rodada.data;
    final date = _formatDateShort(raw);
    return date == '-' ? 'Rodada $numero' : 'Rodada $numero - $date';
  }

  Future<int?> _showFilterSheet({
    required String title,
    required int selectedValue,
    required List<_IntOption> options,
  }) async {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppTheme.surfaceBorder),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final selected = option.value == selectedValue;
                    return ListTile(
                      title: Text(option.label),
                      subtitle: option.helper == null
                          ? null
                          : Text(option.helper!),
                      trailing: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppTheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(option.value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickYear() async {
    final options = <_IntOption>[
      const _IntOption(value: 0, label: 'Todos os anos'),
      ..._years.map((year) => _IntOption(value: year, label: '$year')),
    ];
    final selected = await _showFilterSheet(
      title: 'Filtrar por ano',
      selectedValue: _selectedYear,
      options: options,
    );
    if (selected == null) return;
    await _onYearSelected(selected);
  }

  Future<void> _pickTemporada() async {
    final temporadas = _temporadasFiltradasPorAno;
    final options = <_IntOption>[
      const _IntOption(value: 0, label: 'Todas as temporadas'),
      ...temporadas.map(
        (item) => _IntOption(
          value: item.id,
          label: _temporadaLabel(item),
          helper: item.status == 'ativa' ? 'Ativa' : 'Encerrada',
        ),
      ),
    ];
    final selected = await _showFilterSheet(
      title: 'Filtrar por temporada',
      selectedValue: _selectedTemporadaId,
      options: options,
    );
    if (selected == null) return;
    await _onTemporadaSelected(selected);
  }

  Future<void> _pickRodada() async {
    if (_selectedTemporadaId == 0) return;
    final options = <_IntOption>[
      const _IntOption(value: 0, label: 'Todas as rodadas'),
      ..._rodadasTemporadaSelecionada.map(
        (item) => _IntOption(value: item.id, label: _rodadaLabel(item)),
      ),
    ];
    final selected = await _showFilterSheet(
      title: 'Filtrar por rodada',
      selectedValue: _selectedRodadaId,
      options: options,
    );
    if (selected == null) return;
    await _onRodadaSelected(selected);
  }

  Future<void> _pickSort() async {
    final options = <_IntOption>[
      const _IntOption(
        value: _sortTotal,
        label: 'Geral (contribuicoes)',
        helper: 'Ordena por gols + assistencias',
      ),
      const _IntOption(
        value: _sortGols,
        label: 'Mais gols',
        helper: 'Prioriza artilheiros',
      ),
      const _IntOption(
        value: _sortAssistencias,
        label: 'Mais assistencias',
        helper: 'Prioriza lideres em passes para gol',
      ),
    ];
    final selected = await _showFilterSheet(
      title: 'Ordenar jogadores por',
      selectedValue: _selectedSort,
      options: options,
    );
    if (selected == null) return;
    _onSortSelected(selected);
  }

  String get _selectedYearLabel =>
      _selectedYear == 0 ? 'Todos os anos' : '$_selectedYear';

  String get _selectedTemporadaLabel {
    if (_selectedTemporadaId == 0) return 'Todas as temporadas';
    final temporada = _temporadas.where(
      (item) => item.id == _selectedTemporadaId,
    );
    if (temporada.isEmpty) return 'Temporada';
    return _temporadaLabel(temporada.first);
  }

  String get _selectedRodadaLabel {
    if (_selectedTemporadaId == 0) return 'Selecione uma temporada';
    if (_selectedRodadaId == 0) return 'Todas as rodadas';
    final rodada = _rodadasTemporadaSelecionada.where(
      (item) => item.id == _selectedRodadaId,
    );
    if (rodada.isEmpty) return 'Todas as rodadas';
    return _rodadaLabel(rodada.first);
  }

  String get _selectedSortLabel {
    switch (_selectedSort) {
      case _sortGols:
        return 'Mais gols';
      case _sortAssistencias:
        return 'Mais assistencias';
      case _sortTotal:
      default:
        return 'Geral (contribuicoes)';
    }
  }

  String get _filtersSummary {
    return 'Ano: $_selectedYearLabel  •  '
        'Temporada: $_selectedTemporadaLabel  •  '
        'Rodada: $_selectedRodadaLabel  •  '
        'Ordem: $_selectedSortLabel';
  }

  void _toggleFilters() {
    setState(() => _filtersExpanded = !_filtersExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        leading: AppBackButton(
          fallbackLocation:
              '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}/rankings',
        ),
        title: const Text('Ranking anual'),
        actions: [
          IconButton(
            tooltip: _filtersExpanded ? 'Ocultar filtros' : 'Mostrar filtros',
            onPressed: _toggleFilters,
            icon: Icon(
              _filtersExpanded
                  ? Icons.filter_alt_off_rounded
                  : Icons.filter_alt_rounded,
            ),
          ),
        ],
      ),
      body: _bootLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _bootstrap,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  CyberCard(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.filter_alt_rounded,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Filtros do ranking',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _toggleFilters,
                              child: Text(
                                _filtersExpanded ? 'Ver menos' : 'Ver mais',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _filtersSummary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_filtersExpanded) ...[
                    const SizedBox(height: 10),
                    CyberCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filtro detalhado',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Refine por ano, temporada, rodada e tipo de ordenacao.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _FilterSelector(
                            label: 'Ano',
                            value: _selectedYearLabel,
                            icon: Icons.calendar_today_rounded,
                            onTap: _pickYear,
                          ),
                          const SizedBox(height: 8),
                          _FilterSelector(
                            label: 'Temporada',
                            value: _selectedTemporadaLabel,
                            icon: Icons.emoji_events_rounded,
                            onTap: _pickTemporada,
                          ),
                          const SizedBox(height: 8),
                          _FilterSelector(
                            label: 'Rodada',
                            value: _selectedRodadaLabel,
                            icon: Icons.flag_rounded,
                            onTap: _selectedTemporadaId == 0
                                ? null
                                : _pickRodada,
                          ),
                          const SizedBox(height: 8),
                          _FilterSelector(
                            label: 'Ordenar por',
                            value: _selectedSortLabel,
                            icon: Icons.sort_rounded,
                            onTap: _pickSort,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.9,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _MetricCard(
                        label: 'Jogadores',
                        value: '${_ranking.length}',
                        icon: Icons.groups_rounded,
                      ),
                      _MetricCard(
                        label: 'Gols',
                        value: '$_totalGols',
                        icon: Icons.sports_soccer_rounded,
                      ),
                      _MetricCard(
                        label: 'Assistencias',
                        value: '$_totalAssistencias',
                        icon: Icons.assistant_rounded,
                      ),
                      _MetricCard(
                        label: 'Contribuicoes',
                        value: '$_totalContribuicoes',
                        icon: Icons.bolt_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CyberCard(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            Expanded(
                              flex: 6,
                              child: Text(
                                'Jogador',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _SmallHeader(label: 'G'),
                            _SmallHeader(label: 'A'),
                            _SmallHeader(label: 'T'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(
                          height: 1,
                          color: AppTheme.surfaceBorderSoft,
                        ),
                        if (_rankingLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 24, bottom: 20),
                            child: CircularProgressIndicator(),
                          ),
                        if (!_rankingLoading && _rankingError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _rankingError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        if (!_rankingLoading &&
                            _rankingError == null &&
                            _ranking.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              'Sem dados para esse filtro.',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ),
                        if (!_rankingLoading &&
                            _rankingError == null &&
                            _ranking.isNotEmpty)
                          ..._ranking.asMap().entries.map((entry) {
                            final posicao = entry.key + 1;
                            final item = entry.value;
                            final foto = widget.config.resolveApiImageUrl(
                              item.fotoUrl,
                            );
                            final top = posicao <= 3;

                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: top
                                    ? const Color(0x1418C76F)
                                    : AppTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: top
                                                ? const Color(0x1F18C76F)
                                                : const Color(0x19000000),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            '$posicao',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: top
                                                  ? AppTheme.primary
                                                  : AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        CircleAvatar(
                                          radius: 15,
                                          backgroundImage: foto != null
                                              ? NetworkImage(foto)
                                              : null,
                                          child: foto == null
                                              ? const Icon(
                                                  Icons.person,
                                                  size: 14,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.nome,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.timeNome ?? 'Sem time',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _StatPill(value: '${item.gols}'),
                                  _StatPill(value: '${item.assistencias}'),
                                  _StatPill(
                                    value: '${item.total}',
                                    highlight: true,
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FilterSelector extends StatelessWidget {
  const _FilterSelector({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: enabled ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: enabled ? AppTheme.textSoft : AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CyberCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0x1A18C76F),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallHeader extends StatelessWidget {
  const _SmallHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.value, this.highlight = false});

  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: highlight ? AppTheme.primary : AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _IntOption {
  const _IntOption({required this.value, required this.label, this.helper});

  final int value;
  final String label;
  final String? helper;
}

class _SeasonRankingBundle {
  const _SeasonRankingBundle({
    required this.temporadaId,
    required this.artilheiros,
    required this.assistencias,
  });

  final int temporadaId;
  final List<RankingJogadorEntry> artilheiros;
  final List<RankingJogadorEntry> assistencias;
}

class _PlayerAnnualEntry {
  _PlayerAnnualEntry({
    required this.jogadorId,
    required this.nome,
    this.fotoUrl,
    this.timeNome,
  });

  final int jogadorId;
  final String nome;
  String? fotoUrl;
  String? timeNome;
  int gols = 0;
  int assistencias = 0;

  int get total => gols + assistencias;
}
