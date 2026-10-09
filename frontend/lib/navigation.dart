import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_style.dart';
import 'aerial/aerial_photo_page.dart';
import 'ai_search/ai_search.dart';
import 'ai_search/ai_search_page.dart';
import 'ai_search/answer_sharing.dart';
import 'ai_search/shared_answer_page.dart';
import 'auth/user_session.dart';
import 'collection/collection_search.dart';
import 'collection/collection_search_page.dart';
import 'content/site_structure.dart';
import 'site/activity_page.dart';
import 'site/agenda_page.dart';
import 'site/association_pages.dart';
import 'site/collections_page.dart';
import 'site/discover_pages.dart';
import 'site/education_pages.dart';
import 'site/home_page.dart';
import 'site/membership_page.dart';
import 'site/memory_pages.dart';
import 'site/news_pages.dart';
import 'site/site_widgets.dart';

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
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => fallback(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

GoRoute instantRoute({
  required String path,
  GoRouterWidgetBuilder? builder,
  GoRouterRedirect? redirect,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  redirect: redirect,
  routes: routes,
  pageBuilder: builder == null
      ? null
      : (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: builder(context, state),
        ),
);

/// Pagina voor een onbekende route.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) => SitePage(
    title: 'Pagina niet gevonden',
    children: [
      const PageHeading(
        title: 'Pagina niet gevonden',
        intro: 'Deze pagina bestaat niet of is verplaatst.',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: () => navigateTo(context, '/'),
          child: const Text('Naar de homepage'),
        ),
      ),
    ],
  );
}

