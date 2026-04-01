import '../../core/utils/json_parsing.dart';

class Pelada {
  const Pelada({
    required this.id,
    required this.nome,
    required this.cidade,
    required this.ativa,
    this.fusoHorario,
    this.logoUrl,
    this.perfilUrl,
    this.logoVetorUrl,
    this.instagramUrl,
    this.cores = const <String>[],
    this.proprietarioId,
    this.usuarioGerenteId,
    this.criadoEm,
  });

  final int id;
  final String nome;
  final String cidade;
  final bool ativa;
  final String? fusoHorario;
  final String? logoUrl;
  final String? perfilUrl;
  final String? logoVetorUrl;
  final String? instagramUrl;
  final List<String> cores;
  final int? proprietarioId;
  final int? usuarioGerenteId;
  final String? criadoEm;

  factory Pelada.fromJson(Map<String, dynamic> json) {
    return Pelada(
      id: parseInt(json['id']) ?? 0,
      nome: parseString(json['nome']) ?? '',
      cidade: parseString(json['cidade']) ?? '',
      ativa: parseBool(json['ativa']),
      fusoHorario: parseString(json['fuso_horario']),
      logoUrl: parseString(json['logo_url']),
      perfilUrl: parseString(json['perfil_url']),
      logoVetorUrl: parseString(json['logo_vetor_url']),
      instagramUrl: parseString(json['instagram_url']),
      cores: parseStringList(json['cores']),
      proprietarioId: parseInt(json['proprietario_id']),
      usuarioGerenteId: parseInt(json['usuario_gerente_id']),
      criadoEm: parseString(json['criado_em']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'cidade': cidade,
      'ativa': ativa,
      'fuso_horario': fusoHorario,
      'logo_url': logoUrl,
      'perfil_url': perfilUrl,
      'logo_vetor_url': logoVetorUrl,
      'instagram_url': instagramUrl,
      'cores': cores,
      'proprietario_id': proprietarioId,
      'usuario_gerente_id': usuarioGerenteId,
      'criado_em': criadoEm,
    };
  }
}
