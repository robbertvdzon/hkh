import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hkh_app/aerial/aerial_photo_page.dart';

const _imageSize = Size(2040, 1120);
final _viewerFinder = find.byKey(const Key('aerial-viewer'));

Future<void> _pumpPage(
  WidgetTester tester, {
  Size size = const Size(1400, 1200),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Real image decoding must finish outside the widget test's fake clock.
  // Loading the actual assets also checks that both use the same image grid.
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const AerialPhotoPage(),
      ),
    );
    for (
      var attempt = 0;
      attempt < 500 && _viewerFinder.evaluate().isEmpty;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  });
  expect(_viewerFinder, findsOneWidget);
  // The initial full-image fit is applied after the viewer's first layout.
  await tester.pumpAndSettle();
}

TransformationController _controller(WidgetTester tester) =>
    tester.widget<InteractiveViewer>(_viewerFinder).transformationController!;

Future<void> _tap(WidgetTester tester, String key) async {
  final control = find.byKey(Key(key));
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pumpAndSettle();
}

void _expectSamePoint(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 0.001));
  expect(actual.dy, closeTo(expected.dy, 0.001));
}

void _expectBounded(WidgetTester tester) {
  final controller = _controller(tester);
  final viewport = tester.getSize(_viewerFinder);
  final scale = controller.value.getMaxScaleOnAxis();
  final topLeft = MatrixUtils.transformPoint(controller.value, Offset.zero);
  final bottomRight = MatrixUtils.transformPoint(
    controller.value,
    _imageSize.bottomRight(Offset.zero),
  );

  // A filled axis cannot expose space outside the image; an axis that does
  // not fill the viewport must retain equal white margins on both sides.
  for (final axis in [
    (topLeft.dx, bottomRight.dx, viewport.width, _imageSize.width),
    (topLeft.dy, bottomRight.dy, viewport.height, _imageSize.height),
  ]) {
    if (axis.$4 * scale >= axis.$3 - 0.001) {
      expect(axis.$1, lessThanOrEqualTo(0.001));
      expect(axis.$2, greaterThanOrEqualTo(axis.$3 - 0.001));
    } else {
      expect(axis.$1, closeTo(axis.$3 - axis.$2, 0.001));
    }
  }
}