GoRouter createAppRouter({
  required CollectionSearchSource searchSource,
  AiSearchSource? aiSearchSource,
  AiAnswerPdfSource? pdfSource,
  UserSessionController? session,
  Widget Function()? googleButtonBuilder,
  String? initialLocation,
  DateTime? now,
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

  Widget questionsPage(GoRouterState state) {
    Widget page() => AiSearchPage(
      // Wis geladen privé-antwoorden en de polling zodra de gebruiker wisselt.
      key: ValueKey('questions:${session?.identity?.email ?? "anonymous"}'),
      source: aiSearchSource!,
      pdfSource: pdfSource,
      initialQuestion: switch (state.extra) {
        final AiQuestionDraft draft => draft.question,
        final String question => question,
        _ => null,
      },
      initialDepth: state.extra is AiQuestionDraft
          ? (state.extra as AiQuestionDraft).depth
          : AiResearchDepth.fast,
      initialSessionId: state.uri.queryParameters['id'],
      emptyMessage: session?.signedIn ?? false
          ? 'Je hebt nog geen AI-zoekopdrachten in je account.'
          : 'Je hebt in deze browser nog geen AI-zoekopdrachten.',
      historyDescription: session?.signedIn ?? false
          ? 'Je vragen worden bewaard in je account. Log op een andere pc in met hetzelfde Google-account om ze daar te bekijken.'
          : 'Je vragen worden voor deze browser bewaard. Log in met Google om ze aan je account te koppelen en op andere pc’s te bekijken.',
    );
    return session == null
        ? page()
        : ListenableBuilder(listenable: session, builder: (_, __) => page());
  }

  Widget notFound() => const NotFoundPage();

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      instantRoute(
        path: '/',
        builder: (_, __) =>
            HomePage(questionsEnabled: aiSearchSource != null, now: now),
        routes: [
          // ---- Agenda ----
          instantRoute(
            path: 'agenda',
            builder: (_, __) => AgendaPage(now: now),
            routes: [
              instantRoute(
                path: 'eerder',
                builder: (_, __) => AgendaPage(past: true, now: now),
              ),
              instantRoute(
                path: ':slug',
                builder: (_, state) {
                  final activity = activityBySlug(state.pathParameters['slug']!);
                  return activity == null
                      ? notFound()
                      : ActivityPage(activity: activity, now: now);
                },
              ),
            ],
          ),
          // ---- Nieuws ----
          instantRoute(
            path: 'nieuws',
            builder: (_, __) => const NewsPage(),
            routes: [
              instantRoute(
                path: 'nieuwsbrieven',
                builder: (_, __) => const NewslettersPage(),
              ),
              instantRoute(
                path: 'heemskring',
                builder: (_, __) => const HeemskringPage(),
              ),
              instantRoute(
                path: ':slug',
                builder: (_, state) {
                  final post = newsBySlug(state.pathParameters['slug']!);
                  return post == null ? notFound() : NewsArticlePage(post: post);
                },
              ),
            ],
          ),
          // ---- Ontdek Heemskerk ----
          instantRoute(
            path: 'ontdek',
            builder: (_, __) => const DiscoverPage(),
            routes: [
              instantRoute(
                path: ':slug',
                builder: (_, state) {
                  final slug = state.pathParameters['slug']!;
                  final category = storyCategoryBySlug(slug);
                  if (category != null) return DiscoverPage(category: category);
                  final page = pageBySlug(slug);
                  return page == null ? notFound() : StoryPage(page: page);
                },
              ),
            ],
          ),
          instantRoute(
            path: 'luchtfoto',
            builder: (_, __) => const AerialPhotoPage(),
          ),
          // ---- Geheugen van Heemskerk ----
          instantRoute(
            path: 'geheugen',
            builder: (_, __) => const MemoryOverviewPage(),
            routes: [
              instantRoute(
                path: 'themas',
                builder: (_, __) => const MemoryGroupsPage(byNeighbourhood: false),
              ),
              instantRoute(
                path: 'buurten',
                builder: (_, __) => const MemoryGroupsPage(byNeighbourhood: true),
              ),
              instantRoute(
                path: 'over',
                builder: (_, __) => const MemoryAboutPage(),
              ),
              instantRoute(
                path: 'thema/:name',
                builder: (_, state) => MemoryOverviewPage(
                  key: ValueKey('thema:${state.pathParameters['name']}'),
                  theme: state.pathParameters['name'],
                ),
              ),
              instantRoute(
                path: 'buurt/:name',
                builder: (_, state) => MemoryOverviewPage(
                  key: ValueKey('buurt:${state.pathParameters['name']}'),
                  neighbourhood: state.pathParameters['name'],
                ),
              ),
              instantRoute(
                path: 'verhaal/:slug',
                builder: (_, state) {
                  final story = memoryStoryBySlug(state.pathParameters['slug']!);
                  return story == null
                      ? notFound()
                      : MemoryStoryPage(
                          key: ValueKey(story.slug),
                          story: story,
                        );
                },
              ),
            ],
          ),
          // ---- Collecties ----
          instantRoute(
            path: 'collecties',
            builder: (_, __) =>
                CollectionsPage(questionsEnabled: aiSearchSource != null),
          ),
          instantRoute(
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
              instantRoute(
                path: 'objecten/:collection/:ident',
                builder: (_, state) => objectPage(state),
              ),
            ],
          ),
          instantRoute(
            path: 'objecten/:collection/:ident',
            builder: (_, state) => objectPage(state),
          ),
          if (aiSearchSource != null && shareSourceFor(aiSearchSource) != null)
            instantRoute(
              path: 'gedeeld/:token',
              builder: (_, state) => SharedAnswerPage(
                source: shareSourceFor(aiSearchSource)!,
                token: state.pathParameters['token']!,
              ),
            ),
          if (aiSearchSource != null)
            instantRoute(
              path: 'vragen',
              builder: (_, state) => questionsPage(state),
            ),
          // ---- Educatie ----
          instantRoute(
            path: 'educatie',
            builder: (_, __) => const EducationPage(),
            routes: [
              instantRoute(
                path: ':slug',
                builder: (_, state) {
                  final item = educationBySlug(state.pathParameters['slug']!);
                  return item == null
                      ? notFound()
                      : EducationItemPage(item: item);
                },
              ),
            ],
          ),
          // ---- Vereniging ----
          instantRoute(
            path: 'vereniging',
            builder: (_, __) => const AssociationPage(),
            routes: [
              instantRoute(
                path: ':slug',
                builder: (_, state) =>
                    associationSectionPage(state.pathParameters['slug']!) ??
                    notFound(),
              ),
            ],
          ),
          instantRoute(
            path: 'lid-worden',
            builder: (_, __) => const MembershipPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, _) => Theme(
      data: appPageTheme(context),
      child: const NotFoundPage(),
    ),
  );
}
