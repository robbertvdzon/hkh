import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/ai_search/answer_source_dialog.dart';
import 'package:hkh_app/collection/collection_search.dart';

const _url = 'https://hkh.vdzonsoftware.nl/#/objecten/beeldbank/42';
const _dialog = Key('answer-source-dialog');

class _Source extends Fake implements CollectionSearchSource {
  int calls = 0;
  bool fail = false;
  String? collection, ident;

  @override
  Future<CollectionItemDetail> loadDetail(
    String collection,
    String ident,
  ) async {
    calls++;
    this.collection = collection;
    this.ident = ident;
    if (fail) throw StateError('Niet beschikbaar');
    return CollectionItemDetail(
      collection: collection,
      ident: ident,
      title: 'Touwslagerij Van Oosten',
      description: 'De touwslagerij aan de Oosterweg.',
      year: 1920,
      imageUrl: null,
      pdfUrl: null,
      detailUrl: _url,
      fields: const {'Fotograaf': 'Onbekend'},
      documentText: 'De oorspronkelijke tekst uit het archief.',
    );
  }
}

Future<void> _setup(
  WidgetTester tester,
  _Source source, {
  ScrollController? scroll,
  String url = _url,
  Size size = const Size(1000, 900),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: AnswerSourceScope(source: source, child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                if (scroll != null) const SizedBox(height: 800),
                TextButton(
                  onPressed: () => showAnswerSource(
                    context,
                    url: url,
                    source: AnswerSourceScope.maybeOf(context),
                  ),
                  child: const Text('Bekijk bron'),
                ),
                if (scroll != null) const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (scroll != null) {
    scroll.jumpTo(800);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Bekijk bron'));
  await tester.pumpAndSettle();
}

void main() {
  test('only trusted record routes resolve to native collection requests', () {
    for (final url in [
      _url,
      '/#/objecten/beeldbank/42',
      '#/objecten/beeldbank/42',
      '/objecten/beeldbank/42',
      '/zoeken/objecten/beeldbank/42?search=original',
    ]) {
      expect(answerSourceRecord(url), (
        collection: 'beeldbank',
        ident: '42',
      ), reason: url);
    }
    for (final url in [
      'https://other.example/#/objecten/beeldbank/42',
      'https://hkh.vdzonsoftware.nl.other.example/#/objecten/beeldbank/42',
      'https://someone@hkh.vdzonsoftware.nl/#/objecten/beeldbank/42',
      'https://hkh.vdzonsoftware.nl:444/#/objecten/beeldbank/42',
      'javascript:alert(1)',
      '/objecten/beeldbank/%252fadmin',
      '/objecten/beeldbank/%2fadmin',
      '/objecten/beeldbank/..',
      '/objecten/beeldbank/42/extra',
      '/objecten/unknown/42',
      'https://[invalid',
    ]) {
      expect(answerSourceRecord(url), isNull, reason: url);
    }
  });

  for (final escape in [false, true]) {
    testWidgets(
      'native source shows archive content and ${escape ? 'Escape' : 'close'} preserves reading position',
      (tester) async {
        final source = _Source(), scroll = ScrollController();
        addTearDown(scroll.dispose);
        await _setup(tester, source, scroll: scroll);
        expect(source.calls, 1);
        expect(source.collection, 'beeldbank');
        expect(source.ident, '42');
        expect(find.byKey(_dialog), findsOneWidget);
        expect(find.text('Touwslagerij Van Oosten'), findsOneWidget);
        expect(find.text('De touwslagerij aan de Oosterweg.'), findsOneWidget);
        expect(find.text('Fotograaf'), findsOneWidget);
        expect(find.text('Onbekend'), findsOneWidget);
        expect(
          find.text('De oorspronkelijke tekst uit het archief.'),
          findsOneWidget,
        );
        expect(find.text('Open volledige pagina'), findsOneWidget);
        if (escape) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.tap(find.byKey(const Key('answer-source-close')));
        }
        await tester.pumpAndSettle();
        expect(find.byKey(_dialog), findsNothing);
        expect(scroll.offset, 800);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('load failure can retry without leaving the answer', (
    tester,
  ) async {
    final source = _Source()..fail = true;
    await _setup(tester, source);
    expect(find.text('Deze bron kon niet worden geladen.'), findsOneWidget);
    expect(
      find.byKey(const Key('answer-source-close')).hitTestable(),
      findsOneWidget,
    );
    source.fail = false;
    await tester.tap(find.text('Opnieuw proberen'));
    await tester.pumpAndSettle();
    expect(source.calls, 2);
    expect(find.text('Touwslagerij Van Oosten'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('external source does not load a local collection record', (
    tester,
  ) async {
    final source = _Source();
    await _setup(
      tester,
      source,
      url: 'https://other.example/#/objecten/beeldbank/42',
    );
    expect(source.calls, 0);
    expect(find.byKey(_dialog), findsOneWidget);
    expect(find.text('Open volledige pagina'), findsOneWidget);
    await tester.tap(find.text('Sluiten'));
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsafe URL stays inert inside the popup', (tester) async {
    final source = _Source();
    await _setup(tester, source, url: 'javascript:alert(1)');
    expect(source.calls, 0);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('answer-source-open-page')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text('Deze bron kan hier niet worden weergegeven.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening full page is explicit and keeps the popup open', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launches = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      launches.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await _setup(tester, _Source());
    expect(launches, isEmpty);
    await tester.tap(find.byKey(const Key('answer-source-open-page')));
    await tester.pumpAndSettle();
    expect(launches, hasLength(1));
    expect((launches.single.arguments as Map)['url'], _url);
    expect(find.byKey(_dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile at 200 percent keeps content and close controls usable', (
    tester,
  ) async {
    await _setup(tester, _Source(), size: const Size(320, 800), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('answer-source-close')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('answer-source-open-page')).hitTestable(),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('De oorspronkelijke tekst uit het archief.'),
      150,
      scrollable: find.descendant(
        of: find.byKey(const Key('answer-source-content')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('answer-source-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(_dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
