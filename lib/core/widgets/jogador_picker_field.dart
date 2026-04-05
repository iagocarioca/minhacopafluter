import 'package:flutter/material.dart';

import '../../domain/models/jogador.dart';
import '../theme/app_theme.dart';

String jogadorDisplayName(Jogador jogador) {
  return jogador.apelido.isNotEmpty ? jogador.apelido : jogador.nomeCompleto;
}

String jogadorDisplayNameById(
  List<Jogador> jogadores,
  int? id, {
  String empty = 'Selecionar jogador',
  String noneLabel = 'Sem jogador',
}) {
  if (id == null) return empty;
  if (id == 0) return noneLabel;
  for (final jogador in jogadores) {
    if (jogador.id == id) return jogadorDisplayName(jogador);
  }
  return 'Jogador #$id';
}

Future<int?> showJogadorPickerModal({
  required BuildContext context,
  required String title,
  required List<Jogador> jogadores,
  int? selectedId,
  bool allowNone = false,
  String noneLabel = 'Sem jogador',
  String noneSubtitle = 'Opcional',
  String emptyMessage = 'Nenhum jogador encontrado.',
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
                    top: Radius.circular(22),
                  ),
                  border: Border.all(color: AppTheme.surfaceBorderSoft),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (value) =>
                            setModalState(() => query = value),
                        decoration: const InputDecoration(
                          hintText: 'Buscar jogador...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (allowNone)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _JogadorOptionTile(
                          label: noneLabel,
                          subtitle: noneSubtitle,
                          selected: selectedId == 0,
                          onTap: () => Navigator.of(context).pop(0),
                        ),
                      ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                emptyMessage,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final jogador = filtered[index];
                                return _JogadorOptionTile(
                                  label: jogadorDisplayName(jogador),
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

class JogadorPickerField extends StatefulWidget {
  const JogadorPickerField({
    super.key,
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
  State<JogadorPickerField> createState() => _JogadorPickerFieldState();
}

class _JogadorPickerFieldState extends State<JogadorPickerField> {
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
                      ? (active ? const Color(0xFFEAF2F8) : AppTheme.surfaceAlt)
                      : const Color(0xFFE9EDF2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.enabled
                        ? (active
                              ? AppTheme.primary.withValues(alpha: 0.34)
                              : AppTheme.surfaceBorderSoft)
                        : AppTheme.surfaceBorderSoft,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 18,
                      color: widget.enabled
                          ? AppTheme.textSoft
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
                          ? (active ? AppTheme.primary : AppTheme.textMuted)
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

class _JogadorOptionTile extends StatefulWidget {
  const _JogadorOptionTile({
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
  State<_JogadorOptionTile> createState() => _JogadorOptionTileState();
}

class _JogadorOptionTileState extends State<_JogadorOptionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _hovered;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: widget.selected
                    ? AppTheme.primary.withValues(alpha: 0.14)
                    : (highlighted
                          ? const Color(0xFFF2F6FB)
                          : AppTheme.surfaceAlt),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.selected
                      ? AppTheme.primary.withValues(alpha: 0.32)
                      : AppTheme.surfaceBorderSoft,
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
                          ? AppTheme.primary.withValues(alpha: 0.18)
                          : const Color(0xFFE7EDF4),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.person_rounded,
                      size: 17,
                      color: widget.selected
                          ? AppTheme.primary
                          : AppTheme.textSoft,
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
                          : AppTheme.textMuted,
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
