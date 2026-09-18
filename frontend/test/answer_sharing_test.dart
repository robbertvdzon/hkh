import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/ai_search/ai_search.dart';
import 'package:hkh_app/ai_search/answer_share_dialog.dart';
import 'package:hkh_app/ai_search/answer_sharing.dart';
import 'package:hkh_app/ai_search/shared_answer_page.dart';

class _Shares implements AiAnswerShareSource {
  String? token;
  int creates = 0;
  @override
  Future<String?> answerShareToken(String id) async => token;
  @override
  Future<String> shareAnswer(String id) async => token = 'link-${++creates}';
  @override
  Future<void> revokeAnswerShare(String id) async => token = null;
  @override
  Future<SharedAiAnswer?> loadSharedAnswer(String requested) async =>
      requested != token
      ? null
      : SharedAiAnswer(
          question: 'Wat is de geschiedenis van de Kerklaan?',
          title: 'De Kerklaan',
          answerHtml: '<p>Een gedeeld antwoord met een bron.</p>',
          sharedAt: DateTime(2026, 9, 18),
        );
}

final answer = AiSearchTurn(
  id: 'answer-1',
  turnNumber: 1,
  question: 'De Kerklaan?',
  status: 'SUCCEEDED',
  progressPercent: 100,
  progressMessage: null,
  title: 'De Kerklaan',
  answerHtml: '<p>Een antwoord</p>',
  sources: const [],
  suggestedFollowUps: const [],
  errorMessage: null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  completedAt: DateTime(2026),
  durationSeconds: 60,
);

void main() {
  testWidgets(
    'owner explicitly creates copies revokes and replaces a link on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = _Shares();
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAnswerShareDialog(context, source, answer),
                child: const Text('Antwoord delen'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Antwoord delen'));
      await tester.pumpAndSettle();
      expect(source.creates, 0);
      await tester.tap(find.text('Maak deelbare link'));
      await tester.pumpAndSettle();
      expect(source.creates, 1);
      await tester.ensureVisible(find.text('Kopieer link'));
      await tester.tap(find.text('Kopieer link'));
      await tester.pumpAndSettle();
      expect(clipboard, 'https://hkh.vdzonsoftware.nl/#/gedeeld/link-1');
      expect(find.text('Link gekopieerd'), findsOneWidget);
      await tester.ensureVisible(find.text('Delen stoppen'));
      await tester.tap(find.text('Delen stoppen'));
      await tester.pumpAndSettle();
      expect(source.token, isNull);
      await tester.ensureVisible(find.text('Maak deelbare link'));
      await tester.tap(find.text('Maak deelbare link'));
      await tester.pumpAndSettle();
      expect(source.token, 'link-2');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared reader has no question or management actions and revoked links explain what happened',
    (tester) async {
      final source = _Shares()..token = 'active';
      await tester.pumpWidget(
        MaterialApp(
          home: SharedAnswerPage(source: source, token: 'active'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('De Kerklaan'), findsOneWidget);
      expect(
        find.text('Wat is de geschiedenis van de Kerklaan?'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Delen stoppen'), findsNothing);
      await source.revokeAnswerShare('answer-1');
      await tester.pumpWidget(
        MaterialApp(
          home: SharedAnswerPage(
            key: const ValueKey('reopened'),
            source: source,
            token: 'active',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Deze deellink is niet meer beschikbaar.'),
        findsOneWidget,
      );
      expect(find.text('De Kerklaan'), findsNothing);
    },
  );
}
