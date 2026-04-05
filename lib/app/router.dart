import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/comparativo/presentation/comparativo_page.dart';
import '../features/estatisticas/presentation/temporada_estatisticas_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/jogadores/presentation/jogador_form_page.dart';
import '../features/jogadores/presentation/jogadores_page.dart';
import '../features/partidas/presentation/partida_detail_page.dart';
import '../features/peladas/presentation/pelada_detail_page.dart';
import '../features/peladas/presentation/pelada_form_page.dart';
import '../features/peladas/presentation/peladas_page.dart';
import '../features/perfis/presentation/perfil_jogador_publico_page.dart';
import '../features/rankings/presentation/rankings_page.dart';
import '../features/rankings/presentation/player_annual_rankings_page.dart';
import '../features/rodadas/presentation/rodada_detail_page.dart';
import '../features/rodadas/presentation/rodadas_page.dart';
import '../features/shell/presentation/web_app_shell_page.dart';
import '../features/splash/presentation/splash_page.dart';
import '../features/temporadas/presentation/temporadas_page.dart';
import '../features/times/presentation/sorteio_page.dart';
import '../features/times/presentation/time_detail_page.dart';
import '../features/times/presentation/times_page.dart';
import '../features/transferencias/presentation/transferencias_page.dart';
import '../features/votacoes/presentation/votacao_detail_page.dart';
import '../features/votacoes/presentation/votacao_publica_page.dart';
import '../features/publico/presentation/pelada_publica_page.dart';
import 'app_services.dart';

