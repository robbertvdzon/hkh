import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ai_search/ai_search.dart';
import 'ai_search/ai_search_page.dart';
import 'auth/user_session.dart';
import 'collection/collection_search.dart';
import 'collection/collection_search_page.dart';
import 'dossier/dossier.dart';
import 'dossier/dossier_dialogs.dart';
import 'dossier/dossier_list_page.dart';
import 'dossier/dossier_page.dart';
import 'dossier/article_page.dart';
import 'dossier/article_history_page.dart';
import 'main.dart';

String searchLocation({
  String query = '',
  String? collection,
  Map<String, String> fields = const {},
  int? year,
  int page = 0,
  CollectionSearchOptions? options,
}) => Uri(
  path: '/zoeken',
  queryParameters: {
    if (query.isNotEmpty) 'q': query,
    if (collection != null) 'collection': collection,
    for (final entry in fields.entries) 'field.${entry.key}': entry.value,
    if (year != null) 'year': '$year',
    if (page > 0) 'page': '$page',
    ...?options?.toParameters(),
  },
).toString();

Future<T?> openAppPage<T>(
  BuildContext context,
  String location,
  Widget Function() fallback,
) {
  final router = GoRouter.maybeOf(context);
  if (router != null) return router.push<T>(location);
  return Navigator.of(
    context,
  ).push<T>(MaterialPageRoute(builder: (_) => fallback()));
}

GoRouter createAppRouter({
  required CollectionSearchSource searchSource,
  AiSearchSource? aiSearchSource,
  AiAnswerPdfSource? pdfSource,
  DossierSource? dossierSource,
  UserSessionController? session,
  Widget Function()? googleButtonBuilder,
  String? initialLocation,
}) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  Widget objectPage(GoRouterState state) => CollectionDetailPage(
    key: ValueKey('object:${state.pathParameters}'),
    source: searchSource,
    collection: state.pathParameters['collection']!,
    ident: state.pathParameters['ident']!,
    title: '',
    resultContext: state.extra is CollectionResultContext
        ? state.extra as CollectionResultContext
        : null,
    searchUri: state.uri.path.startsWith('/zoeken/') ? state.uri : null,
  );
  Widget accountPage(Widget child) {
    if (session == null) return child;
    return ListenableBuilder(
      listenable: session,
      builder: (_, __) => session.signedIn
          ? child
          : DossierListPage(
              source: dossierSource!,
              session: session,
              googleButtonBuilder: googleButtonBuilder,
            ),
    );
  }

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => HomePage(
          searchSource: searchSource,
          aiSearchSource: aiSearchSource,
          dossierSource: dossierSource,
          session: session,
          googleButtonBuilder: googleButtonBuilder,
        ),
        routes: [
          GoRoute(
            path: 'zoeken',
            builder: (_, state) {
              final q = state.uri.queryParameters;
              return CollectionSearchPage(
                key: const ValueKey('collection-search'),
                source: searchSource,
                initialQuery: q['q'] ?? '',
                initialOptions: CollectionSearchOptions.fromParameters(
                  state.uri.queryParametersAll,
                ),
                initialCollection: q['collection'],
                initialFieldQueries: {
                  for (final entry in q.entries)
                    if (entry.key.startsWith('field.'))
                      entry.key.substring(6): entry.value,
                },
                initialYear: int.tryParse(q['year'] ?? ''),
                initialPage: (int.tryParse(q['page'] ?? '') ?? 0).clamp(
                  0,
                  100000,
                ),
              );
            },
            routes: [
              GoRoute(
                path: 'objecten/:collection/:ident',
                builder: (_, state) => objectPage(state),
              ),
            ],
          ),
          GoRoute(
            path: 'objecten/:collection/:ident',
            builder: (_, state) => objectPage(state),
          ),
          GoRoute(
            path: 'collecties',
            redirect: (_, state) =>
                state.uri.replace(path: '/zoeken').toString(),
          ),
          if (aiSearchSource != null)
            GoRoute(
              path: 'vragen',
              builder: (_, state) => AiSearchPage(
                source: aiSearchSource,
                pdfSource: pdfSource,
                initialQuestion: state.extra is String
                    ? state.extra as String
                    : null,
                initialSessionId: state.uri.queryParameters['id'],
                onAdopt: dossierSource != null && (session?.signedIn ?? false)
                    ? (context, id) =>
                          showAdoptToDossierDialog(context, dossierSource, id)
                    : null,
              ),
            ),
          if (dossierSource != null) ...[
            GoRoute(
              path: 'dossiers',
              builder: (_, __) => DossierListPage(
                source: dossierSource,
                session: session,
                googleButtonBuilder: googleButtonBuilder,
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => accountPage(
                    DossierPage(
                      key: ValueKey(state.pathParameters['id']),
                      source: dossierSource,
                      dossierId: state.pathParameters['id']!,
                      session: session,
                      initialQuestionId: state.uri.queryParameters['vraag'],
                      initialTab:
                          (int.tryParse(
                                    state.uri.queryParameters['tab'] ?? '',
                                  ) ??
                                  0)
                              .clamp(0, 2),
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'artikelen/:id',
              builder: (_, state) => accountPage(
                ArticlePage(
                  key: ValueKey(state.pathParameters['id']),
                  source: dossierSource,
                  articleId: state.pathParameters['id']!,
                ),
              ),
              routes: [
                GoRoute(
                  path: 'geschiedenis',
                  builder: (_, state) => accountPage(
                    _ArticleHistoryRoute(
                      source: dossierSource,
                      id: state.pathParameters['id']!,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ],
    errorBuilder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Pagina niet gevonden')),
      body: Center(
        child: TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Naar het homescherm'),
        ),
      ),
    ),
  );
}

class _ArticleHistoryRoute extends StatefulWidget {
  const _ArticleHistoryRoute({required this.source, required this.id});
  final DossierSource source;
  final String id;
  @override
  State<_ArticleHistoryRoute> createState() => _ArticleHistoryRouteState();
}

class _ArticleHistoryRouteState extends State<_ArticleHistoryRoute> {
  late final _article = widget.source.loadArticle(widget.id);
  @override
  Widget build(BuildContext context) => FutureBuilder<ArticleDetail>(
    future: _article,
    builder: (_, snapshot) {
      if (snapshot.hasData) {
        return ArticleHistoryPage(
          source: widget.source,
          article: snapshot.requireData,
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Artikelgeschiedenis')),
        body: Center(
          child: snapshot.hasError
              ? const Text('Het artikel kon niet worden geladen.')
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}
