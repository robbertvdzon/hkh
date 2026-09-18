import 'dart:async';
import 'dart:typed_data';

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

AiSearchTurn _answeredTurn({String id = 'turn-1'}) => AiSearchTurn(
  id: id,
  turnNumber: 1,
  question: 'Wie was Jan Klaasz. Beemster?',
  status: 'SUCCEEDED',
  progressPercent: 100,
  progressMessage: 'Onderzoek afgerond',
  title: 'Jan Klaasz. Beemster',
  answerHtml: '<p>Hij was schepen en molenaar in Heemskerk.</p>',
  sources: const [],
  suggestedFollowUps: const [],
  errorMessage: null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  completedAt: DateTime(2026),
  durationSeconds: 60,
);

/// Levert het geladen antwoord; de exportactie hoort daarna zichtbaar te zijn.
class _AnsweredSource extends _AiSource {
  _AnsweredSource() {
    session = AiSearchSession(id: 'session-1', turns: [_answeredTurn()]);
  }
}

class _DelayedPollSource extends _AiSource {
  final pendingPoll = Completer<AiSearchSession>();
  int loads = 0;

  @override
  Future<AiSearchSession> loadAiSearch(String sessionId) {
    loads++;
    return loads == 1 ? Future.value(session!) : pendingPoll.future;
  }
}

class _PdfSource implements AiAnswerPdfSource {
  _PdfSource({this.failing = false});

  bool failing;
  int calls = 0;
  final List<String> requestedIds = [];
  Completer<Uint8List>? pending;

  @override
  Future<Uint8List> exportAnswerPdf(String answerId) {
    calls++;
    requestedIds.add(answerId);
    if (pending case final completer?) return completer.future;
    if (failing) return Future.error(StateError('mislukt'));
    return Future.value(Uint8List.fromList('%PDF-1.4'.codeUnits));
  }
}

class _RecordingSaver {
  final List<String> savedNames = [];
  final List<int> savedSizes = [];

  Future<void> save(String fileName, Uint8List bytes) async {
    savedNames.add(fileName);
    savedSizes.add(bytes.length);
  }
}

class _RouteRecorder extends NavigatorObserver {
  int pushes = 0;
  int pops = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
}

void main() {
  testWidgets('each answer downloads its own PDF', (tester) async {
    final source = _AnsweredSource()
      ..session = AiSearchSession(
        id: 'session-1',
        turns: [
          _answeredTurn(),
          _answeredTurn(id: 'turn-2'),
        ],
      );
    final pdf = _PdfSource();
    await tester.pumpWidget(
      MaterialApp(
        home: AiSearchPage(
          source: source,
          initialSessionId: 'session-1',
          pdfSource: pdf,
          pdfSaver: _RecordingSaver().save,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final second = find.byKey(const ValueKey('answer-pdf-turn-2'));
    await tester.scrollUntilVisible(
      second,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(pdf.requestedIds, ['turn-2']);
  });

  testWidgets(
    'a delayed poll cannot reopen an answer after returning to overview',
    (tester) async {
      final source = _DelayedPollSource();
      await source.startAiSearch('Wat is er bekend over de Kerklaan?');
      await tester.pumpWidget(
        MaterialApp(
          home: AiSearchPage(source: source, initialSessionId: 'session-1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(source.loads, 2);
      await tester.tap(find.byTooltip('Terug naar Vraag het archief'));
      await tester.pumpAndSettle();
      source.pendingPoll.complete(source.session!);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ai-question-card')), findsOneWidget);
      expect(find.text('De beeldbank wordt onderzocht'), findsNothing);
    },
  );

  testWidgets('starts a free archive question and shows progress', (
    tester,
  ) async {
    final source = _AiSource();
    await tester.pumpWidget(MaterialApp(home: AiSearchPage(source: source)));

    await tester.enterText(
      find.byType(TextField),
      'Wat is er bekend over de Kerklaan?',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ai-question-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-question-button')));
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

  testWidgets('shows an enabled pdf export action once an answer is loaded', (
    tester,
  ) async {
    final source = _AnsweredSource();
    final pdfSource = _PdfSource();
    final saver = _RecordingSaver();

    await tester.pumpWidget(
      MaterialApp(
        home: AiSearchPage(
          source: source,
          initialSessionId: 'session-1',
          pdfSource: pdfSource,
          pdfSaver: saver.save,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.widgetWithText(OutlinedButton, 'Download PDF');
    expect(action, findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    expect(tester.widget<OutlinedButton>(action).onPressed, isNotNull);
    expect(find.byTooltip('Mijn zoekopdrachten'), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: action),
      findsNothing,
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(pdfSource.requestedIds, ['turn-1']);
    expect(saver.savedNames, ['antwoord-turn-1.pdf']);
    expect(saver.savedSizes.single, greaterThan(0));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('has no export action before an answer is loaded', (
    tester,
  ) async {
    final source = _AiSource();
    final pdfSource = _PdfSource();

    await tester.pumpWidget(
      MaterialApp(
        home: AiSearchPage(source: source, pdfSource: pdfSource),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.widgetWithText(OutlinedButton, 'Download PDF'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Wat is er bekend?');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ai-question-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-question-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Het onderzoek loopt nog, dus er valt nog niets te exporteren.
    expect(find.widgetWithText(OutlinedButton, 'Download PDF'), findsNothing);
    expect(pdfSource.calls, 0);
  });

  testWidgets('a failed export shows the retry snackbar without navigating', (
    tester,
  ) async {
    final source = _AnsweredSource();
    final pdfSource = _PdfSource(failing: true);
    final saver = _RecordingSaver();
    final routes = _RouteRecorder();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routes],
        home: AiSearchPage(
          source: source,
          initialSessionId: 'session-1',
          pdfSource: pdfSource,
          pdfSaver: saver.save,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pushesBefore = routes.pushes;

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Download PDF'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Download PDF'));
    await tester.pumpAndSettle();

    expect(
      find.text('PDF-export mislukt. Probeer het opnieuw.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(SnackBarAction, 'Opnieuw'), findsOneWidget);
    expect(saver.savedNames, isEmpty);
    expect(find.text('Jan Klaasz. Beemster'), findsOneWidget);
    expect(routes.pushes, pushesBefore);
    expect(routes.pops, 0);

    await tester.tap(find.text('Opnieuw'));
    await tester.pumpAndSettle();

    expect(pdfSource.calls, 2);
    expect(
      find.text('PDF-export mislukt. Probeer het opnieuw.'),
      findsOneWidget,
    );
    expect(saver.savedNames, isEmpty);
  });

  testWidgets('the export action is inactive while an export is running', (
    tester,
  ) async {
    final source = _AnsweredSource();
    final pdfSource = _PdfSource()..pending = Completer<Uint8List>();
    final saver = _RecordingSaver();

    await tester.pumpWidget(
      MaterialApp(
        home: AiSearchPage(
          source: source,
          initialSessionId: 'session-1',
          pdfSource: pdfSource,
          pdfSaver: saver.save,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Download PDF'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Download PDF'));
    await tester.pump();

    final busyButton = find.widgetWithText(OutlinedButton, 'PDF maken…');
    expect(
      find.descendant(
        of: busyButton,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<OutlinedButton>(busyButton).onPressed, isNull);

    pdfSource.pending!.complete(Uint8List.fromList('%PDF-1.4'.codeUnits));
    pdfSource.pending = null;
    await tester.pumpAndSettle();

    expect(pdfSource.calls, 1);
    expect(saver.savedNames, ['antwoord-turn-1.pdf']);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });
}