GoRouter buildAppRouter({required AppServices services}) {
  final authController = services.authController;
  final config = services.config;

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: authController,
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          authController: authController,
          config: config,
          siteAssetsDataSource: services.siteAssetsDataSource,
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterPage(
          authController: authController,
          config: config,
          siteAssetsDataSource: services.siteAssetsDataSource,
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => HomePage(
          authController: authController,
          config: config,
          peladasDataSource: services.peladasDataSource,
          temporadasDataSource: services.temporadasDataSource,
          rodadasDataSource: services.rodadasDataSource,
          partidasDataSource: services.partidasDataSource,
          rankingsDataSource: services.rankingsDataSource,
          perfisDataSource: services.perfisDataSource,
        ),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) =>
            AdminPage(dataSource: services.adminDataSource),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) =>
            WebAppShellPage(config: config, onLogout: authController.logout),
      ),
      GoRoute(
        path: '/peladas',
        builder: (context, state) => PeladasPage(
          authController: authController,
          dataSource: services.peladasDataSource,
          seguidoresDataSource: services.seguidoresDataSource,
          config: config,
          initialSearch: _safeQueryParam(state.uri, 'q'),
        ),
      ),
      GoRoute(
        path: '/peladas/new',
        builder: (context, state) => PeladaFormPage.create(
          dataSource: services.peladasDataSource,
          config: config,
        ),
      ),
      GoRoute(
        path: '/peladas/:peladaId/edit',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          return PeladaFormPage.edit(
            peladaId: peladaId,
            dataSource: services.peladasDataSource,
            config: config,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          return PeladaDetailPage(
            peladaId: peladaId,
            dataSource: services.peladasDataSource,
            seguidoresDataSource: services.seguidoresDataSource,
            authController: authController,
            config: config,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/publico',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          return PeladaPublicaPage(
            peladaId: peladaId,
            config: config,
            authController: authController,
            seguidoresDataSource: services.seguidoresDataSource,
            peladasDataSource: services.peladasDataSource,
            rankingsDataSource: services.rankingsDataSource,
          );
        },
      ),
      GoRoute(
        path: '/perfil/:jogadorId',
        builder: (context, state) {
          final jogadorId = _requiredInt(state.pathParameters['jogadorId']);
          return PerfilJogadorPublicoPage(
            jogadorId: jogadorId,
            config: config,
            perfisDataSource: services.perfisDataSource,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/comparativo',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          return ComparativoPage(
            peladaId: peladaId,
            config: config,
            comparativoDataSource: services.comparativoDataSource,
            jogadoresDataSource: services.jogadoresDataSource,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/jogadores',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          return JogadoresPage(
            peladaId: peladaId,
            dataSource: services.jogadoresDataSource,
            config: config,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/jogadores/new',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          return JogadorFormPage.create(
            peladaId: peladaId,
            dataSource: services.jogadoresDataSource,
            config: config,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/jogadores/:jogadorId/edit',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final jogadorId = _requiredInt(state.pathParameters['jogadorId']);
          return JogadorFormPage.edit(
            peladaId: peladaId,
            jogadorId: jogadorId,
            dataSource: services.jogadoresDataSource,
            config: config,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/temporadas',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          return TemporadasPage(
            peladaId: peladaId,
            dataSource: services.temporadasDataSource,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/temporadas/:temporadaId',
        redirect: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final temporadaId = _requiredInt(state.pathParameters['temporadaId']);
          return '/peladas/$peladaId/temporadas/$temporadaId/rodadas';
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/temporadas/:temporadaId/estatisticas',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final temporadaId = _requiredInt(state.pathParameters['temporadaId']);
          return TemporadaEstatisticasPage(
            peladaId: peladaId,
            temporadaId: temporadaId,
            config: config,
            temporadasDataSource: services.temporadasDataSource,
            rankingsDataSource: services.rankingsDataSource,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/temporadas/:temporadaId/rodadas',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final temporadaId = _requiredInt(state.pathParameters['temporadaId']);
          return RodadasPage(
            peladaId: peladaId,
            temporadaId: temporadaId,
            dataSource: services.rodadasDataSource,
            temporadasDataSource: services.temporadasDataSource,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/temporadas/:temporadaId/times',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final temporadaId = _requiredInt(state.pathParameters['temporadaId']);
          return TimesPage(
            peladaId: peladaId,
            temporadaId: temporadaId,
            dataSource: services.timesDataSource,
            config: config,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/times/:timeId',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final timeId = _requiredInt(state.pathParameters['timeId']);
          return TimeDetailPage(
            peladaId: peladaId,
            timeId: timeId,
            config: config,
            timesDataSource: services.timesDataSource,
            jogadoresDataSource: services.jogadoresDataSource,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/temporadas/:temporadaId/sorteio',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final temporadaId = _requiredInt(state.pathParameters['temporadaId']);
          return SorteioPage(
            peladaId: peladaId,
            temporadaId: temporadaId,
            config: config,
            timesDataSource: services.timesDataSource,
            jogadoresDataSource: services.jogadoresDataSource,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/temporadas/:temporadaId/transferencias',
        builder: (context, state) {
          final temporadaId = _requiredInt(state.pathParameters['temporadaId']);
          return TransferenciasPage(
            temporadaId: temporadaId,
            transferenciasDataSource: services.transferenciasDataSource,
            timesDataSource: services.timesDataSource,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/temporadas/:temporadaId/rankings',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final temporadaId = _requiredInt(state.pathParameters['temporadaId']);
          return RankingsPage(
            peladaId: peladaId,
            temporadaId: temporadaId,
            dataSource: services.rankingsDataSource,
            config: config,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/temporadas/:temporadaId/rankings/anual',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final temporadaId = _requiredInt(state.pathParameters['temporadaId']);
          return PlayerAnnualRankingsPage(
            peladaId: peladaId,
            temporadaId: temporadaId,
            config: config,
            rankingsDataSource: services.rankingsDataSource,
            temporadasDataSource: services.temporadasDataSource,
            rodadasDataSource: services.rodadasDataSource,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/rodadas/:rodadaId',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final rodadaId = _requiredInt(state.pathParameters['rodadaId']);
          return RodadaDetailPage(
            peladaId: peladaId,
            rodadaId: rodadaId,
            rodadasDataSource: services.rodadasDataSource,
            partidasDataSource: services.partidasDataSource,
            votacoesDataSource: services.votacoesDataSource,
            substituicoesDataSource: services.substituicoesDataSource,
            timesDataSource: services.timesDataSource,
            jogadoresDataSource: services.jogadoresDataSource,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/partidas/:partidaId',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final partidaId = _requiredInt(state.pathParameters['partidaId']);
          return PartidaDetailPage(
            peladaId: peladaId,
            partidaId: partidaId,
            config: config,
            partidasDataSource: services.partidasDataSource,
            rodadasDataSource: services.rodadasDataSource,
          );
        },
      ),
      GoRoute(
        path: '/peladas/:peladaId/votacoes/:votacaoId',
        builder: (context, state) {
          final peladaId = _requiredInt(state.pathParameters['peladaId']);
          final votacaoId = _requiredInt(state.pathParameters['votacaoId']);
          return VotacaoDetailPage(
            peladaId: peladaId,
            votacaoId: votacaoId,
            config: config,
            votacoesDataSource: services.votacoesDataSource,
            rodadasDataSource: services.rodadasDataSource,
            substituicoesDataSource: services.substituicoesDataSource,
          );
        },
      ),
      GoRoute(
        path: '/votacao/:votacaoId/publico',
        builder: (context, state) {
          final votacaoId = _requiredInt(state.pathParameters['votacaoId']);
          return VotacaoPublicaPage(
            votacaoId: votacaoId,
            config: config,
            votacoesDataSource: services.votacoesDataSource,
            rodadasDataSource: services.rodadasDataSource,
            substituicoesDataSource: services.substituicoesDataSource,
          );
        },
      ),
    ],
    redirect: (context, state) {
      final location = state.uri.path;
      final onSplash = location == '/splash';
      final onAuth = location == '/login' || location == '/register';
      final isPublicRoute =
          RegExp(r'^/perfil/\d+$').hasMatch(location) ||
          RegExp(r'^/peladas/\d+/publico$').hasMatch(location) ||
          RegExp(r'^/votacao/\d+/publico$').hasMatch(location);

      if (!authController.initialized) {
        return onSplash || isPublicRoute ? null : '/splash';
      }

      if (!authController.isAuthenticated) {
        return onAuth || isPublicRoute ? null : '/login';
      }

      if (onAuth || onSplash || location == '/app') {
        return '/home';
      }

      return null;
    },
  );
}

int _requiredInt(String? rawValue) {
  final value = int.tryParse(rawValue ?? '');
  if (value == null) {
    throw Exception('Parametro de rota invalido');
  }
  return value;
}

String _safeQueryParam(Uri uri, String key) {
  try {
    return (uri.queryParameters[key] ?? '').trim();
  } catch (_) {
    final raw = uri.query.trim();
    if (raw.isEmpty) return '';
    for (final entry in raw.split('&')) {
      if (entry.isEmpty) continue;
      final idx = entry.indexOf('=');
      final currentKey = idx >= 0 ? entry.substring(0, idx) : entry;
      if (currentKey != key) continue;
      final value = idx >= 0 ? entry.substring(idx + 1) : '';
      final normalized = value.replaceAll('+', ' ');
      try {
        return Uri.decodeQueryComponent(normalized).trim();
      } catch (_) {
        return normalized.trim();
      }
    }
    return '';
  }
}
