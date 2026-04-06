import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/admin/data/admin_remote_data_source.dart';
import 'features/auth/data/auth_remote_data_source.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/comparativo/data/comparativo_remote_data_source.dart';
import 'features/jogadores/data/jogadores_remote_data_source.dart';
import 'features/partidas/data/partidas_remote_data_source.dart';
import 'features/peladas/data/peladas_remote_data_source.dart';
import 'features/perfis/data/perfis_remote_data_source.dart';
import 'features/publico/data/site_assets_remote_data_source.dart';
import 'features/rankings/data/rankings_remote_data_source.dart';
import 'features/rodadas/data/rodadas_remote_data_source.dart';
import 'features/seguidores/data/seguidores_remote_data_source.dart';
import 'features/substituicoes/data/substituicoes_remote_data_source.dart';
import 'features/temporadas/data/temporadas_remote_data_source.dart';
import 'features/times/data/times_remote_data_source.dart';
import 'features/transferencias/data/transferencias_remote_data_source.dart';
import 'features/votacoes/data/votacoes_remote_data_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  final config = AppConfig.fromEnvironment();
  final secureStorage = SecureStorageService();
  final authRemoteDataSource = AuthRemoteDataSource(baseUrl: config.apiBaseUrl);
  final authController = AuthController(
    remoteDataSource: authRemoteDataSource,
    secureStorage: secureStorage,
  );

  await authController.initialize();

  final apiClient = ApiClient(config: config, authController: authController);

  final services = AppServices(
    config: config,
    authController: authController,
    apiClient: apiClient,
    peladasDataSource: PeladasRemoteDataSource(apiClient: apiClient),
    jogadoresDataSource: JogadoresRemoteDataSource(apiClient: apiClient),
    temporadasDataSource: TemporadasRemoteDataSource(apiClient: apiClient),
    rodadasDataSource: RodadasRemoteDataSource(apiClient: apiClient),
    seguidoresDataSource: SeguidoresRemoteDataSource(apiClient: apiClient),
    partidasDataSource: PartidasRemoteDataSource(apiClient: apiClient),
    votacoesDataSource: VotacoesRemoteDataSource(apiClient: apiClient),
    substituicoesDataSource: SubstituicoesRemoteDataSource(
      apiClient: apiClient,
    ),
    timesDataSource: TimesRemoteDataSource(apiClient: apiClient),
    rankingsDataSource: RankingsRemoteDataSource(apiClient: apiClient),
    transferenciasDataSource: TransferenciasRemoteDataSource(
      apiClient: apiClient,
    ),
    perfisDataSource: PerfisRemoteDataSource(apiClient: apiClient),
    comparativoDataSource: ComparativoRemoteDataSource(apiClient: apiClient),
    adminDataSource: AdminRemoteDataSource(apiClient: apiClient),
    siteAssetsDataSource: SiteAssetsRemoteDataSource(apiClient: apiClient),
  );

  runApp(MinhaCopaApp(services: services));
}
