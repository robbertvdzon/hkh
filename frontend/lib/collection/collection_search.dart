class CollectionCount {
  const CollectionCount({required this.collection, required this.count});

  factory CollectionCount.fromJson(Map<String, dynamic> json) =>
      CollectionCount(
        collection: json['collection'] as String,
        count: (json['count'] as num).toInt(),
      );

  final String collection;
  final int count;
}

class CollectionOverview {
  const CollectionOverview({required this.total, required this.collections});

  factory CollectionOverview.fromJson(Map<String, dynamic> json) =>
      CollectionOverview(
        total: (json['total'] as num).toInt(),
        collections: (json['collections'] as List<dynamic>)
            .map((e) => CollectionCount.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  final int total;
  final List<CollectionCount> collections;
}

class CollectionItemSummary {
  const CollectionItemSummary({
    required this.collection,
    required this.ident,
    required this.title,
    required this.description,
    required this.year,
    required this.imageUrl,
    required this.hasPdf,
  });

  factory CollectionItemSummary.fromJson(Map<String, dynamic> json) =>
      CollectionItemSummary(
        collection: json['collection'] as String,
        ident: json['ident'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        year: json['year'] as int?,
        imageUrl: json['imageUrl'] as String?,
        hasPdf: json['hasPdf'] as bool? ?? false,
      );

  final String collection;
  final String ident;
  final String title;
  final String description;
  final int? year;
  final String? imageUrl;
  final bool hasPdf;
}

class CollectionItemDetail {
  const CollectionItemDetail({
    required this.collection,
    required this.ident,
    required this.title,
    required this.description,
    required this.year,
    required this.imageUrl,
    required this.pdfUrl,
    required this.detailUrl,
    required this.fields,
  });

  factory CollectionItemDetail.fromJson(Map<String, dynamic> json) =>
      CollectionItemDetail(
        collection: json['collection'] as String,
        ident: json['ident'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        year: json['year'] as int?,
        imageUrl: json['imageUrl'] as String?,
        pdfUrl: json['pdfUrl'] as String?,
        detailUrl: json['detailUrl'] as String? ?? '',
        fields: (json['fields'] as Map<String, dynamic>? ?? const {})
            .map((key, value) => MapEntry(key, value?.toString() ?? '')),
      );

  final String collection;
  final String ident;
  final String title;
  final String description;
  final int? year;
  final String? imageUrl;
  final String? pdfUrl;
  final String detailUrl;
  final Map<String, String> fields;
}

class SearchPage {
  const SearchPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory SearchPage.fromJson(Map<String, dynamic> json) => SearchPage(
    items: (json['items'] as List<dynamic>)
        .map((e) => CollectionItemSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    total: (json['total'] as num).toInt(),
    page: (json['page'] as num).toInt(),
    pageSize: (json['pageSize'] as num).toInt(),
  );

  final List<CollectionItemSummary> items;
  final int total;
  final int page;
  final int pageSize;
}

abstract interface class CollectionSearchSource {
  Future<CollectionOverview> loadOverview();

  /// [fieldQueries] geeft per veldnaam ("title"/"description") een eigen zoekterm;
  /// alle ingevulde velden gelden als EN, naast [query] (dat over alle velden
  /// zoekt). [year] is een exacte match, geen tekst-zoekopdracht.
  Future<SearchPage> search({
    String? query,
    String? collection,
    Map<String, String> fieldQueries = const {},
    int? year,
    int page = 0,
    int size = 20,
  });
  Future<CollectionItemDetail> loadDetail(String collection, String ident);
}
