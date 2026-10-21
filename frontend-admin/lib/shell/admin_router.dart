import 'package:flutter/material.dart';

/// De pagina's van het beheerscherm. Elke pagina heeft een eigen adres, zodat
/// terug, vooruit en een bladwijzer in de browser werken.
class AdminPaths {
  const AdminPaths._();

  static const start = '/';
  static const collection = '/archief';
  static const aiSettings = '/ai-instellingen';
  static const aiCompare = '/ai-vergelijken';
  static const requestLog = '/logboek';

  static const all = [start, collection, aiSettings, aiCompare, requestLog];

  /// Onbekende adressen vallen terug op de startpagina.
  static String normalise(String path) {
    final clean = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    return all.contains(clean) ? clean : start;
  }

  static String title(String path) => switch (path) {
    collection => 'Archief',
    aiSettings => 'AI-instellingen',
    aiCompare => 'AI vergelijken',
    requestLog => 'Logboek van verzoeken',
    _ => 'Overzicht',
  };
}

class AdminRouteParser extends RouteInformationParser<String> {
  const AdminRouteParser();

  @override
  Future<String> parseRouteInformation(
    RouteInformation routeInformation,
  ) async => AdminPaths.normalise(routeInformation.uri.path);

  @override
  RouteInformation? restoreRouteInformation(String configuration) =>
      RouteInformation(uri: Uri.parse(configuration));
}

typedef AdminPageBuilder =
    Widget Function(
      BuildContext context,
      String path,
      void Function(String path) go,
    );

/// Eén pagina in de navigator die van inhoud wisselt: de inlogstatus blijft
/// daardoor behouden bij het wisselen van onderdeel.
class AdminRouterDelegate extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  AdminRouterDelegate(this._builder);

  final AdminPageBuilder _builder;
  String _path = AdminPaths.start;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  String get currentConfiguration => _path;

  void go(String path) {
    final next = AdminPaths.normalise(path);
    if (next == _path) return;
    _path = next;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(String configuration) async {
    _path = AdminPaths.normalise(configuration);
  }

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: [
      MaterialPage<void>(
        key: const ValueKey('admin'),
        child: _builder(context, _path, go),
      ),
    ],
    onDidRemovePage: (_) {},
  );
}
