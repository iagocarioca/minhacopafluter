import '../features/admin/data/admin_remote_data_source.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/comparativo/data/comparativo_remote_data_source.dart';
import '../features/jogadores/data/jogadores_remote_data_source.dart';
import '../features/partidas/data/partidas_remote_data_source.dart';
import '../features/peladas/data/peladas_remote_data_source.dart';
import '../features/perfis/data/perfis_remote_data_source.dart';
import '../features/publico/data/site_assets_remote_data_source.dart';
import '../features/rankings/data/rankings_remote_data_source.dart';
import '../features/rodadas/data/rodadas_remote_data_source.dart';
import '../features/substituicoes/data/substituicoes_remote_data_source.dart';
import '../features/temporadas/data/temporadas_remote_data_source.dart';
import '../features/times/data/times_remote_data_source.dart';
import '../features/transferencias/data/transferencias_remote_data_source.dart';
import '../features/votacoes/data/votacoes_remote_data_source.dart';

class AppServices {
  const AppServices({
    required this.config,
    required this.authController,
    required this.apiClient,
    required this.peladasDataSource,
    required this.jogadoresDataSource,
    required this.temporadasDataSource,
    required this.rodadasDataSource,
    required this.partidasDataSource,
    required this.votacoesDataSource,
    required this.substituicoesDataSource,
    required this.timesDataSource,
    required this.rankingsDataSource,
    required this.transferenciasDataSource,
    required this.perfisDataSource,
    required this.comparativoDataSource,
    required this.adminDataSource,
    required this.siteAssetsDataSource,
  });

  final AppConfig config;
  final AuthController authController;
  final ApiClient apiClient;
  final PeladasRemoteDataSource peladasDataSource;
  final JogadoresRemoteDataSource jogadoresDataSource;
  final TemporadasRemoteDataSource temporadasDataSource;
  final RodadasRemoteDataSource rodadasDataSource;
  final PartidasRemoteDataSource partidasDataSource;
  final VotacoesRemoteDataSource votacoesDataSource;
  final SubstituicoesRemoteDataSource substituicoesDataSource;
  final TimesRemoteDataSource timesDataSource;
  final RankingsRemoteDataSource rankingsDataSource;
  final TransferenciasRemoteDataSource transferenciasDataSource;
  final PerfisRemoteDataSource perfisDataSource;
  final ComparativoRemoteDataSource comparativoDataSource;
  final AdminRemoteDataSource adminDataSource;
  final SiteAssetsRemoteDataSource siteAssetsDataSource;
}