void main() {
  testWidgets('zoom retains the viewed center and respects both scale limits', (
    tester,
  ) async {
    await _pumpPage(tester);
    final controller = _controller(tester);
    final viewportCenter = tester.getSize(_viewerFinder).center(Offset.zero);
    final initialScale = controller.value.getMaxScaleOnAxis();
    final initialCenter = controller.toScene(viewportCenter);
    _expectSamePoint(initialCenter, _imageSize.center(Offset.zero));

    await _tap(tester, 'aerial-zoom-in');
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(initialScale));
    _expectSamePoint(controller.toScene(viewportCenter), initialCenter);

    for (var i = 0; i < 12; i++) {
      await _tap(tester, 'aerial-zoom-in');
    }
    final viewer = tester.widget<InteractiveViewer>(_viewerFinder);
    expect(
      controller.value.getMaxScaleOnAxis(),
      closeTo(viewer.maxScale, 1e-6),
    );
    _expectSamePoint(controller.toScene(viewportCenter), initialCenter);
    _expectBounded(tester);

    for (var i = 0; i < 12; i++) {
      await _tap(tester, 'aerial-zoom-out');
    }
    expect(
      controller.value.getMaxScaleOnAxis(),
      closeTo(viewer.minScale, 1e-6),
    );
    _expectSamePoint(controller.toScene(viewportCenter), initialCenter);
    _expectBounded(tester);
  });

  testWidgets(
    'pan controls and dragging stay inside the map; reset restores fit',
    (tester) async {
      await _pumpPage(tester);
      final controller = _controller(tester);
      final initialTransform = controller.value.clone();
      await _tap(tester, 'aerial-zoom-in');
      await _tap(tester, 'aerial-zoom-in');

      for (final direction in ['left', 'right', 'up', 'down']) {
        final before = controller.toScene(
          tester.getSize(_viewerFinder).center(Offset.zero),
        );
        await _tap(tester, 'aerial-pan-$direction');
        final after = controller.toScene(
          tester.getSize(_viewerFinder).center(Offset.zero),
        );
        switch (direction) {
          case 'left':
            expect(after.dx, lessThan(before.dx));
          case 'right':
            expect(after.dx, greaterThan(before.dx));
          case 'up':
            expect(after.dy, lessThan(before.dy));
          case 'down':
            expect(after.dy, greaterThan(before.dy));
        }
        for (var i = 0; i < 10; i++) {
          await _tap(tester, 'aerial-pan-$direction');
        }
        _expectBounded(tester);
        final edgeTransform = controller.value.clone();
        await _tap(tester, 'aerial-pan-$direction');
        expect(controller.value.storage, orderedEquals(edgeTransform.storage));
      }

      await tester.ensureVisible(_viewerFinder);
      await tester.drag(_viewerFinder, const Offset(10000, 10000));
      await tester.pumpAndSettle();
      _expectBounded(tester);

      await _tap(tester, 'aerial-reset');
      for (var i = 0; i < 16; i++) {
        expect(
          controller.value.storage[i],
          closeTo(initialTransform.storage[i], 1e-6),
        );
      }
      _expectBounded(tester);
    },
  );

  testWidgets(
    'slider fades aligned images without changing the selected view',
    (tester) async {
      await _pumpPage(tester);
      final historicalLayer = find.byKey(const Key('aerial-historical-layer'));
      expect(tester.widget<Opacity>(historicalLayer).opacity, 0);
      await _tap(tester, 'aerial-historic-area');
      // Both separated historical photo areas must be visible, including the
      // Oud Haerlem fragment to the south of the old village center.
      final viewport = tester.getSize(_viewerFinder);
      for (final point in [const Offset(1323, 398), const Offset(1604, 804)]) {
        final visible = MatrixUtils.transformPoint(
          _controller(tester).value,
          point,
        );
        expect(visible.dx, inInclusiveRange(0, viewport.width));
        expect(visible.dy, inInclusiveRange(0, viewport.height));
      }
      await _tap(tester, 'aerial-pan-left');
      final controller = _controller(tester);
      final transform = controller.value.clone();
      final images = find.descendant(
        of: _viewerFinder,
        matching: find.byType(RawImage),
      );
      expect(images, findsNWidgets(2));

      final slider = find.byKey(const Key('aerial-slider'));
      await tester.ensureVisible(slider);
      final rect = tester.getRect(slider);
      for (final value in [1.0, 0.5, 0.0]) {
        await tester.tapAt(
          Offset(rect.left + 1 + (rect.width - 2) * value, rect.center.dy),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Opacity>(historicalLayer).opacity,
          closeTo(value, 0.01),
        );
        expect(controller.value.storage, orderedEquals(transform.storage));
        expect(tester.getRect(images.first), tester.getRect(images.last));
      }
    },
  );

  testWidgets('320 pixel layout with 200% text keeps every control reachable', (
    tester,
  ) async {
    await _pumpPage(tester, size: const Size(320, 800), textScale: 2);
    expect(tester.takeException(), isNull);

    for (final key in [
      'aerial-zoom-in',
      'aerial-pan-left',
      'aerial-pan-right',
      'aerial-pan-up',
      'aerial-pan-down',
      'aerial-zoom-out',
      'aerial-historic-area',
      'aerial-reset',
    ]) {
      final control = find.byKey(Key(key));
      await _tap(tester, key);
      expect(control.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      _expectBounded(tester);
    }
    final slider = find.byKey(const Key('aerial-slider'));
    await tester.ensureVisible(slider);
    await tester.tapAt(tester.getRect(slider).center);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('aerial-historical-layer')))
          .opacity,
      closeTo(0.5, 0.01),
    );
    expect(tester.takeException(), isNull);
  });
}
