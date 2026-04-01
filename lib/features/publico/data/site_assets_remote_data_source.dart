import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_payload.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../domain/models/site_assets.dart';

class SiteAssetsRemoteDataSource {
  SiteAssetsRemoteDataSource({required ApiClient apiClient})
    : _dio = apiClient.dio;

  final Dio _dio;

  Future<SiteAssets> getPublicSiteAssets() async {
    try {
      final response = await _dio.get<dynamic>('/api/publico/site-assets');
      final payload = asPayload(response.data);
      final nested = parseMap(payload['data']);
      final source = nested.isNotEmpty ? nested : payload;
      return SiteAssets.fromJson(source);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
