import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/account_action.dart';
import 'auth/google_signin_button_stub.dart'
    if (dart.library.html) 'auth/google_signin_button_web.dart'
    as google_button;
import 'auth/user_session.dart';
import 'backend/backend_client.dart';
import 'ai_search/ai_search.dart';
import 'ai_search/ai_search_page.dart';
import 'collection/collection_search.dart';
import 'collection/collection_search_page.dart';
import 'navigation.dart';
import 'config/app_config.dart';
import 'dossier/dossier.dart';
import 'dossier/dossier_dialogs.dart';
import 'self_update_prompt.dart';
import 'theme/app_style.dart';

// De homepage en de dossierschermen delen dezelfde vormgeving; de waarden
// staan in theme/app_style.dart.
const _homeBackground = appBackground;
const _aiCardBackground = appAccentBackground;
const _homeGreen = appGreen;
const _collectionBorder = appCardBorder;
const _cardRadius = appCardRadius;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final UserSessionController session = GoogleUserSession(
    apiBaseUrl: AppConfig.apiBaseUrl,
    googleClientId: AppConfig.googleClientId,
  );
  final backend = BackendClient(
    AppConfig.apiBaseUrl,
    tokenProvider: () => session.token,
    // Een 401 op een dossierroute betekent een verlopen of ingetrokken sessie.
    onUnauthorized: () => unawaited(session.signOut()),
  );
  // Niet blokkerend: de app start anoniem en toont de sessie zodra die hersteld is.
  unawaited(session.bootstrap());
  runApp(
    HkhApp(
      searchSource: backend,
      aiSearchSource: backend,
      pdfSource: backend,
      dossierSource: backend,
      session: session,
    ),
  );
}

class HkhApp extends StatefulWidget {
  const HkhApp({
    required this.searchSource,
    this.aiSearchSource,
    this.pdfSource,
    this.dossierSource,
    this.session,
    this.googleButtonBuilder,
    super.key,
  });

  final CollectionSearchSource searchSource;
  final AiSearchSource? aiSearchSource;

  /// Zonder pdf-bron ontbreekt de exportactie op het AI-antwoordscherm.
  final AiAnswerPdfSource? pdfSource;

  /// Zonder dossierbron ontbreekt de losse actie "Mijn dossiers".
  final DossierSource? dossierSource;

  /// Optionele login; zonder controller draait de app anoniem (zoals in tests).
  final UserSessionController? session;
  final Widget Function()? googleButtonBuilder;

  @override
  State<HkhApp> createState() => _HkhAppState();
}

class _HkhAppState extends State<HkhApp> {
  late final _router = createAppRouter(
    searchSource: widget.searchSource,
    aiSearchSource: widget.aiSearchSource,
    pdfSource: widget.pdfSource,
    dossierSource: widget.dossierSource,
    session: widget.session,
    googleButtonBuilder:
        widget.googleButtonBuilder ?? google_button.renderGoogleButton,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Historisch Heemskerk',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: appGreen,
      ).copyWith(surface: appBackground),
      useMaterial3: true,
      scaffoldBackgroundColor: appBackground,
      appBarTheme: appHeaderTheme,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const InstantPageTransitionsBuilder(),
        },
      ),
    ),
    builder: (context, child) => ListenableBuilder(
      listenable: _router.routeInformationProvider,
      builder: (context, _) => AppNavigationScope(
        onOpenHome: () => _router.go('/'),
        onOpenSearch: () => _router.go('/zoeken'),
        onOpenQuestions: widget.aiSearchSource == null
            ? null
            : () => _router.go('/vragen'),
        onOpenDossiers: widget.dossierSource == null
            ? null
            : () => _router.go('/dossiers'),
        location: _router.routeInformationProvider.value.uri.path,
        accountBuilder: (context) => AccountAction(
          session: widget.session ?? DisabledUserSession(),
          googleButtonBuilder: widget.googleButtonBuilder,
        ),
        child: child!,
      ),
    ),
    routerConfig: _router,
  );
}

class HomePage extends StatefulWidget {
  const HomePage({
    required this.searchSource,
    this.aiSearchSource,
    this.pdfSource,
    this.dossierSource,
    this.session,
    this.googleButtonBuilder,
    super.key,
  });

