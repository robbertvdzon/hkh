import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hkh_app/collection/collection_detail_page.dart';
import 'package:hkh_app/collection/collection_search.dart';
import 'package:hkh_app/navigation.dart';
// Tests inspect browser window options that the MethodChannel does not expose.
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const _location = '/objecten/archief/11767';
const _pdfUrl = 'https://hkh.vdzonsoftware.nl/api/media/document.pdf';
const _thumbnailUrl = 'https://hkh.vdzonsoftware.nl/api/media/first-page.jpg';

class _Source extends Fake implements CollectionSearchSource {
  final requests = <({String collection, String ident})>[];

  @override
  Future<CollectionItemDetail> loadDetail(
    String collection,
    String ident,
  ) async {
    requests.add((collection: collection, ident: ident));
    return CollectionItemDetail(
      collection: collection,
      ident: ident,
      title: 'Elk uur een nieuwe Jezus',
      description: 'Kerst in de Laurentiuskerk.',
      year: 2007,
      imageUrl: null,
      pdfUrl: _pdfUrl,
      thumbnailUrl: _thumbnailUrl,
      detailUrl: 'https://hkh.vdzonsoftware.nl/#$_location',
      fields: const {'Type publicatie': 'Krantenartikel'},
    );
  }
}

class _Launcher extends UrlLauncherPlatform {
  final calls = <({String url, LaunchOptions options})>[];

  @override
  Null get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls.add((url: url, options: options));
    return true;
  }
}

Future<GoRouter> _setup(
  WidgetTester tester,
  _Source source, {
  required Size size,
  required double textScale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final image = await tester.runAsync(
    () => createTestImage(width: 40, height: 60),
  );
  const provider = NetworkImage(_thumbnailUrl);
  PaintingBinding.instance.imageCache.putIfAbsent(
    provider,
    () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image!))),
  );
  addTearDown(() => provider.evict());
  final router = createAppRouter(
    searchSource: source,
    initialLocation: _location,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      'PDF detail deep link shows a first-page image and opens the PDF from ${mobile ? 'the button on a 320px phone at 200 percent' : 'the preview on desktop'}',
      (tester) async {
        final originalLauncher = UrlLauncherPlatform.instance;
        final launcher = _Launcher();
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() => UrlLauncherPlatform.instance = originalLauncher);
        final source = _Source();
        final router = await _setup(
          tester,
          source,
          size: mobile ? const Size(320, 800) : const Size(1200, 900),
          textScale: mobile ? 2 : 1,
        );

        expect(source.requests, [(collection: 'archief', ident: '11767')]);
        expect(find.byType(CollectionDetailPage), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.path, _location);
        expect(tester.takeException(), isNull);
        final control = find.byKey(
          Key(mobile ? 'source-pdf-open' : 'source-pdf-preview'),
        );
        final scrollable = find.descendant(
          of: find.byType(CollectionDetailPage),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(control, 150, scrollable: scrollable);
        await tester.pumpAndSettle();
        expect(control.hitTestable(), findsOneWidget);
        expect(find.text('PDF openen'), findsOneWidget);
        final thumbnail = find.byKey(const Key('source-pdf-thumbnail'));
        expect(
          (tester.widget<Image>(thumbnail).image as NetworkImage).url,
          _thumbnailUrl,
        );
        expect(
          tester
              .widget<RawImage>(
                find.descendant(of: thumbnail, matching: find.byType(RawImage)),
              )
              .image,
          isNotNull,
        );
        expect(find.byType(HtmlElementView), findsNothing);
        if (mobile) {
          final bounds = tester.getRect(thumbnail);
          expect(bounds.width, greaterThan(0));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(320));
        }
        expect(launcher.calls, isEmpty);
        expect(tester.takeException(), isNull);
        final position = tester.state<ScrollableState>(scrollable).position;
        final readingPosition = position.pixels;

        await tester.tap(control);
        await tester.pumpAndSettle();

        expect(launcher.calls, hasLength(1));
        expect(launcher.calls.single.url, _pdfUrl);
        expect(
          launcher.calls.single.options.mode,
          PreferredLaunchMode.externalApplication,
        );
        expect(launcher.calls.single.options.webOnlyWindowName, '_blank');
        expect(router.routeInformationProvider.value.uri.path, _location);
        expect(position.pixels, readingPosition);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
