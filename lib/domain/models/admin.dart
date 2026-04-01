import '../../core/utils/json_parsing.dart';
import 'user.dart';

class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.usuariosTotal,
    required this.usuariosAtivos,
    required this.adminsTotal,
    required this.organizadoresTotal,
    required this.usuariosLogaram24h,
    required this.usuariosLogaram7d,
    required this.usuariosLogaram30d,
    required this.usuariosSemLogin,
    required this.usuariosNovos7d,
    required this.peladasTotal,
    required this.peladasAtivas,
    required this.peladasInativas,
    required this.peladasNovas7d,
    required this.temporadasTotal,
    required this.rodadasTotal,
    required this.partidasTotal,
    required this.jogadoresTotal,
  });

  final int usuariosTotal;
  final int usuariosAtivos;
  final int adminsTotal;
  final int organizadoresTotal;
  final int usuariosLogaram24h;
  final int usuariosLogaram7d;
  final int usuariosLogaram30d;
  final int usuariosSemLogin;
  final int usuariosNovos7d;
  final int peladasTotal;
  final int peladasAtivas;
  final int peladasInativas;
  final int peladasNovas7d;
  final int temporadasTotal;
  final int rodadasTotal;
  final int partidasTotal;
  final int jogadoresTotal;

  factory AdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    return AdminDashboardSummary(
      usuariosTotal: parseInt(json['usuarios_total']) ?? 0,
      usuariosAtivos: parseInt(json['usuarios_ativos']) ?? 0,
      adminsTotal: parseInt(json['admins_total']) ?? 0,
      organizadoresTotal: parseInt(json['organizadores_total']) ?? 0,
      usuariosLogaram24h: parseInt(json['usuarios_logaram_24h']) ?? 0,
      usuariosLogaram7d: parseInt(json['usuarios_logaram_7d']) ?? 0,
      usuariosLogaram30d: parseInt(json['usuarios_logaram_30d']) ?? 0,
      usuariosSemLogin: parseInt(json['usuarios_sem_login']) ?? 0,
      usuariosNovos7d: parseInt(json['usuarios_novos_7d']) ?? 0,
      peladasTotal: parseInt(json['peladas_total']) ?? 0,
      peladasAtivas: parseInt(json['peladas_ativas']) ?? 0,
      peladasInativas: parseInt(json['peladas_inativas']) ?? 0,
      peladasNovas7d: parseInt(json['peladas_novas_7d']) ?? 0,
      temporadasTotal: parseInt(json['temporadas_total']) ?? 0,
      rodadasTotal: parseInt(json['rodadas_total']) ?? 0,
      partidasTotal: parseInt(json['partidas_total']) ?? 0,
      jogadoresTotal: parseInt(json['jogadores_total']) ?? 0,
    );
  }
}

class AdminGerenteDestaque {
  const AdminGerenteDestaque({
    required this.id,
    required this.username,
    required this.peladasTotal,
  });

  final int id;
  final String username;
  final int peladasTotal;

  factory AdminGerenteDestaque.fromJson(Map<String, dynamic> json) {
    return AdminGerenteDestaque(
      id: parseInt(json['id']) ?? 0,
      username: parseString(json['username']) ?? '',
      peladasTotal: parseInt(json['peladas_total']) ?? 0,
    );
  }
}

class AdminPelada {
  const AdminPelada({
    required this.id,
    required this.nome,
    required this.cidade,
    required this.ativa,
    required this.usuarioGerenteId,
    required this.gerenteUsername,
    required this.gerenteEmail,
    required this.jogadoresTotal,
    required this.temporadasTotal,
    required this.rodadasTotal,
    required this.partidasTotal,
    this.criadoEm,
  });

  final int id;
  final String nome;
  final String cidade;
  final bool ativa;
  final int usuarioGerenteId;
  final String gerenteUsername;
  final String gerenteEmail;
  final int jogadoresTotal;
  final int temporadasTotal;
  final int rodadasTotal;
  final int partidasTotal;
  final String? criadoEm;

  factory AdminPelada.fromJson(Map<String, dynamic> json) {
    return AdminPelada(
      id: parseInt(json['id']) ?? 0,
      nome: parseString(json['nome']) ?? '',
      cidade: parseString(json['cidade']) ?? '',
      ativa: parseBool(json['ativa']),
      usuarioGerenteId: parseInt(json['usuario_gerente_id']) ?? 0,
      gerenteUsername: parseString(json['gerente_username']) ?? '',
      gerenteEmail: parseString(json['gerente_email']) ?? '',
      jogadoresTotal: parseInt(json['jogadores_total']) ?? 0,
      temporadasTotal: parseInt(json['temporadas_total']) ?? 0,
      rodadasTotal: parseInt(json['rodadas_total']) ?? 0,
      partidasTotal: parseInt(json['partidas_total']) ?? 0,
      criadoEm: parseString(json['criado_em']),
    );
  }
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.resumo,
    required this.ultimosLogins,
    required this.usuariosRecentes,
    required this.peladasRecentes,
    required this.gerentesDestaque,
  });

  final AdminDashboardSummary resumo;
  final List<User> ultimosLogins;
  final List<User> usuariosRecentes;
  final List<AdminPelada> peladasRecentes;
  final List<AdminGerenteDestaque> gerentesDestaque;

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    final resumo = AdminDashboardSummary.fromJson(parseMap(json['resumo']));

    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      if (raw is! Iterable) {
        return <T>[];
      }
      return raw
          .map(parseMap)
          .where((item) => item.isNotEmpty)
          .map(fromJson)
          .toList();
    }

    return AdminDashboardData(
      resumo: resumo,
      ultimosLogins: parseList(json['ultimos_logins'], User.fromJson),
      usuariosRecentes: parseList(json['usuarios_recentes'], User.fromJson),
      peladasRecentes: parseList(
        json['peladas_recentes'],
        AdminPelada.fromJson,
      ),
      gerentesDestaque: parseList(
        json['gerentes_destaque'],
        AdminGerenteDestaque.fromJson,
      ),
    );
  }
}
