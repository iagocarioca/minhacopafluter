import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/core/widgets/jogador_picker_field.dart';
import 'package:frontcopa_flutter/domain/models/jogador.dart';
import 'package:frontcopa_flutter/domain/models/substituicao.dart';
import 'package:frontcopa_flutter/domain/models/votacao.dart';
import 'package:frontcopa_flutter/features/rodadas/data/rodadas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/substituicoes/data/substituicoes_remote_data_source.dart';
import 'package:frontcopa_flutter/features/votacoes/data/votacoes_remote_data_source.dart';
import 'package:intl/intl.dart';

class VotacaoPublicaPage extends StatefulWidget {
  const VotacaoPublicaPage({
    super.key,
    required this.votacaoId,
    required this.config,
    required this.votacoesDataSource,
    required this.rodadasDataSource,
    required this.substituicoesDataSource,
  });

  final int votacaoId;
  final AppConfig config;
  final VotacoesRemoteDataSource votacoesDataSource;
  final RodadasRemoteDataSource rodadasDataSource;
  final SubstituicoesRemoteDataSource substituicoesDataSource;

  @override
  State<VotacaoPublicaPage> createState() => _VotacaoPublicaPageState();
}

class _VotacaoPublicaPageState extends State<VotacaoPublicaPage> {
  Votacao? _votacao;
  Map<String, dynamic>? _resultado;
  List<Jogador> _jogadores = const <Jogador>[];

  bool _loading = true;
  bool _enviandoVotos = false;
  bool _votosEnviados = false;
  String? _error;

