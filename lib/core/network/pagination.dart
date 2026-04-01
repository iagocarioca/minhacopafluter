class PaginationMeta {
  const PaginationMeta({
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int perPage;
  final int total;
  final int totalPages;
}

class PaginatedResult<T> {
  const PaginatedResult({required this.items, this.meta});

  final List<T> items;
  final PaginationMeta? meta;
}
