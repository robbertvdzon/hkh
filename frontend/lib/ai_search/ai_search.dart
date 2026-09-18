import 'dart:typed_data';

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
    required this.updatedAt,
    required this.completedAt,
    required this.durationSeconds,
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
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
    durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
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
  final DateTime updatedAt;
  final DateTime? completedAt;
  final int durationSeconds;

  bool get isActive =>
      const {'SUBMITTING', 'QUEUED', 'RUNNING'}.contains(status);
}

class AiSearchSummary {
  const AiSearchSummary({
    required this.id,
    required this.question,
    required this.title,
    required this.status,
    required this.progressPercent,
    required this.progressMessage,
    required this.turnCount,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
    required this.durationSeconds,
  });

  factory AiSearchSummary.fromJson(Map<String, dynamic> json) =>
      AiSearchSummary(
        id: json['id'] as String,
        question: json['question'] as String,
        title: json['title'] as String?,
        status: json['status'] as String,
        progressPercent: (json['progressPercent'] as num?)?.toInt(),
        progressMessage: json['progressMessage'] as String?,
        turnCount: (json['turnCount'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String question;
  final String? title;
  final String status;
  final int? progressPercent;
  final String? progressMessage;
  final int turnCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final int durationSeconds;

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
  Future<List<AiSearchSummary>> listAiSearches();
  Future<AiSearchSession> startAiSearch(String question);
  Future<AiSearchSession> loadAiSearch(String sessionId);
  Future<AiSearchSession> askFollowUp(String sessionId, String question);
  Future<AiSearchSession> cancelAiSearch(String sessionId);
  Future<void> deleteAiSearch(String sessionId);
}

/// Haalt een geslaagd AI-antwoord op als PDF-bytes. Staat los van [AiSearchSource]
/// zodat schermen zonder exportactie (zoals het dossiertabblad) ongewijzigd blijven.
abstract interface class AiAnswerPdfSource {
  Future<Uint8List> exportAnswerPdf(String answerId);
}

/// Biedt de geëxporteerde PDF aan de gebruiker aan: downloaden op web,
/// delen/opslaan op Android. Zie `answer_pdf_saver.dart`.
typedef AnswerPdfSaver =
    Future<void> Function(String fileName, Uint8List bytes);

/// Koppelt de anonieme vragen uit deze browser aan de ingelogde gebruiker.
abstract interface class AiSearchAccountSource {
  Future<void> syncAiSearchAccount();
}