  int? _selectedVotanteId;
  int? _votanteId;
  final Set<int> _selecionados = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _votosEnviados = false;
      _selecionados.clear();
      _votanteId = null;
      _selectedVotanteId = null;
    });
    try {
      final votacao = await widget.votacoesDataSource.getVotacao(
        widget.votacaoId,
      );
      Map<String, dynamic>? resultado;
      if (votacao.status == 'encerrada') {
        resultado = await widget.votacoesDataSource.getResultado(
          widget.votacaoId,
        );
      }

      final jogadoresRodada = await widget.rodadasDataSource
          .listJogadoresRodada(votacao.rodadaId, apenasAtivos: true);
      final participantes = jogadoresRodada
          .where((jogador) => jogador.timeId != null)
          .toList();

      List<Jogador> jogadores = participantes;
      try {
        final substituicoes = await widget.substituicoesDataSource
            .listSubstituicoes(votacao.rodadaId);
        jogadores = _applySubstituicoes(participantes, substituicoes);
      } catch (_) {
        jogadores = participantes;
      }

      if (!mounted) return;
      setState(() {
        _votacao = votacao;
        _resultado = resultado;
        _jogadores = jogadores;
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

  List<Jogador> _applySubstituicoes(
    List<Jogador> jogadores,
    List<Substituicao> substituicoes,
  ) {
    if (substituicoes.isEmpty) return jogadores;

    var list = List<Jogador>.from(jogadores);
    for (final sub in substituicoes) {
      final timeId = sub.timeId;
      final ausenteId = sub.jogadorAusente.id;
      final substitutoId = sub.jogadorSubstituto.id;

      list = list
          .where(
            (jogador) =>
                !(jogador.id == ausenteId && (jogador.timeId ?? 0) == timeId),
          )
          .toList();

      final jaNoTime = list.any(
        (jogador) =>
            jogador.id == substitutoId && (jogador.timeId ?? 0) == timeId,
      );
      if (jaNoTime) continue;

      final base = list.firstWhere(
        (jogador) => jogador.id == substitutoId,
        orElse: () => Jogador(
          id: substitutoId,
          apelido: sub.jogadorSubstituto.apelido ?? '',
          nomeCompleto: sub.jogadorSubstituto.nomeCompleto,
        ),
      );
      final timeNome = list
          .firstWhere(
            (jogador) => (jogador.timeId ?? 0) == timeId,
            orElse: () => base,
          )
          .timeNome;

      list.add(
        Jogador(
          id: substitutoId,
          apelido: base.apelido,
          nomeCompleto: base.nomeCompleto,
          peladaId: base.peladaId,
          telefone: base.telefone,
          fotoUrl: base.fotoUrl ?? sub.jogadorSubstituto.fotoUrl,
          posicao: base.posicao,
          capitao: base.capitao,
          timeId: timeId,
          timeNome: timeNome,
          timeEscudoUrl: base.timeEscudoUrl,
          ativo: base.ativo,
          criadoEm: base.criadoEm,
        ),
      );
    }

    return list;
  }

  String _tipoLabel(String tipo) {
    const labels = <String, String>{
      'craque': 'Craque da rodada',
      'destaque': 'Destaque da rodada',
      'goleiro': 'Goleiro da rodada',
      'fair_play': 'Jogo limpo',
      'mvp': 'MVP',
      'jogador_noite': 'Jogador da noite',
      'goleiro_noite': 'Goleiro da noite',
    };
    return labels[tipo] ?? tipo;
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
  }

  String _jogadorLabel(Jogador jogador) {
    return jogador.apelido.isNotEmpty ? jogador.apelido : jogador.nomeCompleto;
  }

  String _posicaoDisplayKey(String? posicao) {
    final raw = (posicao ?? '').toLowerCase().trim();
    if (raw.isEmpty) return 'outros';

    bool has(String sub) => raw.contains(sub);
    bool word(List<String> words) => words.any(
      (w) =>
          RegExp('\\b$w\\b').hasMatch(raw) || raw == w || raw.startsWith('$w-'),
    );

    if (word(['gk', 'gol']) || has('goleir')) return 'goleiro';
    if (word(['zag', 'zague', 'fixo', 'cb', 'def']) ||
        has('zag') ||
        has('fixo')) {
      return 'zagueiro';
    }
    if (word(['lat', 'le', 'ld', 'lb', 'rb']) || has('lateral')) {
      return 'lateral';
    }
    if (word(['vol', 'dm']) || has('vol')) return 'volante';
    if (word(['ala', 'wing']) || has('ala')) return 'ala';
    if (word(['mei', 'meia', 'meio', 'cm', 'cam', 'am']) || has('mei')) {
      return 'meia';
    }
    if (word(['ata', 'atac', 'ponta', 'pe', 'pd', 'st', 'cf', '9', 'for']) ||
        has('atac') ||
        has('centroav')) {
      return 'atacante';
    }
    return 'outros';
  }

  void _toggleVoto(int jogadorId) {
    if (_votanteId != null && jogadorId == _votanteId) {
      return;
    }

    setState(() {
      if (_selecionados.contains(jogadorId)) {
        _selecionados.remove(jogadorId);
      } else if (_selecionados.length < 5) {
        _selecionados.add(jogadorId);
      }
    });
  }

  Future<void> _confirmarVotos() async {
    if (_votanteId == null || _selecionados.isEmpty) return;
    setState(() => _enviandoVotos = true);
    try {
      for (final jogadorVotadoId in _selecionados) {
        await widget.votacoesDataSource.votar(
          votacaoId: widget.votacaoId,
          input: VotoInput(
            jogadorVotanteId: _votanteId!,
            jogadorVotadoId: jogadorVotadoId,
            pontos: 1,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _votosEnviados = true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _enviandoVotos = false);
      }
    }
  }

  Future<void> _copiarLink() async {
    final link =
        '${widget.config.webAppUrl}/votacao/${widget.votacaoId}/publico';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final votacao = _votacao;
    Jogador? votante;
    for (final jogador in _jogadores) {
      if (jogador.id == _votanteId) {
        votante = jogador;
        break;
      }
    }

    final goleiros = _jogadores
        .where((item) => _posicaoDisplayKey(item.posicao) == 'goleiro')
        .toList();
    final demaisJogadores = _jogadores
        .where((item) => _posicaoDisplayKey(item.posicao) != 'goleiro')
        .toList();

    final votacaoResultado = _resultado?['votacao'];
    final vencedorMap = votacaoResultado is Map<String, dynamic>
        ? (votacaoResultado['vencedor'] as Map<String, dynamic>?)
        : (_resultado?['vencedor'] as Map<String, dynamic>?);
    final vencedorNome =
        vencedorMap?['apelido']?.toString() ??
        vencedorMap?['nome_completo']?.toString();

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Votacao publica'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Tentar de novo'),
                    ),
                  ],
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
                    child: Column(
                      children: [
                        Text(
                          _tipoLabel(votacao?.tipo ?? ''),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Aberta ate ${_formatDate(votacao?.fechaEm)}',
                          style: const TextStyle(
                            color: Color(0xFF98A0AF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (votacao != null && votacao.status == 'encerrada')
                    CyberCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            size: 40,
                            color: Color(0xFFF5C451),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Votacao encerrada',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if ((vencedorNome ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Vencedor: $vencedorNome'),
                          ],
                        ],
                      ),
                    )
                  else if (_votosEnviados)
                    CyberCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: const [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 42,
                            color: Color(0xFFFF3B4D),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Votos registrados',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text('Obrigado por participar da votacao.'),
                        ],
                      ),
                    )
                  else ...[
                    if (_votanteId == null)
                      CyberCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Passo 1: Quem e voce?',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            JogadorPickerField(
                              label: 'Selecione seu nome',
                              value: jogadorDisplayNameById(
                                _jogadores,
                                _selectedVotanteId,
                                empty: _jogadores.isEmpty
                                    ? 'Sem jogadores disponiveis'
                                    : 'Selecionar jogador',
                              ),
                              icon: Icons.badge_outlined,
                              enabled: _jogadores.isNotEmpty,
                              onTap: () async {
                                final selected = await showJogadorPickerModal(
                                  context: context,
                                  title: 'Quem e voce?',
                                  jogadores: _jogadores,
                                  selectedId: _selectedVotanteId,
                                );
                                if (selected == null || !context.mounted) {
                                  return;
                                }
                                setState(() => _selectedVotanteId = selected);
                              },
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _selectedVotanteId == null
                                    ? null
                                    : () {
                                        setState(
                                          () => _votanteId = _selectedVotanteId,
                                        );
                                      },
                                child: const Text('Continuar'),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      CyberCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.person_rounded),
                          title: Text(
                            'Votando como ${_jogadorLabel(votante ?? Jogador(id: 0, apelido: '', nomeCompleto: 'Jogador'))}',
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              setState(() {
                                _votanteId = null;
                                _selectedVotanteId = null;
                                _selecionados.clear();
                              });
                            },
                            child: const Text('Trocar'),
                          ),
                        ),
                      ),
                      CyberCard(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Escolha ate 5 jogadores. Cada voto vale 1 ponto. '
                          'Voce nao pode votar em si mesmo.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (_selecionados.isNotEmpty)
                        CyberCard(
                          padding: const EdgeInsets.all(14),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selecionados
                                .map(
                                  (id) => Chip(
                                    label: Text(
                                      _jogadorLabel(
                                        _jogadores.firstWhere(
                                          (jogador) => jogador.id == id,
                                        ),
                                      ),
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ),
                                    onDeleted: () {
                                      setState(() => _selecionados.remove(id));
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      if (goleiros.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 6, bottom: 8),
                          child: Text(
                            'Goleiros',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF3B4D),
                            ),
                          ),
                        ),
                        _PlayersVoteGrid(
                          jogadores: goleiros,
                          votanteId: _votanteId,
                          selecionados: _selecionados,
                          maxVotos: 5,
                          config: widget.config,
                          onToggle: _toggleVoto,
                        ),
                      ],
                      if (demaisJogadores.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            'Jogadores',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF3B4D),
                            ),
                          ),
                        ),
                        _PlayersVoteGrid(
                          jogadores: demaisJogadores,
                          votanteId: _votanteId,
                          selecionados: _selecionados,
                          maxVotos: 5,
                          config: widget.config,
                          onToggle: _toggleVoto,
                        ),
                      ],
                      if (_selecionados.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: FilledButton.icon(
                            onPressed: _enviandoVotos ? null : _confirmarVotos,
                            icon: _enviandoVotos
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.how_to_vote_rounded),
                            label: Text(
                              _enviandoVotos
                                  ? 'Enviando votos...'
                                  : 'Confirmar ${_selecionados.length} voto(s)',
                            ),
                          ),
                        ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _copiarLink,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copiar link publico'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PlayersVoteGrid extends StatelessWidget {
  const _PlayersVoteGrid({
    required this.jogadores,
    required this.votanteId,
    required this.selecionados,
    required this.maxVotos,
    required this.config,
    required this.onToggle,
  });

  final List<Jogador> jogadores;
  final int? votanteId;
  final Set<int> selecionados;
  final int maxVotos;
  final AppConfig config;
  final ValueChanged<int> onToggle;

  bool _isDisabled(int jogadorId) {
    if (votanteId != null && jogadorId == votanteId) return true;
    if (selecionados.length >= maxVotos && !selecionados.contains(jogadorId)) {
      return true;
    }
    return false;
  }

  String _label(Jogador jogador) {
    return jogador.apelido.isNotEmpty ? jogador.apelido : jogador.nomeCompleto;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: jogadores.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final jogador = jogadores[index];
        final selected = selecionados.contains(jogador.id);
        final disabled = _isDisabled(jogador.id);
        final image = config.resolveApiImageUrl(jogador.fotoUrl);
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : () => onToggle(jogador.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0x24FF3B4D)
                  : const Color(0xFF18151C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundImage: image != null ? NetworkImage(image) : null,
                  child: image == null
                      ? const Icon(Icons.person, size: 13)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(jogador),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: disabled
                              ? const Color(0xFF5E6B63)
                              : const Color(0xFFF7FAF5),
                        ),
                      ),
                      Text(
                        jogador.timeNome ?? 'Sem time',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: disabled
                              ? const Color(0xFF526058)
                              : const Color(0xFF98A0AF),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xFFFF3B4D),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
