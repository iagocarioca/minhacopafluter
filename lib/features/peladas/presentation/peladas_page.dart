import 'package:flutter/material.dart';
import 'package:frontcopa_flutter/core/config/app_config.dart';
import 'package:frontcopa_flutter/core/theme/app_theme.dart';
import 'package:frontcopa_flutter/core/widgets/app_top_bar.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_badge.dart';
import 'package:frontcopa_flutter/core/widgets/cyber_card.dart';
import 'package:frontcopa_flutter/domain/models/pelada.dart';
import 'package:frontcopa_flutter/features/auth/state/auth_controller.dart';
import 'package:frontcopa_flutter/features/peladas/data/peladas_remote_data_source.dart';
import 'package:go_router/go_router.dart';

class PeladasPage extends StatefulWidget {
  const PeladasPage({
    super.key,
    required this.authController,
    required this.dataSource,
    required this.config,
  });

  final AuthController authController;
  final PeladasRemoteDataSource dataSource;
  final AppConfig config;

  @override
  State<PeladasPage> createState() => _PeladasPageState();
}

class _PeladasPageState extends State<PeladasPage> {
  List<Pelada> _peladas = const <Pelada>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPeladas();
  }

  Future<void> _loadPeladas() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userId = widget.authController.currentUser?.id;
      final response = await widget.dataSource.listPeladas(
        page: 1,
        perPage: 50,
        usuarioId: userId,
      );

      if (!mounted) return;
      setState(() => _peladas = response.items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ativas = _peladas.where((item) => item.ativa).length;
    final inativas = _peladas.where((item) => !item.ativa).length;

    return Scaffold(
      appBar: AppTopBar(
        automaticallyImplyLeading: false,
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
        onRefresh: _loadPeladas,
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
                  const Text(
                    'PELADAS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
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
              const CyberCard(
                child: Column(
                  children: [
                    Icon(Icons.sports_soccer, size: 42),
                    SizedBox(height: 10),
                    Text('Nenhuma pelada encontrada'),
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
