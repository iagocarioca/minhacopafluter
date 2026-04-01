import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/network/pagination.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_back_button.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/domain/models/admin.dart';
import 'package:frontcopa_flutter/domain/models/user.dart';
import 'package:frontcopa_flutter/features/admin/data/admin_remote_data_source.dart';
import 'package:intl/intl.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.dataSource});

  final AdminRemoteDataSource dataSource;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  AdminDashboardData? _dashboard;
  List<User> _users = const <User>[];
  List<AdminPelada> _peladas = const <AdminPelada>[];

  PaginationMeta? _usersMeta;
  PaginationMeta? _peladasMeta;

  String _userBusca = '';
  String _userTipo = '';
  String _userStatus = '';

  String _peladaBusca = '';
  String _peladaAtiva = '';

  bool _loadingDashboard = true;
  bool _loadingUsers = true;
  bool _loadingPeladas = true;
  String? _error;

  final TextEditingController _userBuscaController = TextEditingController();
  final TextEditingController _peladaBuscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _userBuscaController.dispose();
    _peladaBuscaController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() => _error = null);
    try {
      await Future.wait([
        _loadDashboard(),
        _loadUsers(page: 1),
        _loadPeladas(page: 1),
      ]);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _loadingDashboard = true);
    try {
      final data = await widget.dataSource.getDashboard();
      if (!mounted) return;
      setState(() => _dashboard = data);
    } finally {
      if (mounted) {
        setState(() => _loadingDashboard = false);
      }
    }
  }

  Future<void> _loadUsers({required int page}) async {
    setState(() => _loadingUsers = true);
    try {
      final data = await widget.dataSource.listUsuarios(
        page: page,
        perPage: 10,
        busca: _userBusca,
        tipoUsuario: _userTipo,
        status: _userStatus,
      );
      if (!mounted) return;
      setState(() {
        _users = data.items;
        _usersMeta = data.meta;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingUsers = false);
      }
    }
  }

  Future<void> _loadPeladas({required int page}) async {
    setState(() => _loadingPeladas = true);
    try {
      final data = await widget.dataSource.listPeladas(
        page: page,
        perPage: 10,
        busca: _peladaBusca,
        ativa: _peladaAtiva,
      );
      if (!mounted) return;
      setState(() {
        _peladas = data.items;
        _peladasMeta = data.meta;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingPeladas = false);
      }
    }
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nunca';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required String hint,
  }) {
    return CyberCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.accent],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 0.75,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSoft),
          ),
        ],
      ),
    );
  }

  Widget _metaPaginator({
    required PaginationMeta? meta,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    required bool loading,
  }) {
    final page = meta?.page ?? 1;
    final totalPages = meta?.totalPages ?? 1;
    return Row(
      children: [
        OutlinedButton(
          onPressed: loading || page <= 1 ? null : onPrevious,
          child: const Text('Anterior'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Pagina $page de $totalPages',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: loading || page >= totalPages ? null : onNext,
          child: const Text('Proxima'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    final resumo = dashboard?.resumo;

    return Scaffold(
      appBar: AppTopBar(
        leading: const AppBackButton(),
        title: const Text('Admin'),
        actions: [
          IconButton(
            onPressed: _loadingDashboard || _loadingUsers || _loadingPeladas
                ? null
                : _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF23121A), Color(0xFF0F1119)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.transparent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'ADMIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Painel operacional de usuarios, peladas e acessos.',
                    style: TextStyle(color: Color(0xFFCBD4E3)),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (_loadingDashboard)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (resumo != null)
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.24,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _summaryCard(
                    label: 'Usuarios',
                    value: '${resumo.usuariosTotal}',
                    hint: '${resumo.usuariosAtivos} ativos',
                  ),
                  _summaryCard(
                    label: 'Logins 24h',
                    value: '${resumo.usuariosLogaram24h}',
                    hint: '${resumo.usuariosLogaram7d} em 7 dias',
                  ),
                  _summaryCard(
                    label: 'Peladas',
                    value: '${resumo.peladasAtivas}',
                    hint: '${resumo.peladasTotal} cadastradas',
                  ),
                  _summaryCard(
                    label: 'Partidas',
                    value: '${resumo.partidasTotal}',
                    hint: '${resumo.rodadasTotal} rodadas',
                  ),
                ],
              ),
            const SizedBox(height: 18),
            Text(
              'Ultimos logins',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_loadingDashboard)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Carregando acessos...'),
                ),
              )
            else if (dashboard?.ultimosLogins.isEmpty ?? true)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Nenhum login registrado.'),
                ),
              )
            else
              ...dashboard!.ultimosLogins.map((user) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(user.username),
                    subtitle: Text(user.email),
                    trailing: SizedBox(
                      width: 134,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatDate(user.ultimoLoginEm),
                            style: const TextStyle(fontSize: 11.5),
                            textAlign: TextAlign.end,
                          ),
                          Text(
                            user.ultimoLoginIp ?? 'IP indisponivel',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 10.5,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 18),
            Text(
              'Usuarios',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _userBuscaController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nome ou e-mail',
                      ),
                      onSubmitted: (_) async {
                        setState(
                          () => _userBusca = _userBuscaController.text.trim(),
                        );
                        await _loadUsers(page: 1);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _userTipo.isEmpty ? null : _userTipo,
                            decoration: const InputDecoration(
                              labelText: 'Papel',
                            ),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('Todos')),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Admin'),
                              ),
                              DropdownMenuItem(
                                value: 'organizador',
                                child: Text('Organizador'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _userTipo = value ?? '');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _userStatus.isEmpty
                                ? null
                                : _userStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                            ),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('Todos')),
                              DropdownMenuItem(
                                value: 'ativo',
                                child: Text('Ativo'),
                              ),
                              DropdownMenuItem(
                                value: 'inativo',
                                child: Text('Inativo'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _userStatus = value ?? '');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: () async {
                          setState(
                            () => _userBusca = _userBuscaController.text.trim(),
                          );
                          await _loadUsers(page: 1);
                        },
                        child: const Text('Filtrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingUsers)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Carregando usuarios...'),
                ),
              )
            else if (_users.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Nenhum usuario encontrado.'),
                ),
              )
            else
              ..._users.map((user) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(user.username),
                    subtitle: Text(
                      '${user.email}\n${user.tipoUsuario ?? 'organizador'} • ${user.status ?? 'ativo'}',
                    ),
                    isThreeLine: true,
                    trailing: Text('${user.peladasTotal ?? 0} peladas'),
                  ),
                );
              }),
            _metaPaginator(
              meta: _usersMeta,
              loading: _loadingUsers,
              onPrevious: () => _loadUsers(page: (_usersMeta?.page ?? 1) - 1),
              onNext: () => _loadUsers(page: (_usersMeta?.page ?? 1) + 1),
            ),
            const SizedBox(height: 18),
            Text(
              'Peladas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _peladaBuscaController,
                      decoration: const InputDecoration(
                        labelText: 'Buscar por pelada, cidade ou gerente',
                      ),
                      onSubmitted: (_) async {
                        setState(
                          () =>
                              _peladaBusca = _peladaBuscaController.text.trim(),
                        );
                        await _loadPeladas(page: 1);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _peladaAtiva.isEmpty
                                ? null
                                : _peladaAtiva,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                            ),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('Todas')),
                              DropdownMenuItem(
                                value: 'true',
                                child: Text('Ativas'),
                              ),
                              DropdownMenuItem(
                                value: 'false',
                                child: Text('Inativas'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _peladaAtiva = value ?? '');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () async {
                            setState(
                              () => _peladaBusca = _peladaBuscaController.text
                                  .trim(),
                            );
                            await _loadPeladas(page: 1);
                          },
                          child: const Text('Filtrar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingPeladas)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Carregando peladas...'),
                ),
              )
            else if (_peladas.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Nenhuma pelada encontrada.'),
                ),
              )
            else
              ..._peladas.map((pelada) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(pelada.nome),
                    subtitle: Text(
                      '${pelada.cidade}\n${pelada.gerenteUsername} • ${pelada.gerenteEmail}',
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          pelada.ativa ? 'Ativa' : 'Inativa',
                          style: TextStyle(
                            color: pelada.ativa
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB45309),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${pelada.jogadoresTotal} jog',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          '${pelada.partidasTotal} partidas',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            _metaPaginator(
              meta: _peladasMeta,
              loading: _loadingPeladas,
              onPrevious: () =>
                  _loadPeladas(page: (_peladasMeta?.page ?? 1) - 1),
              onNext: () => _loadPeladas(page: (_peladasMeta?.page ?? 1) + 1),
            ),
          ],
        ),
      ),
    );
  }
}
