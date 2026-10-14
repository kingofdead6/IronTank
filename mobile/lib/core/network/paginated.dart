/// The API's list envelope: `{ data, page, limit, total, totalPages }`.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory Paginated.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) => Paginated(
    items: (json['data'] as List<dynamic>).map((e) => parse(e as Map<String, dynamic>)).toList(),
    page: (json['page'] as num).toInt(),
    limit: (json['limit'] as num).toInt(),
    total: (json['total'] as num).toInt(),
    totalPages: (json['totalPages'] as num).toInt(),
  );

  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}
