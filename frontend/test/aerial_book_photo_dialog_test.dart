import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/aerial/aerial_book_photo_dialog.dart';

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(1000, 1000),
  double textScale = 1,
  AssetBundle? bundle,
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
        child: bundle == null
            ? child!
            : DefaultAssetBundle(bundle: bundle, child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAerialBookPhotos(context),
            child: const Text('Open bronfoto’s'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open bronfoto’s'));
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
    .widget<InteractiveViewer>(find.byKey(const Key('aerial-book-viewer')))
    .transformationController!;

void main() {
  testWidgets('all seven originals retain their own year, status and image', (
    tester,
  ) async {
    await _open(tester);
    const photos = [
      ('62057', 1963),
      ('62058', 1963),
      ('62059', 1963),
      ('64797', 1964),
      ('67781', 1965),
      ('67782', 1965),
      ('67783', 1965),
    ];
    for (var i = 0; i < photos.length; i++) {
      final (number, year) = photos[i];
      expect(find.text('$year · Boekfoto $number'), findsOneWidget);
      final status = tester.widget<Text>(
        find.byKey(const Key('aerial-book-status')),
      );
      expect(
        status.data,
        number == '62057' ? 'In de vergelijking' : 'Extra bronfoto',
      );
      expect(
        find.text(
          number == '62057'
              ? 'Deze foto vormt de historische laag in de vergelijking met nu.'
              : 'Bekijk het origineel en zoom in op de details.',
        ),
        findsOneWidget,
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/aerial/book/$year-$number.jpeg',
      );
      expect(image.fit, BoxFit.contain);
      expect(_controller(tester).value, Matrix4.identity());
      await _tap(tester, 'aerial-book-zoom-in');
      expect(_controller(tester).value.getMaxScaleOnAxis(), greaterThan(1));
      if (i < photos.length - 1) await _tap(tester, 'aerial-book-next');
    }
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('aerial-book-next')))
          .onPressed,
      isNull,
    );
    await _tap(tester, 'aerial-book-close');
    expect(find.byKey(const Key('aerial-book-dialog')), findsNothing);
    expect(find.text('Open bronfoto’s'), findsOneWidget);
  });

  testWidgets(
    'dropdown selects a photo and 320px at 200% keeps controls reachable',
    (tester) async {
      await _open(tester, size: const Size(320, 800), textScale: 2);
      expect(tester.takeException(), isNull);
      await _tap(tester, 'aerial-book-select');
      final option = find.text('1965 · 67782');
      await tester.scrollUntilVisible(
        option,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(find.text('1965 · Boekfoto 67782'), findsOneWidget);
      expect(find.text('Extra bronfoto'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final key in [
        'aerial-book-next',
        'aerial-book-previous',
        'aerial-book-zoom-in',
        'aerial-book-zoom-out',
        'aerial-book-reset',
      ]) {
        await _tap(tester, key);
        expect(tester.takeException(), isNull);
      }
      expect(_controller(tester).value, Matrix4.identity());
      await _tap(tester, 'aerial-book-close');
      expect(find.byKey(const Key('aerial-book-dialog')), findsNothing);
    },
  );

  testWidgets('an unavailable original shows a readable error', (tester) async {
    await _open(tester, bundle: _MissingPhotos());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    expect(find.text('Deze bronfoto kon niet worden geladen.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'aerial-book-close');
  });
}

class _MissingPhotos extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.startsWith('assets/aerial/book/')) {
      throw FlutterError('Missing test photo');
    }
    return rootBundle.load(key);
  }
}
