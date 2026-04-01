import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_tabs.dart';
import 'package:frontcopa_flutter/domain/models/jogador.dart';
import 'package:frontcopa_flutter/features/jogadores/data/jogadores_remote_data_source.dart';
import 'package:go_router/go_router.dart';

class JogadoresPage extends StatefulWidget {
  const JogadoresPage({
    super.key,
    required this.peladaId,
    required this.dataSource,
    required this.config,
  });

  final int peladaId;
  final JogadoresRemoteDataSource dataSource;
  final AppConfig config;

  @override
  State<JogadoresPage> createState() => _JogadoresPageState();
}

enum _JogadorFilter { all, active, inactive }

class _JogadoresPageState extends State<JogadoresPage> {
  List<Jogador> _jogadores = const <Jogador>[];
  bool _loading = true;
  String? _error;
  _JogadorFilter _filter = _JogadorFilter.all;

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
      final response = await widget.dataSource.listJogadores(
        peladaId: widget.peladaId,
        page: 1,
        perPage: 200,
      );
      if (!mounted) return;
      setState(() => _jogadores = response.items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<Jogador> get _filtered {
    switch (_filter) {
      case _JogadorFilter.active:
        return _jogadores.where((item) => item.ativo != false).toList();
      case _JogadorFilter.inactive:
        return _jogadores.where((item) => item.ativo == false).toList();
      case _JogadorFilter.all:
        return _jogadores;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _jogadores.where((item) => item.ativo != false).length;
    final inactiveCount = _jogadores
        .where((item) => item.ativo == false)
        .length;

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Jogadores'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/peladas/${widget.peladaId}/jogadores/new'),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo Jogador'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            CyberTabs(
              labels: [
                'Todos (${_jogadores.length})',
                'Ativos ($activeCount)',
                'Inativos ($inactiveCount)',
              ],
              selectedIndex: _filter.index,
              onChanged: (index) =>
                  setState(() => _filter = _JogadorFilter.values[index]),
            ),
            const SizedBox(height: 10),
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
            if (!_loading && _error == null && _filtered.isEmpty)
              const CyberCard(child: Text('Nenhum jogador encontrado')),
            ..._filtered.map(
              (jogador) => CyberCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        jogador.fotoUrl != null && jogador.fotoUrl!.isNotEmpty
                        ? NetworkImage(
                            widget.config.resolveApiImageUrl(jogador.fotoUrl)!,
                          )
                        : null,
                    child: jogador.fotoUrl == null || jogador.fotoUrl!.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(jogador.apelido),
                  subtitle: Text(
                    [
                      jogador.nomeCompleto,
                      if (jogador.posicao != null) jogador.posicao!,
                    ].join(' • '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push(
                      '/peladas/${widget.peladaId}/jogadores/${jogador.id}/edit',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
