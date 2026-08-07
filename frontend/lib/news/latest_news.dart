class LatestNewsItem {
  const LatestNewsItem({
    required this.id,
    required this.title,
    required this.message,
    required this.publishedAt,
  });

  factory LatestNewsItem.fromJson(Map<String, dynamic> json) => LatestNewsItem(
    id: json['id'] as int,
    title: json['title'] as String,
    message: json['message'] as String,
    publishedAt: DateTime.parse(json['publishedAt'] as String),
  );

  final int id;
  final String title;
  final String message;
  final DateTime publishedAt;
}

abstract interface class LatestNewsSource {
  Future<List<LatestNewsItem>> loadLatestNews();
}
