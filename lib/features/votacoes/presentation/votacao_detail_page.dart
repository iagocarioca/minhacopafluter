import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
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
import 'package:url_launcher/url_launcher.dart';

class VotacaoDetailPage extends StatefulWidget {
  const VotacaoDetailPage({
    super.key,
    required this.peladaId,
    required this.votacaoId,
    required this.config,
    required this.votacoesDataSource,
    required this.rodadasDataSource,
    required this.substituicoesDataSource,
  });

  final int peladaId;
  final int votacaoId;
  final AppConfig config;
  final VotacoesRemoteDataSource votacoesDataSource;
  final RodadasRemoteDataSource rodadasDataSource;
  final SubstituicoesRemoteDataSource substituicoesDataSource;

  @override
  State<VotacaoDetailPage> createState() => _VotacaoDetailPageState();
}

class _VotacaoDetailPageState extends State<VotacaoDetailPage> {
  Votacao? _votacao;
  List<Jogador> _jogadores = const <Jogador>[];
  List<Map<String, dynamic>> _votantes = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _resultado;

  int? _jogadorVotanteId;
  int? _jogadorVotadoId;
  int _pontos = 1;

  bool _loading = true;
  bool _saving = false;
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
      final votacao = await widget.votacoesDataSource.getVotacao(
        widget.votacaoId,
      );

      final jogadoresRodada = await widget.rodadasDataSource
          .listJogadoresRodada(votacao.rodadaId, apenasAtivos: true);
      final participantes = jogadoresRodada
          .where((j) => j.timeId != null)
          .toList();

      List<Jogador> jogadores = participantes;
      try {
        final substituicoes = await widget.substituicoesDataSource
            .listSubstituicoes(votacao.rodadaId);
        jogadores = _applySubstituicoes(participantes, substituicoes);
      } catch (_) {
        jogadores = participantes;
      }

      final votantes = await widget.votacoesDataSource.listVotantes(
        widget.votacaoId,
      );
      final resultado = await widget.votacoesDataSource.getResultado(
        widget.votacaoId,
      );

