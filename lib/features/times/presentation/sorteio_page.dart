import 'dart:math';
import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/core/widgets/jogador_picker_field.dart';
import 'package:frontcopa_flutter/domain/models/jogador.dart';
import 'package:frontcopa_flutter/domain/models/time_model.dart';
import 'package:frontcopa_flutter/features/jogadores/data/jogadores_remote_data_source.dart';
import 'package:frontcopa_flutter/features/times/data/times_remote_data_source.dart';
import 'package:go_router/go_router.dart';

class SorteioPage extends StatefulWidget {
  const SorteioPage({
    super.key,
    required this.peladaId,
    required this.temporadaId,
    required this.config,
    required this.timesDataSource,
    required this.jogadoresDataSource,
  });

  final int peladaId;
  final int temporadaId;
  final AppConfig config;
  final TimesRemoteDataSource timesDataSource;
  final JogadoresRemoteDataSource jogadoresDataSource;

  @override
  State<SorteioPage> createState() => _SorteioPageState();
}

class _SorteioPageState extends State<SorteioPage> {
  final Random _random = Random();

  List<TimeModel> _times = const <TimeModel>[];
  List<Jogador> _jogadores = const <Jogador>[];
  bool _loadingTimes = true;
  bool _loadingJogadores = true;
  String? _errorTimes;
  String? _errorJogadores;

  Set<int> _selectedTimes = <int>{};
  Set<int> _selectedJogadores = <int>{};
  Set<int> _selectedGoleiros = <int>{};
  final Map<int, int> _capitaesPorTime = <int, int>{};

  List<SorteioTime> _resultado = <SorteioTime>[];
  String? _sorteioError;
  String? _stepError;
  bool _aplicando = false;
  bool _limparTimesAntes = true;
  int _playersPerTeam = 0;
  int _currentStep = 1;

  @override
  void initState() {
    super.initState();
    _load(keepSelection: false);
  }

  Future<void> _load({required bool keepSelection}) async {
    await _loadTimes(keepSelection: keepSelection);
    await _loadJogadores(keepSelection: keepSelection);
    if (!mounted) return;
    setState(_autoSetPlayersPerTeam);
  }

