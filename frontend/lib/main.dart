import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/google_login_dialog.dart';
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
import 'collection/search_controls.dart';
import 'config/app_config.dart';
import 'dossier/dossier.dart';
import 'dossier/dossier_dialogs.dart';
import 'dossier/dossier_list_page.dart';
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
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315B52)),
      useMaterial3: true,
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

  Future<void> _signIn() => startSignIn(
    context,
    _session,
    googleButtonBuilder:
        widget.googleButtonBuilder ?? google_button.renderGoogleButton,
  );

  void _openDossiers() {
    final dossierSource = widget.dossierSource;
    if (dossierSource == null) return;
    openAppPage(
      context,
      '/dossiers',
      () => DossierListPage(
        source: dossierSource,
        session: _session,
        googleButtonBuilder:
            widget.googleButtonBuilder ?? google_button.renderGoogleButton,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width <= 600;
    return Scaffold(
      backgroundColor: _homeBackground,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text(
          'Historisch Heemskerk',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          _SessionActions(
            session: _session,
            onSignIn: _signIn,
            onOpenDossiers: widget.dossierSource == null ? null : _openDossiers,
            onSignOut: _session.signOut,
            isNarrow: isNarrow,
          ),
        ],
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
            'Bijv. wat is er bekend over de Kerklaan? De digitale onderzoeker zoekt bronnen bij elkaar. Dit kan enkele minuten duren.',
            style: TextStyle(color: _homeGreen),
          ),
          const SizedBox(height: 18),
          if (widget.isNarrow) ...[
            _questionField(),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('ai-question-button'),
              onPressed: _open,
              child: const Text('Vraag stellen'),
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _questionField()),
                const SizedBox(width: 12),
                FilledButton(
                  key: const Key('ai-question-button'),
                  onPressed: _open,
                  child: const Text('Vraag stellen'),
                ),
              ],
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
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => _open(),
    decoration: const InputDecoration(
      labelText: 'Uw vraag',
      hintText: 'Bijv. wat is er bekend over de Kerklaan?',
    ),
  );
}

/// Zoekbalk direct op de startpagina, mét "Uitgebreid zoeken": toont meteen een
/// volledige resultatenlijst met dezelfde zoekinstellingen.
class _HomeSearchSection extends StatefulWidget {
  const _HomeSearchSection({required this.source, required this.isNarrow});

  final CollectionSearchSource source;
  final bool isNarrow;

  @override
  State<_HomeSearchSection> createState() => _HomeSearchSectionState();
}

class _HomeSearchSectionState extends State<_HomeSearchSection> {
  final _controller = TextEditingController();
  final _fieldControllers = SearchFieldControllers();
  bool _advancedOpen = false;
  bool _tipsOpen = false;
  CollectionOverview? _overview;
  String? _collection;

  @override
  void initState() {
    super.initState();
    widget.source
        .loadOverview()
        .then((overview) {
          if (mounted) setState(() => _overview = overview);
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _fieldControllers.dispose();
    super.dispose();
  }

  void _search() {
    final location = searchLocation(
      query: _controller.text.trim(),
      collection: _collection,
      fields: _fieldControllers.fieldQueries,
      year: _fieldControllers.yearValue,
      options: const CollectionSearchOptions(),
    );
    openAppPage(
      context,
      location,
      () => CollectionSearchPage(
        source: widget.source,
        initialQuery: _controller.text.trim(),
        initialCollection: _collection,
        initialFieldQueries: _fieldControllers.fieldQueries,
        initialYear: _fieldControllers.yearValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('collection-search-section'),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _collectionBorder),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      padding: EdgeInsets.all(widget.isNarrow ? 20 : 24),
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
          const SizedBox(height: 12),
          CollectionChips(
            overview: _overview,
            selected: _collection,
            onSelect: (value) => setState(() => _collection = value),
          ),
          const SizedBox(height: 16),
          if (widget.isNarrow) ...[
            _searchField(),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('collection-search-button'),
              onPressed: _search,
              child: const Text('Zoeken'),
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _searchField()),
                const SizedBox(width: 12),
                OutlinedButton(
                  key: const Key('collection-search-button'),
                  onPressed: _search,
                  child: const Text('Zoeken'),
                ),
              ],
            ),
          const SizedBox(height: 4),
          _DisclosureButton(
            label: 'Zoektips',
            expanded: _tipsOpen,
            onPressed: () => setState(() => _tipsOpen = !_tipsOpen),
          ),
          if (_tipsOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Los woorden voor een EN-zoekopdracht, of zet een zin tussen '
                '"aanhalingstekens" voor een exacte frase.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          _DisclosureButton(
            label: 'Uitgebreid zoeken',
            expanded: _advancedOpen,
            onPressed: () => setState(() => _advancedOpen = !_advancedOpen),
          ),
          if (_advancedOpen) ...[
            const SizedBox(height: 4),
            AdvancedSearchFields(
              controllers: _fieldControllers,
              onSubmit: _search,
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchField() => TextField(
    key: const Key('collection-search-field'),
    controller: _controller,
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => _search(),
    decoration: const InputDecoration(
      labelText: 'Zoekterm',
      hintText: 'Zoek in de collectie…',
    ),
  );
}

class _DisclosureButton extends StatelessWidget {
  const _DisclosureButton({
    required this.label,
    required this.expanded,
    required this.onPressed,
  });

  final String label;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      expanded: expanded,
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          label: Text(label),
        ),
      ),
    );
  }
}

enum _AccountMenuItem { signOut }

/// Acties rechtsboven: voor een ingelogde gebruiker staat "Mijn dossiers"
/// rechtstreeks naast het accountmenu. Zonder geconfigureerde login blijft de balk leeg.
class _SessionActions extends StatelessWidget {
  const _SessionActions({
    required this.session,
    required this.onSignIn,
    required this.onOpenDossiers,
    required this.onSignOut,
    required this.isNarrow,
  });

  final UserSessionController session;
  final VoidCallback onSignIn;
  final VoidCallback? onOpenDossiers;
  final VoidCallback onSignOut;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final identity = session.identity;
        if (identity != null) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onOpenDossiers != null) ...[
                if (isNarrow)
                  IconButton(
                    key: const Key('dossiers-action'),
                    onPressed: onOpenDossiers,
                    icon: const Icon(Icons.folder_outlined),
                    tooltip: 'Mijn dossiers',
                  )
                else
                  TextButton.icon(
                    key: const Key('dossiers-action'),
                    onPressed: onOpenDossiers,
                    icon: const Icon(Icons.folder_outlined),
                    label: const Text('Mijn dossiers'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: _homeGreen,
                    ),
                  ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: _collectionBorder,
                ),
              ],
              PopupMenuButton<_AccountMenuItem>(
                key: const Key('account-menu'),
                tooltip: 'Account',
                onSelected: (_) => onSignOut(),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _AccountMenuItem.signOut,
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Uitloggen'),
                    ),
                  ),
                ],
                child: SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: isNarrow
                        ? const SizedBox(
                            width: 32,
                            child: Icon(Icons.account_circle_outlined),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_circle_outlined),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 120,
                                ),
                                child: Text(
                                  identity.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          );
        }
        if (!session.configured && !session.signedIn) {
          return const SizedBox.shrink();
        }
        if (session.busy) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return TextButton.icon(
          onPressed: onSignIn,
          icon: const Icon(Icons.login),
          label: const Text('Inloggen'),
        );
      },
    );
  }
}
