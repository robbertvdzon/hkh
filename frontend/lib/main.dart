import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

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
import 'collection/img_embed/img_embed.dart';
import 'collection/search_controls.dart';
import 'config/app_config.dart';
import 'dossier/dossier.dart';
import 'dossier/dossier_dialogs.dart';
import 'dossier/dossier_list_page.dart';
import 'self_update_prompt.dart';

const _homeBackground = Color(0xFFFBF6EE);
const _aiCardBackground = Color(0xFFDCE9DA);
const _homeGreen = Color(0xFF1F3B2E);
const _collectionBorder = Color(0xFFD9CFBB);
const _controlBorder = Color(0xFF647566);
const _errorBackground = Color(0xFFFBE9E7);
const _errorForeground = Color(0xFF9F201B);
const _cardRadius = 16.0;
const _controlRadius = 10.0;

void main() {
  final UserSessionController session = AppConfig.googleClientId.isEmpty
      ? DisabledUserSession()
      : GoogleUserSession(
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
      dossierSource: backend,
      session: session,
    ),
  );
}

class HkhApp extends StatelessWidget {
  const HkhApp({
    required this.searchSource,
    this.aiSearchSource,
    this.dossierSource,
    this.session,
    this.googleButtonBuilder,
    super.key,
  });

  final CollectionSearchSource searchSource;
  final AiSearchSource? aiSearchSource;

  /// Zonder dossierbron ontbreekt de losse actie "Mijn dossiers".
  final DossierSource? dossierSource;

  /// Optionele login; zonder controller draait de app anoniem (zoals in tests).
  final UserSessionController? session;
  final Widget Function()? googleButtonBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Historisch Heemskerk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF315B52),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: HomePage(
        searchSource: searchSource,
        aiSearchSource: aiSearchSource,
        dossierSource: dossierSource,
        session: session,
        googleButtonBuilder:
            googleButtonBuilder ?? google_button.renderGoogleButton,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    required this.searchSource,
    this.aiSearchSource,
    this.dossierSource,
    this.session,
    this.googleButtonBuilder,
    super.key,
  });

  final CollectionSearchSource searchSource;
  final AiSearchSource? aiSearchSource;
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DossierListPage(
          source: dossierSource,
          session: _session,
          googleButtonBuilder:
              widget.googleButtonBuilder ?? google_button.renderGoogleButton,
        ),
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

ThemeData _homeTheme(BuildContext context) {
  final base = Theme.of(context);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(_controlRadius),
    borderSide: const BorderSide(color: _controlBorder),
  );
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _homeGreen,
      onPrimary: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_controlRadius),
        borderSide: const BorderSide(color: _homeGreen, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: _homeGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: _homeGreen,
        side: const BorderSide(color: _homeGreen),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _homeGreen,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
        ),
      ),
    ),
  );
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.searchSource,
    required this.aiSearchSource,
    required this.dossierSource,
    required this.session,
    required this.isNarrow,
  });

  final CollectionSearchSource searchSource;
  final AiSearchSource? aiSearchSource;
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
    required this.dossierSource,
    required this.session,
    required this.isNarrow,
  });
  final AiSearchSource source;
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiSearchPage(
          source: widget.source,
          initialQuestion: question.isEmpty ? null : question,
          onAdopt: _onAdopt,
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiSearchPage(source: widget.source, onAdopt: _onAdopt),
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
              onPressed: _openHistory,
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
/// paar treffers, met een link door naar het volledige zoekscherm.
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
  List<CollectionItemSummary>? _results;
  int _total = 0;
  bool _loading = false;
  bool _searched = false;
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    _fieldControllers.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    final fieldQueries = _fieldControllers.fieldQueries;
    final year = _fieldControllers.yearValue;
    if (query.isEmpty && fieldQueries.isEmpty && year == null) return;
    setState(() {
      _loading = true;
      _searched = true;
      _failed = false;
    });
    try {
      final result = await widget.source.search(
        query: query,
        fieldQueries: fieldQueries,
        year: year,
        size: 3,
      );
      if (!mounted) return;
      setState(() {
        _results = result.items;
        _total = result.total;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
        _failed = true;
      });
    }
  }

  void _openFullSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CollectionSearchPage(
          source: widget.source,
          initialQuery: _controller.text.trim().isEmpty
              ? null
              : _controller.text.trim(),
          initialFieldQueries: _fieldControllers.fieldQueries,
          initialYear: _fieldControllers.yearValue,
        ),
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
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ] else if (_failed) ...[
            const SizedBox(height: 12),
            const _CollectionSearchError(),
          ] else if (_searched) ...[
            const SizedBox(height: 12),
            if ((_results ?? const []).isEmpty)
              const Center(child: Text('Geen resultaten gevonden.'))
            else
              Column(
                children: [
                  for (final item in _results!) ...[
                    _HomeResultTile(item: item, source: widget.source),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _openFullSearch,
              child: Text(
                _searched && _total > 0
                    ? 'Alle $_total resultaten'
                    : 'Doorzoek de collectie',
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ),
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

class _CollectionSearchError extends StatelessWidget {
  const _CollectionSearchError();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: _errorBackground,
          border: Border.all(color: const Color(0xFFE7AAA6)),
          borderRadius: BorderRadius.circular(_controlRadius),
        ),
        padding: const EdgeInsets.all(12),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: _errorForeground),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Zoeken in de collectie is niet gelukt. Controleer de verbinding en probeer het opnieuw.',
                style: TextStyle(color: _errorForeground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeResultTile extends StatelessWidget {
  const _HomeResultTile({required this.item, required this.source});

  final CollectionItemSummary item;
  final CollectionSearchSource source;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: item.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: buildNetworkImage(item.imageUrl!, fit: BoxFit.cover),
                )
              : Icon(
                  item.hasPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.description_outlined,
                ),
        ),
        title: Text(
          item.title.isEmpty ? '(zonder titel)' : item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CollectionDetailPage(
              source: source,
              collection: item.collection,
              ident: item.ident,
              title: item.title,
            ),
          ),
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
        if (!session.configured) return const SizedBox.shrink();
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
