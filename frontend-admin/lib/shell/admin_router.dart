import 'package:flutter/material.dart';

/// De pagina's van het beheerscherm. Elke pagina heeft een eigen adres, zodat
/// terug, vooruit en een bladwijzer in de browser werken.
class AdminPaths {
  const AdminPaths._();

  static const start = '/';
  static const collection = '/archief';
  static const aiSettings = '/ai-instellingen';
  static const aiCapacity = '/ai-capaciteit';
  static const aiCompare = '/ai-vergelijken';
  static const requestLog = '/logboek';
  static const workflowLog = '/workflow-logboek';

  static const all = [
    start,
    collection,
    aiSettings,
    aiCompare,
    aiCapacity,
    requestLog,
    workflowLog,
  ];

  static String capacityResult(String campaignId, String runId) =>
      '$aiCapacity/$campaignId/$runId';
  static String capacityExecution(String campaignId, String runId) =>
      '${capacityResult(campaignId, runId)}/uitvoering';
  static List<String>? executionIds(String path) => path.endsWith('/uitvoering')
      ? resultIds(path.substring(0, path.length - '/uitvoering'.length))
      : null;
  static List<String>? resultIds(String path) {
    final segments = Uri.parse(path).pathSegments;
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return segments.length == 3 &&
            segments[0] == 'ai-capaciteit' &&
            uuid.hasMatch(segments[1]) &&
            uuid.hasMatch(segments[2])
        ? segments.sublist(1)
        : null;
  }

  static String workflowSession(String id) => '$workflowLog/$id';

  /// De sessie-id uit `/workflow-logboek/{uuid}`, of null als het pad dat niet is.
  static String? workflowSessionId(String path) {
    final segments = Uri.parse(path).pathSegments;
    return segments.length == 2 &&
            segments[0] == 'workflow-logboek' &&
            RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(segments[1])
        ? segments[1].toLowerCase()
        : null;
  }

  /// Onbekende adressen vallen terug op de startpagina.
  static String normalise(String path) {
    final clean = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    return all.contains(clean) ||
            workflowSessionId(clean) != null ||
            resultIds(clean) != null ||
            executionIds(clean) != null
        ? clean
        : start;
  }

  static String title(String path) => workflowSessionId(path) != null
      ? 'Doorloop van de workflow-app'
      : executionIds(path) != null
      ? 'Uitvoeringsdetails'
      : resultIds(path) != null
      ? 'Testresultaat'
      : switch (path) {
          collection => 'Archief',
          aiSettings => 'AI-instellingen',
          aiCapacity => 'Capaciteitstests',
          aiCompare => 'AI vergelijken',
          requestLog => 'Logboek van verzoeken',
          workflowLog => 'Workflow-logboek',
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
