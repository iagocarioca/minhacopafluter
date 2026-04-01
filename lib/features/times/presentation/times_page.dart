import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/image_file_picker_field.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/cyber_card.dart';
import '../../../domain/models/time_model.dart';
import '../data/times_remote_data_source.dart';

class TimesPage extends StatefulWidget {
  const TimesPage({
    super.key,
    required this.peladaId,
    required this.temporadaId,
    required this.dataSource,
    required this.config,
  });

  final int peladaId;
  final int temporadaId;
  final TimesRemoteDataSource dataSource;
  final AppConfig config;

  @override
  State<TimesPage> createState() => _TimesPageState();
}

class _TimesPageState extends State<TimesPage> {
  List<TimeModel> _times = const <TimeModel>[];
  Map<int, int> _jogadoresPorTime = const <int, int>{};
  bool _loading = true;
  bool _creating = false;
  String? _error;
  String? _createError;

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
      final data = await widget.dataSource.listTimes(
        temporadaId: widget.temporadaId,
        page: 1,
        perPage: 200,
      );
      final counts = <int, int>{
        for (final time in data) time.id: time.jogadoresTotal ?? 0,
      };
      if (!mounted) return;
      setState(() {
        _times = data;
        _jogadoresPorTime = counts;
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

  List<TimeModel> get _rankedTimes {
    final items = List<TimeModel>.from(_times);
    items.sort((a, b) {
      final jogadoresA = _jogadoresPorTime[a.id] ?? 0;
      final jogadoresB = _jogadoresPorTime[b.id] ?? 0;
      final byPlayers = jogadoresB.compareTo(jogadoresA);
      if (byPlayers != 0) return byPlayers;

      return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    });
    return items;
  }

  int _playersCount(int timeId) => _jogadoresPorTime[timeId] ?? 0;

  Widget _buildTimeCard(TimeModel time, int rank) {
    final escudoUrl = widget.config.resolveApiImageUrl(time.escudoUrl);
    final color = _parseColor(time.cor);
    final jogadores = _playersCount(time.id);
    final isTop = rank <= 3;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.push('/peladas/${widget.peladaId}/times/${time.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: Color(0xFF243245),
                            height: 1.02,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildInfoChip(
                              icon: Icons.emoji_events_rounded,
                              label: '#$rank',
                              highlighted: isTop,
                            ),
                            _buildInfoChip(
                              icon: Icons.groups_2_rounded,
                              label: '$jogadores jogadores',
                              highlighted: false,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTeamAvatar(escudoUrl: escudoUrl, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _openRenameDialog(time),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFFF1F5FA),
                      foregroundColor: AppTheme.textSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 15),
                    label: const Text(
                      'Renomear',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppTheme.textSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required bool highlighted,
  }) {
    final bgColor = highlighted
        ? const Color(0x1F18C76F)
        : const Color(0xFFF1F5FA);
    final textColor = highlighted ? AppTheme.primary : AppTheme.textMuted;

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamAvatar({required String? escudoUrl, required Color color}) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF4F7FB),
        border: Border.all(color: const Color(0xFFE7EDF4)),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.18),
        ),
        clipBehavior: Clip.antiAlias,
        child: escudoUrl != null && escudoUrl.isNotEmpty
            ? Image.network(
                escudoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.shield_rounded, color: color, size: 24),
              )
            : Icon(Icons.shield_rounded, color: color, size: 24),
      ),
    );
  }

  Future<void> _openRenameDialog(TimeModel time) async {
    final controller = TextEditingController(text: time.nome);
    String? errorText;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Renomear time'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Nome do time',
                    ),
                    enabled: !saving,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final nome = controller.text.trim();
                          if (nome.isEmpty) {
                            setDialogState(
                              () => errorText = 'Informe o nome do time.',
                            );
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            errorText = null;
                          });
                          try {
                            await widget.dataSource.updateTime(
                              timeId: time.id,
                              input: TimeUpdateInput(nome: nome),
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            await _load();
                          } catch (error) {
                            if (!context.mounted) return;
                            setDialogState(() => errorText = error.toString());
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => saving = false);
                            }
                          }
                        },
                  child: saving
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
        );
      },
    );

    controller.dispose();
  }

  Future<void> _openCreateDialog() async {
    final nomeController = TextEditingController();
    String selectedColor = '#2A2C35';
    XFile? escudoFile;
    _createError = null;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Novo time'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do time',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        const [
                          '#2A2C35',
                          '#0D6EFD',
                          '#DC3545',
                          '#198754',
                          '#F39C12',
                          '#6F42C1',
                        ].map((hex) {
                          return _ColorOption(colorHex: hex);
                        }).toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedColor,
                    items: const [
                      DropdownMenuItem(
                        value: '#2A2C35',
                        child: Text('Cinza escuro'),
                      ),
                      DropdownMenuItem(value: '#0D6EFD', child: Text('Azul')),
                      DropdownMenuItem(
                        value: '#DC3545',
                        child: Text('Vermelho'),
                      ),
                      DropdownMenuItem(value: '#198754', child: Text('Verde')),
                      DropdownMenuItem(
                        value: '#F39C12',
                        child: Text('Laranja'),
                      ),
                      DropdownMenuItem(value: '#6F42C1', child: Text('Roxo')),
                    ],
                    onChanged: _creating
                        ? null
                        : (value) => setDialogState(
                            () => selectedColor = value ?? selectedColor,
                          ),
                    decoration: const InputDecoration(labelText: 'Cor'),
                  ),
                  const SizedBox(height: 12),
                  ImageFilePickerField(
                    label: 'Escudo (opcional)',
                    onChanged: (file) => escudoFile = file,
                    shape: BoxShape.rectangle,
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
                onPressed: _creating ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _creating
                    ? null
                    : () async {
                        final nome = nomeController.text.trim();
                        if (nome.isEmpty) {
                          setDialogState(
                            () => _createError = 'Informe o nome do time.',
                          );
                          return;
                        }

                        setState(() {
                          _creating = true;
                          _createError = null;
                        });

                        try {
                          await widget.dataSource.createTime(
                            temporadaId: widget.temporadaId,
                            input: TimeCreateInput(
                              nome: nome,
                              cor: selectedColor,
                              escudoFile: escudoFile,
                            ),
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          await _load();
                        } catch (error) {
                          setDialogState(() => _createError = error.toString());
                        } finally {
                          if (mounted) {
                            setState(() => _creating = false);
                          }
                        }
                      },
                child: _creating
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

    nomeController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rankedTimes = _rankedTimes;

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Arena dos Times'),
        actions: [
          IconButton(
            onPressed: () => context.push(
              '/peladas/${widget.peladaId}/temporadas/${widget.temporadaId}/sorteio',
            ),
            icon: const Icon(Icons.shuffle_rounded),
            tooltip: 'Sorteio',
          ),
          IconButton(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Novo time',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
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
            if (!_loading && _error == null && _times.isEmpty)
              const CyberCard(
                child: Text('Nenhum time cadastrado nesta temporada.'),
              ),
            if (!_loading && _error == null && _times.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1080
                      ? 4
                      : width >= 760
                      ? 3
                      : width >= 520
                      ? 2
                      : 1;
                  if (columns == 1) {
                    return Column(
                      children: [
                        for (var index = 0; index < rankedTimes.length; index++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == rankedTimes.length - 1 ? 0 : 12,
                            ),
                            child: _buildTimeCard(
                              rankedTimes[index],
                              index + 1,
                            ),
                          ),
                      ],
                    );
                  }
                  final aspect = columns == 1
                      ? 2.18
                      : columns == 2
                      ? 1.36
                      : 1.2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rankedTimes.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: aspect,
                    ),
                    itemBuilder: (context, index) =>
                        _buildTimeCard(rankedTimes[index], index + 1),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({required this.colorHex});

  final String colorHex;

  @override
  Widget build(BuildContext context) {
    final parsed = int.tryParse(colorHex.replaceFirst('#', ''), radix: 16);
    final color = parsed == null
        ? const Color(0xFF2A2C35)
        : Color(0xFF000000 | parsed);

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
