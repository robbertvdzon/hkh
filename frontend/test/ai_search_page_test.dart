import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/ai_search/ai_search.dart';
import 'package:hkh_app/ai_search/ai_search_page.dart';

class _AiSource implements AiSearchSource {
  AiSearchSession? session;

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
  });
}
