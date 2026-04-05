import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_badge.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/domain/models/pelada.dart';
import 'package:frontcopa_flutter/domain/models/pelada_feed.dart';
import 'package:frontcopa_flutter/features/auth/state/auth_controller.dart';
import 'package:frontcopa_flutter/features/peladas/data/peladas_remote_data_source.dart';
import 'package:frontcopa_flutter/features/seguidores/data/seguidores_remote_data_source.dart';
import 'package:go_router/go_router.dart';

class PeladasPage extends StatefulWidget {
  const PeladasPage({
    super.key,
    required this.authController,
    required this.dataSource,
    required this.seguidoresDataSource,
    required this.config,
    this.initialSearch = '',
  });

  final AuthController authController;
  final PeladasRemoteDataSource dataSource;
  final SeguidoresRemoteDataSource seguidoresDataSource;
  final AppConfig config;
  final String initialSearch;

  @override
  State<PeladasPage> createState() => _PeladasPageState();
}

class _PeladasPageState extends State<PeladasPage> {
  List<Pelada> _peladas = const <Pelada>[];
  List<PeladaFeedItem> _discoverPeladas = const <PeladaFeedItem>[];
  Set<int> _followedIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  bool _loadingDiscover = false;
  int? _followingPeladaId;
  String? _error;
  String? _discoverError;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSearch.trim();
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _searchTerm = initial;
    }
    _loadPeladas();
    if (widget.authController.isSeguidor) {
      _loadDiscoverPeladas();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPeladas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = widget.authController.isSeguidor
          ? await widget.seguidoresDataSource.listPeladasSeguidas(
              page: 1,
              perPage: 50,
            )
          : await widget.dataSource.listPeladas(
              page: 1,
              perPage: 50,
              usuarioId: widget.authController.currentUser?.id,
            );

      if (!mounted) return;
      setState(() {
        _peladas = response.items;
        _followedIds = response.items.map((item) => item.id).toSet();
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

  Future<void> _loadDiscoverPeladas() async {
    setState(() {
      _loadingDiscover = true;
      _discoverError = null;
    });
    try {
      final response = await widget.dataSource.getPublicPeladasFeed(
        semanas: 52,
        limit: 120,
        somenteComInstagram: false,
      );
      if (!mounted) return;
      final unique = <int, PeladaFeedItem>{};
      for (final item in response.feed) {
        unique[item.id] = item;
      }
      setState(() => _discoverPeladas = unique.values.toList());
    } catch (error) {
      if (!mounted) return;
      setState(() => _discoverError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingDiscover = false);
      }
    }
  }

  Future<void> _refreshAll() async {
    await _loadPeladas();
    if (widget.authController.isSeguidor) {
      await _loadDiscoverPeladas();
    }
  }

  List<PeladaFeedItem> get _discoverFiltered {
    final term = _searchTerm.trim().toLowerCase();
    final base = _discoverPeladas.where(
      (item) => !_followedIds.contains(item.id),
    );
    if (term.isEmpty) {
      return base.toList();
    }
    return base
        .where((item) => item.nome.toLowerCase().contains(term))
        .toList();
  }

  List<String> get _discoverSuggestions {
    final suggestions = <String>[];
    final seen = <String>{};
    for (final item in _discoverPeladas) {
      if (_followedIds.contains(item.id)) continue;
      final parsed = item.nome.trim();
      if (parsed.isEmpty) continue;
      final key = parsed.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      suggestions.add(parsed);
      if (suggestions.length >= 5) break;
    }
    return suggestions;
  }

  void _applyDiscoverSuggestion(String value) {
    _searchController.text = value;
    setState(() => _searchTerm = value);
  }

  Future<void> _seguirPelada(PeladaFeedItem item) async {
    if (_followingPeladaId != null) return;
    setState(() => _followingPeladaId = item.id);
    try {
      await widget.seguidoresDataSource.seguirPelada(item.id);
      if (!mounted) return;
      setState(() => _followedIds = {..._followedIds, item.id});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Agora voce segue ${item.nome}.')));
      await _loadPeladas();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _followingPeladaId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSeguidor = widget.authController.isSeguidor;
    final discover = _discoverFiltered;
    final discoverSuggestions = _discoverSuggestions;
    final showAllDiscover = _searchTerm.trim().isNotEmpty;
    final discoverToShow = showAllDiscover ? discover : discover.take(20);
    final ativas = _peladas.where((item) => item.ativa).length;
    final inativas = _peladas.where((item) => !item.ativa).length;

    return Scaffold(
      appBar: AppTopBar(
        leading: IconButton(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar para home',
        ),
        title: const Text('Peladas'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              await widget.authController.logout();
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            CyberCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tutorial ocultado',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Abra novamente quando quiser rever como usar o app.',
                          style: TextStyle(
                            color: AppTheme.textSoft,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: const Text('Ver vídeo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            CyberCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSeguidor ? 'PELADAS SEGUIDAS' : 'PELADAS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isSeguidor)
                    OutlinedButton.icon(
                      onPressed: () => context.push('/peladas/new'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('ADICIONAR PELADA'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: const Color(0x24FF4D5E)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Total',
                          value: _peladas.length,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'Ativas',
                          value: ativas,
                          highlight: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatCard(
                          label: 'Inativas',
                          value: inativas,
                          muted: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (isSeguidor) ...[
              CyberCard(
                padding: EdgeInsets.zero,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF7FCF9), Color(0xFFEFF8F3)],
                    ),
                    border: Border.all(color: const Color(0xFFDAECE2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: const Color(0x2E17A76F),
                            ),
                            child: const Icon(
                              Icons.travel_explore_rounded,
                              size: 18,
                              color: Color(0xFF116066),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Descobrir peladas',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x1E17A76F),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${discover.length} resultado(s)',
                              style: const TextStyle(
                                color: Color(0xFF116066),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Busque uma pelada para seguir e acompanhar no app.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchTerm = value),
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar pelada por nome...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchTerm.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchTerm = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                      if (discoverSuggestions.isNotEmpty &&
                          _searchTerm.trim().isEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: discoverSuggestions.map((item) {
                            return ActionChip(
                              onPressed: () => _applyDiscoverSuggestion(item),
                              backgroundColor: const Color(0x1717A76F),
                              side: const BorderSide(color: Color(0x44116066)),
                              label: Text(
                                item,
                                style: const TextStyle(
                                  color: Color(0xFF116066),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingDiscover)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_discoverError != null && !_loadingDiscover)
                CyberCard(
                  child: Text(
                    _discoverError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              if (!_loadingDiscover &&
                  _discoverError == null &&
                  discover.isEmpty)
                const CyberCard(
                  child: Text(
                    'Nenhuma pelada encontrada para esse filtro.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              if (!showAllDiscover && discover.length > 20)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Mostrando 20 de ${discover.length} peladas. Digite para filtrar.',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ...discoverToShow.map((item) {
                final logoUrl = widget.config.resolveApiImageUrl(item.iconeUrl);
                final following = _followedIds.contains(item.id);
                final busy = _followingPeladaId == item.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CyberCard(
                    onTap: () => context.push('/peladas/${item.id}/publico'),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF17151C),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.transparent),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: logoUrl != null
                                ? Image.network(logoUrl, fit: BoxFit.cover)
                                : const Icon(
                                    Icons.sports_soccer_rounded,
                                    color: AppTheme.primary,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: following || busy
                              ? null
                              : () => _seguirPelada(item),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(
                            busy ? '...' : (following ? 'Seguindo' : 'Seguir'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
              const Divider(color: AppTheme.surfaceBorderSoft),
              const SizedBox(height: 10),
            ],
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
            if (!_loading && _error == null && _peladas.isEmpty)
              CyberCard(
                child: Column(
                  children: [
                    const Icon(Icons.sports_soccer, size: 42),
                    const SizedBox(height: 10),
                    Text(
                      isSeguidor
                          ? 'Voce ainda nao segue nenhuma pelada.'
                          : 'Nenhuma pelada encontrada',
                    ),
                    if (isSeguidor) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Abra o perfil publico de uma pelada para seguir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ..._peladas.map((pelada) {
              final logoUrl =
                  pelada.logoUrl != null && pelada.logoUrl!.isNotEmpty
                  ? widget.config.resolveApiImageUrl(pelada.logoUrl)
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CyberCard(
                  onTap: () => context.push('/peladas/${pelada.id}'),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF17151C),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.transparent),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: logoUrl != null
                              ? Image.network(logoUrl, fit: BoxFit.cover)
                              : const Icon(
                                  Icons.sports_soccer_rounded,
                                  color: AppTheme.primary,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pelada.nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_rounded,
                                  size: 14,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    pelada.cidade,
                                    style: const TextStyle(
                                      color: Color(0xFF98A0AF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      CyberBadge(
                        label: pelada.ativa ? 'Ativa' : 'Inativa',
                        variant: pelada.ativa
                            ? CyberBadgeVariant.active
                            : CyberBadgeVariant.ended,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.highlight = false,
    this.muted = false,
  });

  final String label;
  final int value;
  final bool highlight;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: highlight
                ? AppTheme.primary
                : muted
                ? const Color(0xFF98A0AF)
                : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF98A0AF),
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
