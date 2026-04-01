import '../../core/utils/json_parsing.dart';

class SiteAssets {
  const SiteAssets({
    this.logoUrl,
    this.bannerUrl,
    this.criadoEm,
    this.atualizadoEm,
  });

  final String? logoUrl;
  final String? bannerUrl;
  final String? criadoEm;
  final String? atualizadoEm;

  factory SiteAssets.fromJson(Map<String, dynamic> json) {
    return SiteAssets(
      logoUrl: parseString(json['logo_url']),
      bannerUrl: parseString(json['banner_url']),
      criadoEm: parseString(json['criado_em']),
      atualizadoEm: parseString(json['atualizado_em']),
    );
  }
}
