import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/ai_search/ai_search.dart';
import 'package:hkh_app/ai_search/ai_search_page.dart';

class _AiSource implements AiSearchSource {
  AiSearchSession? session;
  final List<AiSearchSummary> searches = [];

  @override
  Future<List<AiSearchSummary>> listAiSearches() async => searches;

  @override
  Future<AiSearchSession> startAiSearch(String question) async {
    session = AiSearchSession(
      id: 'session-1',
      turns: [
        AiSearchTurn(
          id: 'turn-1',
          turnNumber: 1,
          question: question,
          status: 'RUNNING',
          progressPercent: 20,
          progressMessage: 'De beeldbank wordt onderzocht',
          title: null,
          answerHtml: null,
          sources: const [],
          suggestedFollowUps: const [],
          errorMessage: null,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          completedAt: null,
          durationSeconds: 12,
        ),
      ],
    );
    return session!;
  }

  @override
  Future<AiSearchSession> loadAiSearch(String sessionId) async => session!;

  @override
  Future<AiSearchSession> askFollowUp(
    String sessionId,
    String question,
  ) async => session!;

  @override
  Future<AiSearchSession> cancelAiSearch(String sessionId) async => session!;

  @override
  Future<void> deleteAiSearch(String sessionId) async {
    searches.removeWhere((search) => search.id == sessionId);
  }
}

void main() {
  testWidgets('starts a free archive question and shows progress', (
    tester,
  ) async {
    final source = _AiSource();
    await tester.pumpWidget(MaterialApp(home: AiSearchPage(source: source)));

    await tester.enterText(
      find.byType(TextField),
      'Wat is er bekend over de Kerklaan?',
    );
    await tester.tap(find.byTooltip('Vraag stellen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Wat is er bekend over de Kerklaan?'), findsOneWidget);
    expect(find.text('De beeldbank wordt onderzocht'), findsOneWidget);
    expect(find.textContaining('20%'), findsOneWidget);
    expect(find.text('Stoppen'), findsOneWidget);
    expect(find.textContaining('enkele minuten'), findsOneWidget);
  });

  testWidgets('shows persisted searches with duration and delete action', (
    tester,
  ) async {
    final source = _AiSource();
    source.searches.add(
      AiSearchSummary(
        id: 'saved-1',
        question: 'Wat gebeurde er aan de Kerklaan?',
        title: 'De geschiedenis van de Kerklaan',
        status: 'SUCCEEDED',
        progressPercent: 100,
        progressMessage: 'Onderzoek afgerond',
        turnCount: 1,
        createdAt: DateTime(2026, 9, 12, 10),
        updatedAt: DateTime(2026, 9, 12, 10, 2),
        completedAt: DateTime(2026, 9, 12, 10, 2),
        durationSeconds: 125,
      ),
    );

    await tester.pumpWidget(MaterialApp(home: AiSearchPage(source: source)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();

    expect(find.text('Mijn zoekopdrachten'), findsOneWidget);
    expect(find.text('De geschiedenis van de Kerklaan'), findsOneWidget);
    expect(find.text('Duur: 2 min 05 sec'), findsOneWidget);
    expect(find.byTooltip('Zoekopdracht verwijderen'), findsOneWidget);
  });
}
