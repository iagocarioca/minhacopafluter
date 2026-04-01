import '../utils/json_parsing.dart';
import 'pagination.dart';

Map<String, dynamic> asPayload(dynamic data) {
  return parseMap(data);
}

PaginationMeta? parsePaginationMeta(Map<String, dynamic> payload) {
  final meta = parseMap(payload['meta']);
  final pagination = parseMap(payload['pagination']);
  final source = meta.isNotEmpty ? meta : pagination;
  if (source.isEmpty) {
    return null;
  }

  final page = parseInt(source['page']) ?? 1;
  final perPage = parseInt(source['per_page']) ?? 20;
  final total = parseInt(source['total']) ?? 0;
  final totalPages =
      parseInt(source['pages']) ??
      parseInt(source['total_pages']) ??
      ((total / perPage).ceil());

  return PaginationMeta(
    page: page,
    perPage: perPage,
    total: total,
    totalPages: totalPages,
  );
}

List<Map<String, dynamic>> parseDataList(Map<String, dynamic> payload) {
  final raw =
      payload['data'] ??
      payload['items'] ??
      payload['results'] ??
      payload['peladas'] ??
      payload['jogadores'] ??
      payload['temporadas'] ??
      payload;

  if (raw is! Iterable) {
    return const <Map<String, dynamic>>[];
  }

  return raw.map(parseMap).where((item) => item.isNotEmpty).toList();
}