      if (!mounted) return;
      setState(() {
        _votacao = votacao;
        _jogadores = jogadores;
        _votantes = votantes;
        _resultado = resultado;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
          .where((j) => !(j.id == ausenteId && (j.timeId ?? 0) == timeId))
          .toList();

      final jaNoTime = list.any(
        (j) => j.id == substitutoId && (j.timeId ?? 0) == timeId,
      );
      if (jaNoTime) continue;

      final base = list.firstWhere(
        (j) => j.id == substitutoId,
        orElse: () => Jogador(
          id: substitutoId,
          apelido: sub.jogadorSubstituto.apelido ?? '',
          nomeCompleto: sub.jogadorSubstituto.nomeCompleto,
        ),
      );

      final timeNome = list
          .firstWhere((j) => (j.timeId ?? 0) == timeId, orElse: () => base)
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

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
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

  String _statusLabel(String status) {
    const labels = <String, String>{
      'aberta': 'Aberta',
      'encerrada': 'Encerrada',
    };
    return labels[status] ??
        status
            .replaceAll('_', ' ')
            .replaceFirstMapped(
              RegExp(r'^\w'),
              (m) => m.group(0)!.toUpperCase(),
            );
  }

  Uri _publicLinkUri() {
    return widget.config.webAppUrl.replace(
      path: '/votacao/${widget.votacaoId}/publico',
      queryParameters: <String, String>{'pelada_id': '${widget.peladaId}'},
    );
  }

  String get _publicLink => _publicLinkUri().toString();

  Future<void> _copiarLinkPublico() async {
    await Clipboard.setData(ClipboardData(text: _publicLink));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link público copiado.')));
  }

  Future<void> _abrirLinkPublico() async {
    final launched = await launchUrl(
      _publicLinkUri(),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o link público.')),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  dynamic _decodeJsonIfNeeded(dynamic value) {
    if (value is! String) return value;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return value;
    final looksLikeJson =
        (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'));
    if (!looksLikeJson) return value;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return value;
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    value = _decodeJsonIfNeeded(value);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    value = _decodeJsonIfNeeded(value);
    if (value is! Iterable) return const <Map<String, dynamic>>[];
    return value
        .map(_asMap)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _jogadorLabel(Jogador jogador) {
    return jogador.apelido.trim().isNotEmpty
        ? jogador.apelido
        : jogador.nomeCompleto;
  }

  String _jogadorLabelById(int? jogadorId) {
    if (jogadorId == null) return '-';
    for (final jogador in _jogadores) {
      if (jogador.id == jogadorId) return _jogadorLabel(jogador);
    }
    return '#$jogadorId';
  }

  int? _votanteIdFromItem(Map<String, dynamic> item) {
    final jogadorVotante = _asMap(item['jogador_votante']);
    return _asInt(
      jogadorVotante['id'] ??
          item['jogador_votante_id'] ??
          item['votante_id'] ??
          item['id'],
    );
  }

  String _votanteNomeFromItem(Map<String, dynamic> item) {
    final jogadorVotante = _asMap(item['jogador_votante']);
    final apelido = (jogadorVotante['apelido']?.toString() ?? '').trim();
    if (apelido.isNotEmpty) return apelido;

    final nomeCompleto = (jogadorVotante['nome_completo']?.toString() ?? '')
        .trim();
    if (nomeCompleto.isNotEmpty) return nomeCompleto;

    final nomeLegacy = (item['jogador_votante_nome']?.toString() ?? '').trim();
    if (nomeLegacy.isNotEmpty) return nomeLegacy;

    final nomeFallback = (item['votante']?.toString() ?? '').trim();
    if (nomeFallback.isNotEmpty) return nomeFallback;

    return _jogadorLabelById(_votanteIdFromItem(item));
  }

  String? _votanteFotoFromItem(Map<String, dynamic> item) {
    final jogadorVotante = _asMap(item['jogador_votante']);
    return widget.config.resolveApiImageUrl(
      jogadorVotante['foto_url']?.toString(),
    );
  }

  int _quantidadeVotosFromItem(Map<String, dynamic> item) {
    return _asInt(
          item['quantidade_votos'] ?? item['qtd_votos'] ?? item['pontos'],
        ) ??
        0;
  }

  Future<void> _enviarVoto() async {
    if (_votacao == null) return;
    if (_jogadorVotanteId == null || _jogadorVotadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione votante e votado.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.votacoesDataSource.votar(
        votacaoId: widget.votacaoId,
        input: VotoInput(
          jogadorVotanteId: _jogadorVotanteId!,
          jogadorVotadoId: _jogadorVotadoId!,
          pontos: _pontos,
        ),
      );
      if (!mounted) return;
      setState(() {
        _jogadorVotanteId = null;
        _jogadorVotadoId = null;
        _pontos = 1;
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voto registrado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _encerrarVotacao() async {
    if (_votacao == null) return;
    setState(() => _saving = true);
    try {
      await widget.votacoesDataSource.encerrarVotacao(widget.votacaoId);
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

  @override
  Widget build(BuildContext context) {
    final votacao = _votacao;
    final votantesIds = <int>{};
    for (final item in _votantes) {
      final votanteId = _votanteIdFromItem(item);
      if (votanteId != null) {
        votantesIds.add(votanteId);
      }
    }

    final jogadoresNaoVotaram = _jogadores
        .where((jogador) => !votantesIds.contains(jogador.id))
        .toList(growable: false);

    final resultadoRaiz = _asMap(_resultado);
    final resultadoVotacao = _asMap(resultadoRaiz['votacao']);
    final resultado = resultadoVotacao.isNotEmpty
        ? resultadoVotacao
        : resultadoRaiz;
    final vencedor = _asMap(resultado['vencedor']);
    final ranking = _asMapList(resultado['resultado']);
    final totalVotos =
        _asInt(resultado['total_votos'] ?? resultadoRaiz['total_votos']) ?? 0;

    final vencedorNome =
        (vencedor['apelido']?.toString().trim() ?? '').isNotEmpty
        ? vencedor['apelido'].toString().trim()
        : (vencedor['nome_completo']?.toString().trim() ?? '');

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Detalhes da votação'),
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
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CyberCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _tipoLabel(votacao?.tipo ?? ''),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: votacao?.status == 'aberta'
                                  ? const Color(0x1A18C76F)
                                  : AppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _statusLabel(votacao?.status ?? ''),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: votacao?.status == 'aberta'
                                    ? AppTheme.primary
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Abertura: ${_formatDate(votacao?.abreEm)}',
                        style: const TextStyle(color: AppTheme.textSoft),
                      ),
                      Text(
                        'Fechamento: ${_formatDate(votacao?.fechaEm)}',
                        style: const TextStyle(color: AppTheme.textSoft),
                      ),
                    ],
                  ),
                ),
                if (votacao != null && votacao.status == 'aberta') ...[
                  const SizedBox(height: 12),
                  CyberCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.link_rounded,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Link público para votação',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Compartilhe este link para os jogadores votarem.',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(
                            _publicLink,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSoft,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _copiarLinkPublico,
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Copiar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _abrirLinkPublico,
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                ),
                                label: const Text('Abrir'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Painel de votação',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading || _saving ? null : _load,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Atualizar'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CyberCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Já votaram (${_votantes.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_votantes.isEmpty)
                        const Text(
                          'Ninguém votou ainda.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ..._votantes.map((item) {
                        final foto = _votanteFotoFromItem(item);
                        final nome = _votanteNomeFromItem(item);
                        final qtd = _quantidadeVotosFromItem(item);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundImage: foto != null
                                    ? NetworkImage(foto)
                                    : null,
                                child: foto == null
                                    ? const Icon(Icons.person, size: 13)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '$qtd voto(s)',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                CyberCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ainda não votaram (${jogadoresNaoVotaram.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE14A52),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (jogadoresNaoVotaram.isEmpty)
                        const Text(
                          'Todos já votaram.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ...jogadoresNaoVotaram.map((jogador) {
                        final foto = widget.config.resolveApiImageUrl(
                          jogador.fotoUrl,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundImage: foto != null
                                    ? NetworkImage(foto)
                                    : null,
                                child: foto == null
                                    ? const Icon(Icons.person, size: 13)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _jogadorLabel(jogador),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 17,
                                color: Color(0xFFE14A52),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Registrar voto',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                CyberCard(
                  child: Column(
                    children: [
                      JogadorPickerField(
                        label: 'Jogador votante',
                        value: jogadorDisplayNameById(
                          _jogadores,
                          _jogadorVotanteId,
                          empty: _jogadores.isEmpty
                              ? 'Sem jogadores disponíveis'
                              : 'Selecionar jogador',
                        ),
                        icon: Icons.how_to_vote_rounded,
                        enabled: !_saving && _jogadores.isNotEmpty,
                        onTap: () async {
                          final selected = await showJogadorPickerModal(
                            context: context,
                            title: 'Selecionar votante',
                            jogadores: _jogadores,
                            selectedId: _jogadorVotanteId,
                          );
                          if (selected == null || !context.mounted) return;
                          setState(() {
                            _jogadorVotanteId = selected;
                            if (_jogadorVotadoId == selected) {
                              _jogadorVotadoId = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      JogadorPickerField(
                        label: 'Jogador votado',
                        value: jogadorDisplayNameById(
                          _jogadores,
                          _jogadorVotadoId,
                          empty:
                              _jogadores
                                  .where((item) => item.id != _jogadorVotanteId)
                                  .isEmpty
                              ? 'Sem opções disponíveis'
                              : 'Selecionar jogador',
                        ),
                        icon: Icons.person_pin_circle_outlined,
                        enabled:
                            !_saving &&
                            _jogadores
                                .where((item) => item.id != _jogadorVotanteId)
                                .isNotEmpty,
                        onTap: () async {
                          final candidatos = _jogadores
                              .where((item) => item.id != _jogadorVotanteId)
                              .toList(growable: false);
                          final selected = await showJogadorPickerModal(
                            context: context,
                            title: 'Selecionar votado',
                            jogadores: candidatos,
                            selectedId: _jogadorVotadoId,
                          );
                          if (selected == null || !context.mounted) return;
                          setState(() => _jogadorVotadoId = selected);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: _pontos,
                        items: List<int>.generate(10, (index) => index + 1)
                            .map(
                              (pontos) => DropdownMenuItem<int>(
                                value: pontos,
                                child: Text('$pontos ponto(s)'),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _pontos = value ?? 1),
                        decoration: const InputDecoration(
                          labelText: 'Pontuação',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              _saving ||
                                  votacao == null ||
                                  votacao.status == 'encerrada'
                              ? null
                              : _enviarVoto,
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Enviar voto'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (votacao != null && votacao.status != 'encerrada')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _encerrarVotacao,
                      icon: const Icon(Icons.lock_clock_rounded),
                      label: const Text('Encerrar votação'),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Resultado',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                CyberCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.how_to_vote_rounded,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$totalVotos voto(s) registrado(s)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (vencedorNome.isNotEmpty)
                  CyberCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFE9A73E),
                      ),
                      title: const Text('Vencedor'),
                      subtitle: Text(vencedorNome),
                    ),
                  ),
                if (ranking.isNotEmpty)
                  CyberCard(
                    child: Column(
                      children: ranking
                          .asMap()
                          .entries
                          .map((entry) {
                            final pos = entry.key + 1;
                            final item = entry.value;
                            final jogador = _asMap(item['jogador']);
                            final nome =
                                (jogador['apelido']?.toString().trim() ?? '')
                                    .isNotEmpty
                                ? jogador['apelido'].toString().trim()
                                : (jogador['nome_completo']
                                          ?.toString()
                                          .trim() ??
                                      'Jogador');
                            final votos = _asInt(item['votos']) ?? 0;
                            final totalPontos =
                                _asInt(item['total_pontos']) ?? 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppTheme.surfaceBorder,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceAlt,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$pos',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      nome,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$votos votos · $totalPontos pts',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  )
                else
                  CyberCard(
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            size: 17,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Ainda não há votos computados nesta votação.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_resultado != null &&
                    ranking.isEmpty &&
                    vencedorNome.isEmpty)
                  CyberCard(
                    margin: const EdgeInsets.only(top: 8),
                    child: const Text(
                      'Os resultados aparecerão aqui assim que houver votos.',
                      style: TextStyle(color: AppTheme.textSoft, fontSize: 12),
                    ),
                  ),
              ],
            ),
    );
  }
}
