import 'ai_search.dart';

class SharedAiAnswer {
  const SharedAiAnswer({
    required this.question,
    required this.title,
    required this.answerHtml,
    required this.sharedAt,
  });
  factory SharedAiAnswer.fromJson(Map<String, dynamic> json) => SharedAiAnswer(
    question: json['question'] as String,
    title: json['title'] as String?,
    answerHtml: json['answerHtml'] as String,
    sharedAt: DateTime.parse(json['sharedAt'] as String),
  );
  final String question;
  final String? title;
  final String answerHtml;
  final DateTime sharedAt;
}

/// Delen is losgekoppeld van het stellen of bewerken van vragen.
abstract interface class AiAnswerShareSource {
  Future<String?> answerShareToken(String answerId);
  Future<String> shareAnswer(String answerId);
  Future<void> revokeAnswerShare(String answerId);
  Future<SharedAiAnswer?> loadSharedAnswer(String token);
}

String sharedAnswerUrl(String token) {
  final base = Uri.base;
  final origin = base.scheme == 'http' || base.scheme == 'https'
      ? Uri(
          scheme: base.scheme,
          host: base.host,
          port: base.hasPort ? base.port : null,
          path: base.path,
        ).toString()
      : 'https://hkh.vdzonsoftware.nl/';
  return '$origin#/gedeeld/${Uri.encodeComponent(token)}';
}

AiAnswerShareSource? shareSourceFor(AiSearchSource source) =>
    source is AiAnswerShareSource ? source as AiAnswerShareSource : null;
