import '../ai_search/ai_search.dart';
import 'dossier.dart';

/// Laat de bestaande AI-zoekpagina werken op de vragen van één dossier.
class DossierQuestionSource implements AiSearchSource {
  const DossierQuestionSource({required this.source, required this.dossierId});

  final DossierSource source;
  final String dossierId;

  @override
  Future<List<AiSearchSummary>> listAiSearches() =>
      source.listQuestions(dossierId);

  @override
  Future<AiSearchSession> startAiSearch(String question) =>
      source.askQuestion(dossierId, question);

  @override
  Future<AiSearchSession> loadAiSearch(String sessionId) =>
      source.loadQuestion(dossierId, sessionId);

  @override
  Future<AiSearchSession> askFollowUp(String sessionId, String question) =>
      source.askFollowUpQuestion(dossierId, sessionId, question);

  @override
  Future<AiSearchSession> cancelAiSearch(String sessionId) =>
      source.cancelQuestion(dossierId, sessionId);

  @override
  Future<void> deleteAiSearch(String sessionId) =>
      source.deleteQuestion(dossierId, sessionId);
}