  Future<void> _loadTimes({required bool keepSelection}) async {
    setState(() {
      _loadingTimes = true;
      _errorTimes = null;
    });

    try {
      final data = await widget.timesDataSource.listTimes(
        temporadaId: widget.temporadaId,
        page: 1,
        perPage: 200,
      );
      if (!mounted) return;
      setState(() {
        _times = data;
        if (!keepSelection || _selectedTimes.isEmpty) {
          _selectedTimes = data.map((time) => time.id).toSet();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorTimes = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingTimes = false);
      }
    }
  }

  Future<void> _loadJogadores({required bool keepSelection}) async {
    setState(() {
      _loadingJogadores = true;
      _errorJogadores = null;
    });

    try {
      final data = await widget.jogadoresDataSource.listJogadores(
        peladaId: widget.peladaId,
        page: 1,
        perPage: 400,
      );
      if (!mounted) return;
      setState(() {
        _jogadores = data.items;
        if (!keepSelection || _selectedJogadores.isEmpty) {
          _selectedJogadores = data.items.map((j) => j.id).toSet();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorJogadores = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingJogadores = false);
      }
    }
  }

  void _autoSetPlayersPerTeam() {
    if (_playersPerTeam > 0) return;
    final totalTimes = _selectedTimes.isNotEmpty
        ? _selectedTimes.length
        : _times.length;
    final totalJogadores = _selectedJogadores.isNotEmpty
        ? _selectedJogadores.length
        : _jogadores.length;
    if (totalTimes > 0 && totalJogadores > 0) {
      _playersPerTeam = max(1, totalJogadores ~/ totalTimes);
    }
  }

  bool get _isLoading => _loadingTimes || _loadingJogadores;

  String? get _errorMessage => _errorTimes ?? _errorJogadores;

  List<TimeModel> get _timesSelecionados =>
      _times.where((time) => _selectedTimes.contains(time.id)).toList();

  List<Jogador> get _jogadoresSelecionados =>
      _jogadores.where((j) => _selectedJogadores.contains(j.id)).toList();

  Set<int> get _goleirosSet => _selectedGoleiros;

  bool get _hasEnoughPlayers =>
      _playersPerTeam > 0 &&
      _selectedTimes.isNotEmpty &&
      _selectedJogadores.length >= _playersPerTeam * _selectedTimes.length;

  String get _jogadoresPorTimeLabel {
    if (_selectedTimes.isEmpty) {
      return 'Selecione os times para calcular a divisao.';
    }
    if (_selectedJogadores.isEmpty) {
      return 'Selecione os jogadores para calcular a divisao.';
    }
    final totalDesejado = _playersPerTeam * _selectedTimes.length;
    if (totalDesejado == _selectedJogadores.length) {
      return '$_playersPerTeam jogadores por time (divisao exata).';
    }
    if (totalDesejado < _selectedJogadores.length) {
      final sobra = _selectedJogadores.length - totalDesejado;
      return '$_playersPerTeam por time. $sobra ficam de fora.';
    }
    final falta = totalDesejado - _selectedJogadores.length;
    return '$_playersPerTeam por time. faltam $falta jogadores.';
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
    return AppTheme.primary;
  }

  void _toggleTime(int timeId) {
    final updated = Set<int>.from(_selectedTimes);
    if (updated.contains(timeId)) {
      updated.remove(timeId);
    } else {
      updated.add(timeId);
    }
    setState(() {
      _selectedTimes = updated;
      _pruneCapitaes();
      _resultado = <SorteioTime>[];
      _stepError = null;
    });
  }

  void _toggleJogador(int jogadorId) {
    final updated = Set<int>.from(_selectedJogadores);
    if (updated.contains(jogadorId)) {
      updated.remove(jogadorId);
    } else {
      updated.add(jogadorId);
    }
    setState(() {
      _selectedJogadores = updated;
      _selectedGoleiros = _selectedGoleiros.intersection(updated);
      _pruneCapitaes();
      _resultado = <SorteioTime>[];
      _stepError = null;
    });
  }

  void _toggleGoleiro(int jogadorId) {
    if (!_selectedJogadores.contains(jogadorId)) return;
    final updated = Set<int>.from(_selectedGoleiros);
    if (updated.contains(jogadorId)) {
      updated.remove(jogadorId);
    } else {
      updated.add(jogadorId);
    }
    setState(() {
      _selectedGoleiros = updated;
      _resultado = <SorteioTime>[];
    });
  }

  void _selectAllJogadores() {
    setState(() {
      _selectedJogadores = _jogadores.map((j) => j.id).toSet();
      _resultado = <SorteioTime>[];
      _stepError = null;
    });
  }

  void _clearJogadores() {
    setState(() {
      _selectedJogadores = <int>{};
      _selectedGoleiros = <int>{};
      _resultado = <SorteioTime>[];
      _stepError = null;
    });
  }

  void _pruneCapitaes() {
    _capitaesPorTime.removeWhere(
      (timeId, jogadorId) =>
          !_selectedTimes.contains(timeId) ||
          !_selectedJogadores.contains(jogadorId),
    );
  }

  void _goToStep(int step) {
    if (step < 1 || step > 4) return;
    setState(() {
      _currentStep = step;
      _stepError = null;
    });
    if (step == 4 && _resultado.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _gerarSorteio();
        }
      });
    }
  }

  void _nextStep() {
    setState(() => _stepError = null);
    if (_currentStep == 1) {
      if (_selectedTimes.isEmpty) {
        setState(() => _stepError = 'Selecione pelo menos um time.');
        return;
      }
      if (_playersPerTeam <= 0) {
        setState(
          () => _stepError = 'Defina a quantidade de jogadores por time.',
        );
        return;
      }
    }
    if (_currentStep == 2) {
      if (!_hasEnoughPlayers) {
        setState(
          () =>
              _stepError = 'Selecione jogadores suficientes para a quantidade.',
        );
        return;
      }
    }
    if (_currentStep == 3) {
      if (_jogadoresSelecionados.isEmpty) {
        setState(() => _stepError = 'Selecione jogadores antes de avancar.');
        return;
      }
      _autoFillCaptains();
      final missing = _timesSelecionados
          .where((time) => !_capitaesPorTime.containsKey(time.id))
          .toList();
      if (missing.isNotEmpty) {
        setState(() => _stepError = 'Nao foi possivel definir capitaes.');
        return;
      }
    }
    final next = min(_currentStep + 1, 4);
    setState(() => _currentStep = next);
    if (next == 4 && _resultado.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _gerarSorteio();
        }
      });
    }
  }

  void _prevStep() {
    setState(() {
      _currentStep = max(1, _currentStep - 1);
      _stepError = null;
    });
  }

  void _resetSorteio() {
    setState(() {
      _selectedTimes = _times.map((t) => t.id).toSet();
      _selectedJogadores = _jogadores.map((j) => j.id).toSet();
      _selectedGoleiros = <int>{};
      _capitaesPorTime.clear();
      _resultado = <SorteioTime>[];
      _sorteioError = null;
      _playersPerTeam = 0;
      _currentStep = 1;
      _stepError = null;
      _autoSetPlayersPerTeam();
    });
  }

  void _autoFillCaptains() {
    final candidatos = _jogadoresSelecionados.map((j) => j.id).toList();
    if (candidatos.isEmpty) return;

    final shuffled = _shuffle(candidatos);
    final used = <int>{};

    _capitaesPorTime.removeWhere(
      (timeId, jogadorId) =>
          !_selectedTimes.contains(timeId) ||
          !candidatos.contains(jogadorId) ||
          used.contains(jogadorId),
    );

    for (final entry in _capitaesPorTime.entries) {
      used.add(entry.value);
    }

    var index = 0;
    for (final time in _timesSelecionados) {
      if (_capitaesPorTime.containsKey(time.id)) continue;
      while (index < shuffled.length && used.contains(shuffled[index])) {
        index += 1;
      }
      int pick;
      if (index < shuffled.length) {
        pick = shuffled[index];
        used.add(pick);
        index += 1;
      } else {
        pick = shuffled[_random.nextInt(shuffled.length)];
      }
      _capitaesPorTime[time.id] = pick;
    }
  }

  List<T> _shuffle<T>(List<T> items) {
    final list = List<T>.from(items);
    for (var i = list.length - 1; i > 0; i -= 1) {
      final j = _random.nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
    return list;
  }

  T? _pickMin<T>(List<T> items, int Function(T) getter) {
    if (items.isEmpty) return null;
    var minValue = 1 << 30;
    final candidates = <T>[];
    for (final item in items) {
      final value = getter(item);
      if (value < minValue) {
        minValue = value;
        candidates
          ..clear()
          ..add(item);
      } else if (value == minValue) {
        candidates.add(item);
      }
    }
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  void _gerarSorteio() {
    setState(() {
      _sorteioError = null;
      _resultado = <SorteioTime>[];
    });

    if (_selectedTimes.isEmpty) {
      setState(() => _sorteioError = 'Selecione pelo menos um time.');
      return;
    }
    if (_jogadoresSelecionados.isEmpty) {
      setState(() => _sorteioError = 'Selecione jogadores para o sorteio.');
      return;
    }
    if (_playersPerTeam <= 0) {
      setState(
        () => _sorteioError = 'Informe a quantidade de jogadores por time.',
      );
      return;
    }

    final totalDesejado = _playersPerTeam * _selectedTimes.length;
    if (_jogadoresSelecionados.length < totalDesejado) {
      setState(
        () => _sorteioError =
            'Jogadores selecionados sao menos que o necessario.',
      );
      return;
    }

    _autoFillCaptains();
    final missingCap = _timesSelecionados
        .where((time) => !_capitaesPorTime.containsKey(time.id))
        .toList();
    if (missingCap.isNotEmpty) {
      setState(() => _sorteioError = 'Nao foi possivel definir capitaes.');
      return;
    }

    final jogadoresMap = {for (final j in _jogadoresSelecionados) j.id: j};
    final assignments = _timesSelecionados
        .map((time) => _SorteioAssignment(time: time))
        .toList();

    final assigned = <int>{};

    for (final assignment in assignments) {
      final capId = _capitaesPorTime[assignment.time.id];
      final jogador = capId == null ? null : jogadoresMap[capId];
      if (jogador == null) continue;
      final isGk = _goleirosSet.contains(jogador.id);
      assignment.jogadores.add(
        SorteioJogador(jogador: jogador, capitao: true, goleiro: isGk),
      );
      assignment.goleiros += isGk ? 1 : 0;
      assigned.add(jogador.id);
    }

    final goleirosDisponiveis = _shuffle(
      _jogadoresSelecionados
          .where((j) => _goleirosSet.contains(j.id) && !assigned.contains(j.id))
          .toList(),
    );

    for (final goleiro in goleirosDisponiveis) {
      final target =
          _pickMin(
            assignments
                .where((a) => a.jogadores.length < _playersPerTeam)
                .toList(),
            (a) => a.goleiros,
          ) ??
          _pickMin(assignments, (a) => a.goleiros);
      if (target == null) continue;
      target.jogadores.add(SorteioJogador(jogador: goleiro, goleiro: true));
      target.goleiros += 1;
      assigned.add(goleiro.id);
    }

    final restantes = _shuffle(
      _jogadoresSelecionados.where((j) => !assigned.contains(j.id)).toList(),
    );
    for (final jogador in restantes) {
      final candidatos = assignments
          .where((a) => a.jogadores.length < _playersPerTeam)
          .toList();
      final target = _pickMin(candidatos, (a) => a.jogadores.length);
      if (target == null) continue;
      target.jogadores.add(
        SorteioJogador(
          jogador: jogador,
          goleiro: _goleirosSet.contains(jogador.id),
        ),
      );
      assigned.add(jogador.id);
    }

    setState(() {
      _resultado = assignments
          .map(
            (assignment) => SorteioTime(
              time: assignment.time,
              jogadores: assignment.jogadores,
            ),
          )
          .toList();
    });
  }

  Future<Map<int, Set<int>>> _loadExistingByTeam(Set<int> teamIds) async {
    final Map<int, Set<int>> existing = <int, Set<int>>{};
    for (final timeId in teamIds) {
      final detail = await widget.timesDataSource.getTime(timeId);
      existing[timeId] = detail.jogadores.map((j) => j.id).toSet();
    }
    return existing;
  }

  Future<void> _aplicarSorteio() async {
    if (_resultado.isEmpty) {
      _gerarSorteio();
    }
    if (_resultado.isEmpty) return;

    setState(() {
      _aplicando = true;
      _sorteioError = null;
    });

    try {
      final selectedTeamIds = Set<int>.from(_selectedTimes);
      final existingByTeam = await _loadExistingByTeam(selectedTeamIds);
      final currentTeamByPlayer = <int, int>{};
      for (final jogador in _jogadoresSelecionados) {
        final timeId = jogador.timeId;
        if (timeId != null) {
          currentTeamByPlayer[jogador.id] = timeId;
        }
      }
      final removedPairs = <String>{};

      if (_limparTimesAntes) {
        for (final timeId in selectedTeamIds) {
          final jogadores = existingByTeam[timeId] ?? <int>{};
          for (final jogadorId in jogadores) {
            await widget.timesDataSource.removeJogador(
              timeId: timeId,
              jogadorId: jogadorId,
            );
            removedPairs.add('$timeId:$jogadorId');
          }
        }
      }

      for (final resultado in _resultado) {
        final timeId = resultado.time.id;
        final existing = existingByTeam[timeId] ?? <int>{};
        for (final item in resultado.jogadores) {
          final playerId = item.jogador.id;
          final currentTeamId = currentTeamByPlayer[playerId];
          if (currentTeamId != null && currentTeamId != timeId) {
            final key = '$currentTeamId:$playerId';
            if (!removedPairs.contains(key)) {
              await widget.timesDataSource.removeJogador(
                timeId: currentTeamId,
                jogadorId: playerId,
              );
              removedPairs.add(key);
            }
          }
          if (!_limparTimesAntes && existing.contains(item.jogador.id)) {
            continue;
          }
          final posicao = item.goleiro
              ? 'Goleiro'
              : (item.jogador.posicao ?? '');
          await widget.timesDataSource.addJogador(
            timeId: timeId,
            jogadorId: item.jogador.id,
            posicao: posicao,
            capitao: item.capitao,
          );
        }
      }

      await _load(keepSelection: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sorteioError = error.toString());
    } finally {
      if (mounted) setState(() => _aplicando = false);
    }
  }

  Map<int, int> _countPlayersByTeam() {
    final counts = <int, int>{};
    for (final jogador in _jogadores) {
      final timeId = jogador.timeId;
      if (timeId == null) continue;
      counts[timeId] = (counts[timeId] ?? 0) + 1;
    }
    return counts;
  }

  Set<int> _usedCaptains(int currentTimeId) {
    final used = <int>{};
    _capitaesPorTime.forEach((timeId, jogadorId) {
      if (timeId != currentTimeId) {
        used.add(jogadorId);
      }
    });
    return used;
  }

  Widget _buildStepChip(int index, String label) {
    final active = _currentStep == index;
    final done = index < _currentStep;
    final borderColor = active
        ? AppTheme.primary.withValues(alpha: 0.42)
        : done
        ? const Color(0xFFBFD7C8)
        : AppTheme.surfaceBorderSoft;
    final background = active
        ? const Color(0xFFE9FFF2)
        : done
        ? const Color(0xFFF0FDF4)
        : AppTheme.surfaceAlt;
    final textColor = active
        ? const Color(0xFF0F8F50)
        : done
        ? const Color(0xFF2A9B62)
        : AppTheme.textMuted;
    final iconColor = active
        ? Colors.white
        : done
        ? const Color(0xFF0F8F50)
        : AppTheme.textMuted;
    return InkWell(
      onTap: () => _goToStep(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primary
                    : done
                    ? const Color(0x1A18C76F)
                    : Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: done && !active
                  ? Icon(Icons.check_rounded, size: 12, color: iconColor)
                  : Text(
                      '$index',
                      style: TextStyle(
                        color: iconColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
            ),
            const SizedBox(width: 7),
            Icon(_stepIcon(index), size: 14, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  IconData _stepIcon(int step) {
    switch (step) {
      case 1:
        return Icons.groups_2_rounded;
      case 2:
        return Icons.sports_soccer_rounded;
      case 3:
        return Icons.workspace_premium_rounded;
      case 4:
        return Icons.emoji_events_rounded;
      default:
        return Icons.radio_button_checked_rounded;
    }
  }

  Widget _buildStepProgressHeader() {
    final progress = (_currentStep / 4).clamp(0.0, 1.0);
    final subtitle = switch (_currentStep) {
      1 => 'Defina os times e quantidade',
      2 => 'Selecione quem joga e goleiros',
      3 => 'Escolha os capitaes dos times',
      _ => 'Revise o resultado e aplique',
    };

    return CyberCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Passo $_currentStep de 4',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE7EDF4),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStepChip(1, 'Times'),
                const SizedBox(width: 8),
                _buildStepChip(2, 'Jogadores'),
                const SizedBox(width: 8),
                _buildStepChip(3, 'Capitaes'),
                const SizedBox(width: 8),
                _buildStepChip(4, 'Resultado'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTimes(Map<int, int> counts, double availableHeight) {
    return CyberCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Times e quantidade',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Escolha os times e quantos jogadores cada um tera.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          if (_times.isEmpty)
            const Text(
              'Nenhum time cadastrado nesta temporada.',
              style: TextStyle(color: AppTheme.textMuted),
            )
          else
            SizedBox(
              height: min(280, availableHeight * 0.35),
              child: ListView.separated(
                itemCount: _times.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final time = _times[index];
                  return _buildTimeOption(time, counts[time.id] ?? 0);
                },
              ),
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Limpar jogadores dos times antes de aplicar'),
            value: _limparTimesAntes,
            onChanged: (value) => setState(() => _limparTimesAntes = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jogadores por time',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _jogadoresPorTimeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: _playersPerTeam <= 1
                        ? null
                        : () => setState(() => _playersPerTeam -= 1),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Container(
                    width: 46,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: Text(
                      '$_playersPerTeam',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _playersPerTeam += 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepJogadores(double availableHeight) {
    return CyberCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '2. Jogadores e goleiros',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _selectAllJogadores,
                  child: const Text('Selecionar todos'),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: _clearJogadores,
                  child: const Text('Limpar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Marque quem participa e destaque os goleiros.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: min(360, availableHeight * 0.5),
              child: ListView.separated(
                itemCount: _jogadores.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _buildJogadorOption(_jogadores[index]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedJogadores.length} jogadores selecionados, ${_selectedGoleiros.length} goleiros.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCapitaes() {
    return CyberCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3. Capitaes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Defina um capitao por time.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            if (_timesSelecionados.isEmpty)
              const Text(
                'Selecione os times antes.',
                style: TextStyle(color: AppTheme.textMuted),
              )
            else
              Column(
                children: _timesSelecionados.map((time) {
                  final used = _usedCaptains(time.id);
                  final candidatos = _jogadoresSelecionados
                      .where(
                        (jogador) =>
                            !used.contains(jogador.id) ||
                            _capitaesPorTime[time.id] == jogador.id,
                      )
                      .toList();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: JogadorPickerField(
                      label: '${time.nome} (capitao)',
                      value: jogadorDisplayNameById(
                        candidatos,
                        _capitaesPorTime[time.id],
                        empty: candidatos.isEmpty
                            ? 'Sem opcoes disponiveis'
                            : 'Selecionar capitao',
                        noneLabel: 'Sem capitao',
                      ),
                      icon: Icons.workspace_premium_outlined,
                      enabled: candidatos.isNotEmpty,
                      onTap: () async {
                        final selected = await showJogadorPickerModal(
                          context: context,
                          title: 'Selecionar capitao de ${time.nome}',
                          jogadores: candidatos,
                          selectedId: _capitaesPorTime[time.id],
                          allowNone: true,
                          noneLabel: 'Sem capitao',
                          noneSubtitle: 'Remover capitao deste time',
                        );
                        if (selected == null || !context.mounted) return;
                        setState(() {
                          if (selected == 0) {
                            _capitaesPorTime.remove(time.id);
                          } else {
                            _capitaesPorTime[time.id] = selected;
                          }
                          _resultado = <SorteioTime>[];
                          _stepError = null;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepResultado() {
    return CyberCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '4. Resultado',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _gerarSorteio,
                  child: const Text('Gerar times'),
                ),
                FilledButton(
                  onPressed: _aplicando || _resultado.isEmpty
                      ? null
                      : _aplicarSorteio,
                  child: _aplicando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Aplicar sorteio'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_sorteioError != null)
              Text(
                _sorteioError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            if (_resultado.isEmpty)
              const Text(
                'Clique em "Sortear equipes" para ver a distribuicao.',
                style: TextStyle(color: AppTheme.textMuted),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width > 980
                      ? 3
                      : width > 680
                      ? 2
                      : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _resultado.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemBuilder: (context, index) {
                      final resultado = _resultado[index];
                      final escudoUrl = widget.config.resolveApiImageUrl(
                        resultado.time.escudoUrl,
                      );
                      return CyberCard(
                        padding: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: escudoUrl != null
                                        ? NetworkImage(escudoUrl)
                                        : null,
                                    backgroundColor: AppTheme.surfaceAlt,
                                    child: escudoUrl == null
                                        ? const Icon(
                                            Icons.shield_rounded,
                                            size: 16,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      resultado.time.nome,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${resultado.jogadores.length} jogadores',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: resultado.jogadores.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, idx) {
                                    final item = resultado.jogadores[idx];
                                    final nome = item.jogador.apelido.isNotEmpty
                                        ? item.jogador.apelido
                                        : item.jogador.nomeCompleto;
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            nome,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (item.capitao)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0x2EF5C451),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'Capitao',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFF5C451),
                                              ),
                                            ),
                                          ),
                                        if (item.goleiro)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 6,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0x22FF3B4D),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'Goleiro',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFFF3B4D),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(Map<int, int> counts, double availableHeight) {
    switch (_currentStep) {
      case 1:
        return _buildStepTimes(counts, availableHeight);
      case 2:
        return _buildStepJogadores(availableHeight);
      case 3:
        return _buildStepCapitaes();
      case 4:
        return _buildStepResultado();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimeOption(TimeModel time, int count) {
    final selected = _selectedTimes.contains(time.id);
    final escudoUrl = widget.config.resolveApiImageUrl(time.escudoUrl);
    final color = _parseColor(time.cor);
    return InkWell(
      onTap: () => _toggleTime(time.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.32)
                : AppTheme.surfaceBorderSoft,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              backgroundImage: escudoUrl != null
                  ? NetworkImage(escudoUrl)
                  : null,
              child: escudoUrl == null
                  ? Icon(Icons.shield_rounded, color: color, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                time.nome,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$count jogadores',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJogadorOption(Jogador jogador) {
    final selected = _selectedJogadores.contains(jogador.id);
    final goleiro = _selectedGoleiros.contains(jogador.id);
    final display = jogador.apelido.isNotEmpty
        ? jogador.apelido
        : jogador.nomeCompleto;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.34)
              : AppTheme.surfaceBorderSoft,
        ),
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.08)
            : AppTheme.surfaceAlt,
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (_) => _toggleJogador(jogador.id),
          ),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.shield_rounded, size: 14),
                SizedBox(width: 4),
                Text('Goleiro'),
              ],
            ),
            selected: goleiro,
            onSelected: selected ? (_) => _toggleGoleiro(jogador.id) : null,
            selectedColor: const Color(0x2418C76F),
            checkmarkColor: AppTheme.primary,
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppTheme.surfaceBorderSoft),
            labelStyle: TextStyle(
              color: goleiro ? AppTheme.primary : AppTheme.textSoft,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = _countPlayersByTeam();
    final availableHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Sorteio de equipes'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _resetSorteio,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('Limpar'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(keepSelection: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Monte os times por sorteio com goleiros e capitaes fixos.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              CyberCard(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              )
            else ...[
              _buildStepProgressHeader(),
              const SizedBox(height: 12),
              _buildCurrentStep(counts, availableHeight),
              const SizedBox(height: 12),
              if (_stepError != null)
                Text(
                  _stepError!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _currentStep == 1 ? null : _prevStep,
                        child: const Text('Voltar'),
                      ),
                      if (_currentStep < 4)
                        FilledButton(
                          onPressed: _nextStep,
                          child: const Text('Continuar'),
                        )
                      else
                        OutlinedButton(
                          onPressed: _gerarSorteio,
                          child: const Text('Re-sortear'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Voltar para Times'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SorteioJogador {
  const SorteioJogador({
    required this.jogador,
    this.capitao = false,
    this.goleiro = false,
  });

  final Jogador jogador;
  final bool capitao;
  final bool goleiro;
}

class SorteioTime {
  const SorteioTime({required this.time, required this.jogadores});

  final TimeModel time;
  final List<SorteioJogador> jogadores;
}

class _SorteioAssignment {
  _SorteioAssignment({required this.time})
    : jogadores = <SorteioJogador>[],
      goleiros = 0;

  final TimeModel time;
  final List<SorteioJogador> jogadores;
  int goleiros;
}
