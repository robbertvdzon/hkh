class AiSourceRef {
  const AiSourceRef({required this.collection, required this.ident});

  factory AiSourceRef.fromJson(Map<String, dynamic> json) => AiSourceRef(
    collection: json['collection'] as String? ?? '',
    ident: json['ident'] as String? ?? '',
  );

  final String collection;
  final String ident;
}

class AiSearchTurn {
  const AiSearchTurn({
    required this.id,
    required this.turnNumber,
    required this.question,
    required this.status,
    required this.progressPercent,
    required this.progressMessage,
    required this.title,
    required this.answerHtml,
    required this.sources,
    required this.suggestedFollowUps,
    required this.errorMessage,
    required this.createdAt,
  });

  factory AiSearchTurn.fromJson(Map<String, dynamic> json) => AiSearchTurn(
    id: json['id'] as String,
    turnNumber: (json['turnNumber'] as num).toInt(),
    question: json['question'] as String,
    status: json['status'] as String,
    progressPercent: (json['progressPercent'] as num?)?.toInt(),
    progressMessage: json['progressMessage'] as String?,
    title: json['title'] as String?,
    answerHtml: json['answerHtml'] as String?,
    sources: (json['sources'] as List<dynamic>? ?? const [])
        .map((item) => AiSourceRef.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    suggestedFollowUps:
        (json['suggestedFollowUps'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
    errorMessage: json['errorMessage'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  final String id;
  final int turnNumber;
  final String question;
  final String status;
  final int? progressPercent;
  final String? progressMessage;
  final String? title;
  final String? answerHtml;
  final List<AiSourceRef> sources;
  final List<String> suggestedFollowUps;
  final String? errorMessage;
  final DateTime createdAt;

  bool get isActive =>
      const {'SUBMITTING', 'QUEUED', 'RUNNING'}.contains(status);
}

class AiSearchSession {
  const AiSearchSession({required this.id, required this.turns});

  factory AiSearchSession.fromJson(Map<String, dynamic> json) =>
      AiSearchSession(
        id: json['id'] as String,
        turns: (json['turns'] as List<dynamic>? ?? const [])
            .map((item) => AiSearchTurn.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );

  final String id;
  final List<AiSearchTurn> turns;
}

abstract interface class AiSearchSource {
  Future<AiSearchSession> startAiSearch(String question);
  Future<AiSearchSession> loadAiSearch(String sessionId);
  Future<AiSearchSession> askFollowUp(String sessionId, String question);
  Future<AiSearchSession> cancelAiSearch(String sessionId);
}