  final CollectionSearchSource searchSource;
  final AiSearchSource? aiSearchSource;
  final AiAnswerPdfSource? pdfSource;
  final DossierSource? dossierSource;
  final UserSessionController? session;
  final Widget Function()? googleButtonBuilder;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final UserSessionController _session =
      widget.session ?? DisabledUserSession();
  String? _shownError;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybePromptSelfUpdate(context);
      });
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final error = _session.error;
    if (!mounted || error == null || error == _shownError) {
      if (error == null) _shownError = null;
      return;
    }
    _shownError = error;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width <= 600;
    return Scaffold(
      backgroundColor: _homeBackground,
      appBar: HkhAppBar(
        context: context,
        title: const Text('Historisch Heemskerk'),
        showPageTitle: false,
        accountAction: AccountAction(
          session: _session,
          googleButtonBuilder: widget.googleButtonBuilder,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Theme(
              data: _homeTheme(context),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 16 : 24,
                  vertical: 24,
                ),
                child: _HomeContent(
                  searchSource: widget.searchSource,
                  aiSearchSource: widget.aiSearchSource,
                  pdfSource: widget.pdfSource,
                  dossierSource: widget.dossierSource,
                  session: _session,
                  isNarrow: isNarrow,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData _homeTheme(BuildContext context) => appSurfaceTheme(context);

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.searchSource,
    required this.aiSearchSource,
    required this.pdfSource,
    required this.dossierSource,
    required this.session,
    required this.isNarrow,
  });

  final CollectionSearchSource searchSource;
  final AiSearchSource? aiSearchSource;
  final AiAnswerPdfSource? pdfSource;
  final DossierSource? dossierSource;
  final UserSessionController session;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text(
          'Ontdek historisch Heemskerk',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _homeGreen,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Stel een vraag over plekken, personen of gebeurtenissen uit de geschiedenis van Heemskerk.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _homeGreen),
        ),
        SizedBox(height: isNarrow ? 32 : 40),
        if (aiSearchSource != null) ...[
          _AiHomeCard(
            source: aiSearchSource!,
            pdfSource: pdfSource,
            dossierSource: dossierSource,
            session: session,
            isNarrow: isNarrow,
          ),
          SizedBox(height: isNarrow ? 32 : 40),
        ],
        _HomeSearchSection(source: searchSource, isNarrow: isNarrow),
      ],
    );
  }
}

class _AiHomeCard extends StatefulWidget {
  const _AiHomeCard({
    required this.source,
    required this.pdfSource,
    required this.dossierSource,
    required this.session,
    required this.isNarrow,
  });
  final AiSearchSource source;
  final AiAnswerPdfSource? pdfSource;
  final DossierSource? dossierSource;
  final UserSessionController session;
  final bool isNarrow;

  @override
  State<_AiHomeCard> createState() => _AiHomeCardState();
}

class _AiHomeCardState extends State<_AiHomeCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// "In dossier zetten" is er alleen voor ingelogde gebruikers met een dossierbron.
  AdoptSearchHandler? get _onAdopt {
    final dossierSource = widget.dossierSource;
    if (dossierSource == null || !widget.session.signedIn) return null;
    return (context, sessionId) =>
        showAdoptToDossierDialog(context, dossierSource, sessionId);
  }

  void _open() {
    final question = _controller.text.trim();
    if (GoRouter.maybeOf(context) case final router?) {
      router.go('/vragen', extra: question.isEmpty ? null : question);
    } else {
      _openHistory(question: question.isEmpty ? null : question);
    }
  }

  void _openHistory({String? question}) {
    openAppPage(
      context,
      '/vragen',
      () => AiSearchPage(
        source: widget.source,
        pdfSource: widget.pdfSource,
        initialQuestion: question,
        onAdopt: _onAdopt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('ai-question-card'),
    margin: EdgeInsets.zero,
    elevation: 0,
    color: _aiCardBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_cardRadius),
    ),
    child: Padding(
      padding: EdgeInsets.all(widget.isNarrow ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Wat wilt u weten?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: _homeGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stel gerust een uitgebreide onderzoeksvraag over families, relaties tussen mensen en plekken, of veranderingen door de tijd. De digitale onderzoeker zoekt de bronnen erbij; dit kan enkele minuten duren.',
            style: TextStyle(color: _homeGreen),
          ),
          const SizedBox(height: 18),
          _questionField(),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('ai-question-button'),
            onPressed: _open,
            child: const Text('Vraag stellen'),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openHistory(),
              child: const Text(
                'Eerdere vragen',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _questionField() => TextField(
    key: const Key('ai-question-field'),
    controller: _controller,
    keyboardType: TextInputType.multiline,
    textInputAction: TextInputAction.newline,
    minLines: 5,
    maxLines: 10,
    decoration: const InputDecoration(
      labelText: 'Uw vraag',
      floatingLabelBehavior: FloatingLabelBehavior.always,
      alignLabelWithHint: true,
      hintText:
          'Bijvoorbeeld: Onderzoek de geschiedenis van de familie Jansen in Heemskerk. Welke relaties vind je met andere families, de Kerklaan en lokale verenigingen? Beschrijf hoe die verbanden door de tijd veranderden en vermeld bij je bevindingen de bronnen.',
    ),
  );
}

class _HomeSearchSection extends StatelessWidget {
  const _HomeSearchSection({required this.source, required this.isNarrow});
  final CollectionSearchSource source;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('collection-search-section'),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _collectionBorder),
      borderRadius: BorderRadius.circular(_cardRadius),
    ),
    padding: EdgeInsets.all(isNarrow ? 20 : 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Zelf zoeken in de collectie',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _homeGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ontdek foto’s, documenten en verhalen uit de geschiedenis van Heemskerk.',
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('collection-search-button'),
          icon: const Icon(Icons.search),
          label: const Text('Zoeken in de collectie'),
          onPressed: () => openAppPage(
            context,
            searchLocation(options: const CollectionSearchOptions()),
            () => CollectionSearchPage(source: source),
          ),
        ),
      ],
    ),
  );
}
