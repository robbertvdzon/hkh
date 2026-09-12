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

  /// Zonder dossierbron ontbreekt "Mijn dossiers" in het accountmenu.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historisch Heemskerk'),
        actions: [
          _SessionAction(
            session: _session,
            onSignIn: _signIn,
            onOpenDossiers: widget.dossierSource == null ? null : _openDossiers,
            onSignOut: _session.signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _HomeContent(
                searchSource: widget.searchSource,
                aiSearchSource: widget.aiSearchSource,
                dossierSource: widget.dossierSource,
                session: _session,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.searchSource,
    required this.aiSearchSource,
    required this.dossierSource,
    required this.session,
  });

  final CollectionSearchSource searchSource;
  final AiSearchSource? aiSearchSource;
  final DossierSource? dossierSource;
  final UserSessionController session;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Icon(
          Icons.account_balance,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        const Text(
          'Ontdek de geschiedenis van Heemskerk vanuit een vraag, plek, persoon of gebeurtenis.\n'
          'Verken betrouwbare historische bronnen en hun verbindingen met de wereld daarbuiten.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (aiSearchSource != null) ...[
          _AiHomeCard(
            source: aiSearchSource!,
            dossierSource: dossierSource,
            session: session,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'of zoek zelf',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
        ],
        _HomeSearchSection(source: searchSource),
      ],
    );
  }
}

class _AiHomeCard extends StatefulWidget {
  const _AiHomeCard({
    required this.source,
    required this.dossierSource,
    required this.session,
  });
  final AiSearchSource source;
  final DossierSource? dossierSource;
  final UserSessionController session;

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
    color: Theme.of(
      context,
    ).colorScheme.secondaryContainer.withValues(alpha: 0.55),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                'Vraag het archief',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Start een AI-zoekopdracht met een vrije vraag. De digitale onderzoeker zoekt zelf de relevante bronnen, verhalen en afbeeldingen bij elkaar. Dit kan enkele minuten duren.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _open(),
            decoration: InputDecoration(
              hintText: 'Bijv. wat is er bekend over de Kerklaan?',
              prefixIcon: const Icon(Icons.question_answer_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: _open,
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'Vraag stellen',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openHistory,
              icon: const Icon(Icons.history),
              label: const Text('Mijn AI-zoekopdrachten'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Zoekbalk direct op de startpagina, mét "Uitgebreid zoeken": toont meteen een
/// paar treffers, met een link door naar het volledige zoekscherm.
class _HomeSearchSection extends StatefulWidget {
  const _HomeSearchSection({required this.source});

  final CollectionSearchSource source;

  @override
  State<_HomeSearchSection> createState() => _HomeSearchSectionState();
}

class _HomeSearchSectionState extends State<_HomeSearchSection> {
  final _controller = TextEditingController();
  final _fieldControllers = SearchFieldControllers();
  bool _advancedOpen = false;
  List<CollectionItemSummary>? _results;
  int _total = 0;
  bool _loading = false;
  bool _searched = false;

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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  hintText: 'Zoek in de collectie…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _search, child: const Text('Zoeken')),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Los woorden voor een EN-zoekopdracht, of zet een zin tussen '
          '"aanhalingstekens" voor een exacte frase.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => setState(() => _advancedOpen = !_advancedOpen),
          icon: Icon(_advancedOpen ? Icons.expand_less : Icons.expand_more),
          label: const Text('Uitgebreid zoeken'),
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
        ] else if (_searched) ...[
          const SizedBox(height: 12),
          if ((_results ?? const []).isEmpty)
            const Text('Geen resultaten gevonden.')
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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openFullSearch,
            icon: const Icon(Icons.manage_search),
            label: Text(
              _searched && _total > 0
                  ? 'Alle $_total resultaten'
                  : 'Doorzoek de collectie',
            ),
          ),
        ),
      ],
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

enum _AccountMenuItem { dossiers, signOut }

/// Knop rechtsboven: "Inloggen" als dat kan, een accountmenu als iemand is ingelogd, en
/// niets als Google-login niet is geconfigureerd.
class _SessionAction extends StatelessWidget {
  const _SessionAction({
    required this.session,
    required this.onSignIn,
    required this.onOpenDossiers,
    required this.onSignOut,
  });

  final UserSessionController session;
  final VoidCallback onSignIn;
  final VoidCallback? onOpenDossiers;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final identity = session.identity;
        if (identity != null) {
          return PopupMenuButton<_AccountMenuItem>(
            tooltip: 'Account',
            onSelected: (item) => switch (item) {
              _AccountMenuItem.dossiers => onOpenDossiers?.call(),
              _AccountMenuItem.signOut => onSignOut(),
            },
            itemBuilder: (_) => [
              if (onOpenDossiers != null)
                const PopupMenuItem(
                  value: _AccountMenuItem.dossiers,
                  child: ListTile(
                    leading: Icon(Icons.folder_outlined),
                    title: Text('Mijn dossiers'),
                  ),
                ),
              const PopupMenuItem(
                value: _AccountMenuItem.signOut,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Uitloggen'),
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle_outlined),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      identity.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
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
