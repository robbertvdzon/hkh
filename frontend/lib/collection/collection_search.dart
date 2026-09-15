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
    this.thumbnailUrl,
    this.fields = const {},
  });

  factory CollectionItemSummary.fromJson(Map<String, dynamic> json) =>
      CollectionItemSummary(
        collection: json['collection'] as String,
        ident: json['ident'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        year: json['year'] as int?,
        imageUrl: json['imageUrl'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        hasPdf: json['hasPdf'] as bool? ?? false,
        fields: (json['fields'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v.toString()),
        ),
      );

  final String collection;
  final String ident;
  final String title;
  final String description;
  final int? year;
  final String? imageUrl;
  final String? thumbnailUrl;
  final bool hasPdf;
  final Map<String, String> fields;
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
        fields: (json['fields'] as Map<String, dynamic>? ?? const {}).map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
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
    this.documentTextAvailable = false,
  });

  factory SearchPage.fromJson(Map<String, dynamic> json) => SearchPage(
    items: (json['items'] as List<dynamic>)
        .map((e) => CollectionItemSummary.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
    total: (json['total'] as num).toInt(),
    page: (json['page'] as num).toInt(),
    pageSize: (json['pageSize'] as num).toInt(),
    documentTextAvailable: json['documentTextAvailable'] as bool? ?? false,
  );

  final List<CollectionItemSummary> items;
  final int total;
  final int page;
  final int pageSize;
  final bool documentTextAvailable;
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
    CollectionSearchOptions? options,
  });
  Future<CollectionFacet> loadFacet({
    required String collection,
    required String field,
    String query = '',
    Map<String, String> fieldQueries = const {},
    int? year,
    CollectionSearchOptions? options,
    String valueQuery = '',
  });
  Future<CollectionItemDetail> loadDetail(String collection, String ident);
}

/// URL-serializable search settings. Filters are exact alternatives within a field.
class CollectionSearchOptions {
  const CollectionSearchOptions({
    this.mode = 'and',
    this.partial = true,
    this.field = 'all',
    this.yearFrom,
    this.yearTo,
    this.filters = const {},
    this.sort = 'relevance',
    this.recentDays,
    this.documentText = true,
    this.view,
  });
  final String mode, field, sort;
  final bool partial, documentText;
  final int? yearFrom, yearTo, recentDays;
  final Map<String, List<String>> filters;
  final String? view;

  factory CollectionSearchOptions.fromParameters(Map<String, List<String>> p) {
    String? value(String key) => p[key]?.firstOrNull;
    final filters = <String, List<String>>{};
    for (final raw in p['filter'] ?? <String>[]) {
      final colon = raw.indexOf(':');
      if (colon > 0) {
        (filters[raw.substring(0, colon)] ??= []).add(raw.substring(colon + 1));
      }
    }
    return CollectionSearchOptions(
      mode: value('mode') ?? 'web',
      partial: value('partial') == 'true',
      field: value('field') ?? 'all',
      yearFrom: int.tryParse(value('from') ?? ''),
      yearTo: int.tryParse(value('to') ?? ''),
      filters: filters,
      sort: value('sort') ?? 'relevance',
      recentDays: int.tryParse(value('recent') ?? ''),
      documentText: value('documentText') != 'false',
      view: value('view'),
    );
  }

  Map<String, dynamic> toParameters({bool includeView = true}) => {
    'mode': mode,
    'partial': '$partial',
    if (field != 'all') 'field': field,
    if (yearFrom != null) 'from': '$yearFrom',
    if (yearTo != null) 'to': '$yearTo',
    if (filters.isNotEmpty)
      'filter': [
        for (final e in filters.entries)
          for (final v in e.value) '${e.key}:$v',
      ],
    if (sort != 'relevance') 'sort': sort,
    if (recentDays != null) 'recent': '$recentDays',
    if (!documentText) 'documentText': 'false',
    if (includeView && view != null) 'view': view,
  };

  CollectionSearchOptions copyWith({
    String? mode,
    bool? partial,
    String? field,
    int? yearFrom,
    int? yearTo,
    bool clearPeriod = false,
    Map<String, List<String>>? filters,
    String? sort,
    int? recentDays,
    bool clearRecent = false,
    bool? documentText,
    String? view,
  }) => CollectionSearchOptions(
    mode: mode ?? this.mode,
    partial: partial ?? this.partial,
    field: field ?? this.field,
    yearFrom: clearPeriod ? yearFrom : yearFrom ?? this.yearFrom,
    yearTo: clearPeriod ? yearTo : yearTo ?? this.yearTo,
    filters: filters ?? this.filters,
    sort: sort ?? this.sort,
    recentDays: clearRecent ? recentDays : recentDays ?? this.recentDays,
    documentText: documentText ?? this.documentText,
    view: view ?? this.view,
  );
}

class FacetValue {
  const FacetValue(this.value, this.count);
  final String value;
  final int count;
}

class CollectionFacet {
  const CollectionFacet({
    required this.field,
    this.values = const [],
    this.totalValues = 0,
  });
  final String field;
  final List<FacetValue> values;
  final int totalValues;
  factory CollectionFacet.fromJson(Map<String, dynamic> json) =>
      CollectionFacet(
        field: json['field'] as String,
        values: (json['values'] as List)
            .map(
              (e) =>
                  FacetValue(e['value'] as String, (e['count'] as num).toInt()),
            )
            .toList(),
        totalValues: (json['totalValues'] as num).toInt(),
      );
}
