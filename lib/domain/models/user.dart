import '../../core/utils/json_parsing.dart';

class User {
  const User({
    required this.id,
    required this.username,
    required this.email,
    this.status,
    this.tipoUsuario,
    this.ultimoLoginEm,
    this.ultimoLoginIp,
    this.peladasTotal,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String username;
  final String email;
  final String? status;
  final String? tipoUsuario;
  final String? ultimoLoginEm;
  final String? ultimoLoginIp;
  final int? peladasTotal;
  final String? createdAt;
  final String? updatedAt;

  bool get isAdmin => tipoUsuario == 'admin';
  bool get isOrganizador => tipoUsuario == 'organizador';
  bool get isSeguidor => tipoUsuario == 'seguidor';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: parseInt(json['id']) ?? 0,
      username: parseString(json['username']) ?? '',
      email: parseString(json['email']) ?? '',
      status: parseString(json['status']),
      tipoUsuario: parseString(json['tipo_usuario']),
      ultimoLoginEm: parseString(json['ultimo_login_em']),
      ultimoLoginIp: parseString(json['ultimo_login_ip']),
      peladasTotal: parseInt(json['peladas_total']),
      createdAt: parseString(json['created_at']),
      updatedAt: parseString(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'email': email,
      'status': status,
      'tipo_usuario': tipoUsuario,
      'ultimo_login_em': ultimoLoginEm,
      'ultimo_login_ip': ultimoLoginIp,
      'peladas_total': peladasTotal,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
