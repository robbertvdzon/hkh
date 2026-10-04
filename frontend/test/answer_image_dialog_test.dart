import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/ai_search/answer_html.dart';
import 'package:hkh_app/ai_search/answer_image_dialog.dart';

const _imageUrl = 'https://images.example.test/archief/origineel.jpg';
const _description = 'Touwslagerij Van Oosten aan de Oosterweg';
const _viewerKey = Key('answer-image-viewer');
const _dialogKey = Key('answer-image-dialog');

Future<void> _open(
  WidgetTester tester, {
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
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAnswerImage(
              context,
              imageUrl: _imageUrl,
              description: _description,
            ),
            child: const Text('Open foto'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open foto'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

TransformationController _controller(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byKey(_viewerKey))
    .transformationController!;

void main() {
  for (final linked in [false, true]) {
    testWidgets(
      '${linked ? 'linked' : 'plain'} answer image opens the photo and returns to the same reading position',
      (tester) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        const image = '<img src="$_imageUrl" alt="$_description">';
        final html = linked
            ? '<a href="https://archive.example.test/bronnen/42">$image</a>'
            : image;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    const SizedBox(height: 800),
                    AnswerHtml(html),
                    const SizedBox(height: 1000),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        scroll.jumpTo(800);
        await tester.pumpAndSettle();
        final readingPosition = scroll.offset;
        await tester.tap(find.byTooltip('Foto vergroten'));
        await tester.pumpAndSettle();

        expect(find.byKey(_dialogKey), findsOneWidget);
        final dialog = tester.widget<AnswerImageDialog>(
          find.byType(AnswerImageDialog),
        );
        expect(dialog.imageUrl, _imageUrl);
        expect(dialog.description, _description);
        final fullImage = tester.widget<Image>(
          find.descendant(
            of: find.byKey(_viewerKey),
            matching: find.byType(Image),
          ),
        );
        expect((fullImage.image as NetworkImage).url, _imageUrl);
        // The opened photo must not keep the source page's clickable link.
        expect(
          find.descendant(
            of: find.byKey(_viewerKey),
            matching: find.byType(InkWell),
          ),
          findsNothing,
        );

        if (linked) {
          await _tap(tester, 'answer-image-close');
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
        expect(find.byKey(_dialogKey), findsNothing);
        expect(find.byTooltip('Foto vergroten'), findsOneWidget);
        expect(scroll.offset, readingPosition);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('zoom controls preserve the viewed center and reset the photo', (
    tester,
  ) async {
    await _open(tester);
    final viewport = tester.getSize(find.byKey(_viewerKey));
    final center = viewport.center(Offset.zero);
    final initialCenter = _controller(tester).toScene(center);
    await _tap(tester, 'answer-image-zoom-in');
    final enlargedScale = _controller(tester).value.getMaxScaleOnAxis();
    expect(enlargedScale, greaterThan(1));
    expect(
      (_controller(tester).toScene(center) - initialCenter).distance,
      lessThan(0.01),
    );
    await _tap(tester, 'answer-image-zoom-out');
    expect(
      _controller(tester).value.getMaxScaleOnAxis(),
      lessThan(enlargedScale),
    );
    for (var i = 0; i < 12; i++) {
      await _tap(tester, 'answer-image-zoom-in');
    }
    expect(_controller(tester).value.getMaxScaleOnAxis(), closeTo(12, 0.001));
    await _tap(tester, 'answer-image-reset');
    expect(_controller(tester).value, Matrix4.identity());
    await _tap(tester, 'answer-image-zoom-out');
    expect(_controller(tester).value, Matrix4.identity());
    expect(tester.takeException(), isNull);
  });

  testWidgets('two-finger pinch enlarges a photo on a phone', (tester) async {
    await _open(tester, size: const Size(390, 844));
    final center = tester.getCenter(find.byKey(_viewerKey));
    final first = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    await tester.pump();
    for (var distance = 40.0; distance <= 100; distance += 20) {
      await first.moveTo(center - Offset(distance, 0));
      await second.moveTo(center + Offset(distance, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(_controller(tester).value.getMaxScaleOnAxis(), greaterThan(1.5));
    await _tap(tester, 'answer-image-reset');
    expect(_controller(tester).value, Matrix4.identity());
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px and 200% text keep zoom and close controls reachable', (
    tester,
  ) async {
    await _open(tester, size: const Size(320, 800), textScale: 2);
    expect(tester.takeException(), isNull);
    for (final key in [
      'answer-image-zoom-in',
      'answer-image-zoom-out',
      'answer-image-reset',
    ]) {
      await _tap(tester, key);
      expect(tester.takeException(), isNull);
    }
    await _tap(tester, 'answer-image-close');
    expect(find.byKey(_dialogKey), findsNothing);
    expect(find.text('Open foto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
