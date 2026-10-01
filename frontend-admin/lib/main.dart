import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'auth/admin_session.dart';
import 'config/app_config.dart';
import 'google_signin_button_stub.dart'
    if (dart.library.html) 'google_signin_button_web.dart'
    as google_button;
import 'ai/admin_ai_model.dart';
import 'collection/admin_collection_scrape.dart';
import 'news/admin_latest_news.dart';

void main() {
  final sessionSource = AppConfig.previewMode
      ? PreviewAdminSessionSource(apiBaseUrl: AppConfig.apiBaseUrl)
      : AppConfig.googleClientId.isEmpty
      ? const DisabledAdminSessionSource()
      : AdminSessionService(
          apiBaseUrl: AppConfig.apiBaseUrl,
          googleClientId: AppConfig.googleClientId,
        );
  runApp(
    HkhAdminApp(
      sessionSource: sessionSource,
      newsSource: AdminLatestNewsClient(AppConfig.apiBaseUrl),
      scrapeSource: AdminScrapeClient(AppConfig.apiBaseUrl),
      aiModelSource: AdminAiModelClient(AppConfig.apiBaseUrl),
    ),
  );
}

class HkhAdminApp extends StatelessWidget {
  const HkhAdminApp({
    required this.sessionSource,
    required this.newsSource,
    required this.scrapeSource,
    this.aiModelSource,
    this.googleButtonBuilder,
    super.key,
  });

  final AdminSessionSource sessionSource;
  final AdminLatestNewsSource newsSource;
  final AdminScrapeSource scrapeSource;

  /// Modelkeuze van de digitale onderzoeker; zonder bron wordt het blok niet getoond.
  final AdminAiModelSource? aiModelSource;
  final Widget Function()? googleButtonBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HKH Beheer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF594A78)),
        useMaterial3: true,
      ),
      home: AdminGate(
        sessionSource: sessionSource,
        newsSource: newsSource,
        scrapeSource: scrapeSource,
        aiModelSource: aiModelSource,
        googleButtonBuilder:
            googleButtonBuilder ?? google_button.renderGoogleButton,
      ),
    );
  }
}

class AdminGate extends StatefulWidget {
  const AdminGate({
    required this.sessionSource,
    required this.newsSource,
    required this.scrapeSource,
    required this.googleButtonBuilder,
    this.aiModelSource,
    super.key,
  });

  final AdminSessionSource sessionSource;
  final AdminLatestNewsSource newsSource;
  final AdminScrapeSource scrapeSource;
  final AdminAiModelSource? aiModelSource;
  final Widget Function() googleButtonBuilder;

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  StreamSubscription<AdminIdentity>? _subscription;
  AdminIdentity? _identity;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _subscription = widget.sessionSource.identities.listen(
      _authenticated,
      onError: _failed,
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!widget.sessionSource.configured) {
      setState(() => _busy = false);
      return;
    }
    try {
      final identity = await widget.sessionSource.bootstrap();
      if (identity != null) _authenticated(identity);
      if (mounted) setState(() => _busy = false);
    } catch (error) {
      _failed(error);
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final identity = await widget.sessionSource.signIn();
      if (identity != null) _authenticated(identity);
      if (mounted) setState(() => _busy = false);
    } catch (error) {
      _failed(error);
    }
  }

  Future<void> _signOut() async {
    await widget.sessionSource.signOut();
    if (mounted) setState(() => _identity = null);
  }

  void _authenticated(AdminIdentity identity) {
    if (!mounted) return;
    setState(() {
      _identity = identity;
      _busy = false;
      _error = null;
    });
  }

  void _failed(Object error) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error is StateError && error.message.isNotEmpty
          ? error.message
          : 'Inloggen mislukt. Controleer je HKH-beheeraccount.';
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    widget.sessionSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final identity = _identity;
    if (identity != null) {
      return _AdminHome(
        identity: identity,
        newsSource: widget.newsSource,
        scrapeSource: widget.scrapeSource,
        aiModelSource: widget.aiModelSource,
        onSignOut: _signOut,
      );
    }
    return _LoginScreen(
      configured: widget.sessionSource.configured,
      error: _error,
      onSignIn: _signIn,
      googleButtonBuilder: widget.googleButtonBuilder,
    );
  }
}

class _LoginScreen extends StatelessWidget {
  const _LoginScreen({
    required this.configured,
    required this.error,
    required this.onSignIn,
    required this.googleButtonBuilder,
  });

  final bool configured;
  final String? error;
  final VoidCallback onSignIn;
  final Widget Function() googleButtonBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 60),
                const SizedBox(height: 16),
                Text(
                  'HKH Beheer',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  configured
                      ? 'Log in met een toegestaan Google-account.'
                      : 'Google-login is nog niet geconfigureerd.',
                  textAlign: TextAlign.center,
                ),
                if (configured) ...[
                  const SizedBox(height: 24),
                  if (kIsWeb)
                    SizedBox(height: 40, child: googleButtonBuilder())
                  else
                    FilledButton.icon(
                      onPressed: onSignIn,
                      icon: const Icon(Icons.login),
                      label: const Text('Inloggen met Google'),
                    ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminHome extends StatefulWidget {
  const _AdminHome({
    required this.identity,
    required this.newsSource,
    required this.scrapeSource,
    required this.onSignOut,
    this.aiModelSource,
  });

  final AdminIdentity identity;
  final AdminLatestNewsSource newsSource;
  final AdminScrapeSource scrapeSource;
  final AdminAiModelSource? aiModelSource;
  final VoidCallback onSignOut;

  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _saving = false;
  String? _success;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _success = null;
      _error = null;
    });
    try {
      await widget.newsSource.create(
        identity: widget.identity,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      _titleController.clear();
      _messageController.clear();
      setState(() => _success = 'Het nieuwsbericht is gepubliceerd.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Publiceren is mislukt. Probeer het opnieuw.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HKH Beheer'),
        actions: [
          IconButton(
            onPressed: widget.onSignOut,
            tooltip: 'Uitloggen',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    'Beheerder geverifieerd',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(widget.identity.email, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  _CollectionScrapeSection(
                    identity: widget.identity,
                    source: widget.scrapeSource,
                  ),
                  if (widget.aiModelSource case final aiModelSource?) ...[
                    const SizedBox(height: 32),
                    _AiModelSection(
                      identity: widget.identity,
                      source: aiModelSource,
                    ),
                  ],
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 20),
                  Text(
                    'Nieuw bericht',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Publiceer een bericht dat direct in de HKH-app verschijnt.',
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          maxLength: 160,
                          decoration: const InputDecoration(
                            labelText: 'Titel',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Vul een titel in.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _messageController,
                          minLines: 5,
                          maxLines: 12,
                          maxLength: 10000,
                          decoration: const InputDecoration(
                            labelText: 'Bericht',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Vul een bericht in.'
                              : null,
                        ),
                        if (_success != null) ...[
                          Text(
                            _success!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          onPressed: _saving ? null : _publish,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.publish),
                          label: const Text('Publiceren'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionScrapeSection extends StatefulWidget {
  const _CollectionScrapeSection({
    required this.identity,
    required this.source,
  });

  final AdminIdentity identity;
  final AdminScrapeSource source;

  @override
  State<_CollectionScrapeSection> createState() =>
      _CollectionScrapeSectionState();
}

class _CollectionScrapeSectionState extends State<_CollectionScrapeSection> {
  ScrapeStatus? _status;
  bool _loading = true;
  bool _force = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await widget.source.loadStatus(widget.identity);
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
        _error = null;
      });
      _schedulePolling(status);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Status kon niet worden geladen.';
      });
    }
  }

  void _schedulePolling(ScrapeStatus? status) {
    _poll?.cancel();
    if (status != null && status.running) {
      _poll = Timer(const Duration(seconds: 3), _refresh);
    }
  }

  Future<void> _start(ScrapeMode mode) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.source.start(
        identity: widget.identity,
        mode: mode,
        force: _force,
      );
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
      _schedulePolling(status);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is StateError ? error.message : 'Starten mislukt.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final running = status?.running ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_download_outlined),
                const SizedBox(width: 8),
                Text(
                  'Collectie ophalen (ZCBS)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Haalt alle metadata uit de ZCBS-beeldbanken op en zet die in de '
              'zoekdatabase. Beelden blijven op de HKH-webserver staan.',
            ),
            const SizedBox(height: 16),
            if (status != null) _StatusView(status: status),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _force,
              onChanged: running || _loading
                  ? null
                  : (value) => setState(() => _force = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Alles opnieuw ophalen (i.p.v. alleen nieuwe/onvolledige)',
              ),
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: running || _loading
                  ? null
                  : () => _start(ScrapeMode.fast),
              icon: running || _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bolt_outlined),
              label: const Text('Snel ophalen (overzicht, 30 tegelijk)'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Snel gebruikt alleen de lijstpagina\'s: titel, korte beschrijving en een '
              'paar velden - geen beeld/PDF-link.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: running || _loading
                  ? null
                  : () => _start(ScrapeMode.full),
              icon: running || _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                running
                    ? 'Bezig met ophalen (${status?.mode.label})…'
                    : 'Volledig ophalen (langzaam, alle gegevens)',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Volledig haalt elk record apart op (± 2 uur voor de hele collectie), '
              'vult zo ook het beeld/PDF en de overige velden aan en haalt direct de '
              'tekst uit de PDF van nieuwe records.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('scrape-text'),
              onPressed: running || _loading
                  ? null
                  : () => _start(ScrapeMode.text),
              icon: running || _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.text_snippet_outlined),
              label: const Text(
                'Documenttekst ophalen (ontbrekende en mislukte)',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Haalt voor records met een PDF (archief, artikelen) de tekstlaag uit die '
              'PDF en zet die in de zoekdatabase. Eenmalig nodig voor de bestaande '
              'collectie; eerder mislukte records worden opnieuw geprobeerd. Met "alles '
              'opnieuw" worden ook al opgehaalde PDF\'s op wijzigingen gecontroleerd.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kiest het model van de digitale onderzoeker uit de catalogus van de agent-runtime.
class _AiModelSection extends StatefulWidget {
  const _AiModelSection({required this.identity, required this.source});

  final AdminIdentity identity;
  final AdminAiModelSource source;

  @override
  State<_AiModelSection> createState() => _AiModelSectionState();
}

class _AiModelSectionState extends State<_AiModelSection> {
  AiModelState? _state;
  String? _selectedKey;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await widget.source.load(widget.identity);
      if (!mounted) return;
      setState(() {
        _state = state;
        _selectedKey = state.current.key;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is StateError
            ? error.message
            : 'Modelinstelling kon niet worden geladen.';
      });
    }
  }

  Future<void> _apply(
    Future<AiModelState> Function() action,
    String success,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      final state = await action();
      if (!mounted) return;
      setState(() {
        _state = state;
        _selectedKey = state.current.key;
        _success = success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is StateError ? error.message : 'Opslaan mislukt.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final options = state?.options ?? const <AiModelOption>[];
    final keys = options.map((o) => o.execution.key).toSet();
    final selectedKey = _selectedKey != null && keys.contains(_selectedKey)
        ? _selectedKey
        : null;
    final selectedOption = options
        .where((o) => o.execution.key == selectedKey)
        .firstOrNull;
    final changed = selectedKey != null && selectedKey != state?.current.key;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_outlined),
                const SizedBox(width: 8),
                Text(
                  'AI-onderzoeker: model',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Het model waarmee de digitale onderzoeker vragen beantwoordt. De keuze geldt '
              'direct voor nieuwe vragen; lopende onderzoeken maken hun huidige model af.',
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (state != null)
                Text(
                  'Nu actief: ${state.current.label}'
                  '${state.fromSetting ? '' : ' (uit de configuratie)'}'
                  '${state.updatedBy == null ? '' : ' · gekozen door ${state.updatedBy}'}',
                  key: const Key('ai-model-current'),
                ),
              if (state?.catalogError != null) ...[
                const SizedBox(height: 8),
                Text(
                  state!.catalogError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('ai-model-select'),
                initialValue: selectedKey,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final option in options)
                    DropdownMenuItem(
                      value: option.execution.key,
                      child: Text(
                        '${option.execution.label}'
                        '${option.available ? '' : ' · geen worker online'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving || options.isEmpty
                    ? null
                    : (value) => setState(() {
                        _selectedKey = value;
                        _success = null;
                      }),
              ),
              if (selectedOption != null && !selectedOption.available) ...[
                const SizedBox(height: 6),
                Text(
                  'Voor dit model is nu geen worker online; vragen blijven dan wachten.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('ai-model-save'),
                    onPressed: _saving || !changed || selectedOption == null
                        ? null
                        : () => _apply(
                            () => widget.source.select(
                              widget.identity,
                              selectedOption.execution,
                            ),
                            'Het model is gewijzigd.',
                          ),
                    icon: const Icon(Icons.check),
                    label: const Text('Dit model gebruiken'),
                  ),
                  OutlinedButton(
                    key: const Key('ai-model-reset'),
                    onPressed: _saving || !(state?.fromSetting ?? false)
                        ? null
                        : () => _apply(
                            () => widget.source.reset(widget.identity),
                            'Terug naar het model uit de configuratie.',
                          ),
                    child: const Text('Terug naar configuratie'),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Catalogus verversen'),
                  ),
                ],
              ),
              if (_success != null) ...[
                const SizedBox(height: 8),
                Text(_success!, key: const Key('ai-model-success')),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.status});

  final ScrapeStatus status;

  @override
  Widget build(BuildContext context) {
    final total = status.total;
    final done = status.processed + status.skipped + status.failed;
    final fraction = total > 0 ? (done / total).clamp(0.0, 1.0) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Laatste run: ${_label(status.status)} (${status.mode.label})'),
        if (status.running && status.currentCollection != null) ...[
          const SizedBox(height: 4),
          Text('Bezig met: ${status.currentCollection}'),
        ],
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: status.running ? fraction : (fraction ?? 0.0),
        ),
        const SizedBox(height: 8),
        Text(
          'Opgehaald: ${status.processed}  ·  Overgeslagen: ${status.skipped}'
          '  ·  Mislukt: ${status.failed}'
          '${total > 0 ? '  ·  Totaal: $total' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (status.mode == ScrapeMode.full &&
            (status.documents > 0 || status.documentsFailed > 0)) ...[
          const SizedBox(height: 4),
          Text(
            'Documentteksten: ${status.documents}'
            '  ·  Mislukt: ${status.documentsFailed}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (status.message != null) ...[
          const SizedBox(height: 4),
          Text(status.message!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  String _label(String status) => switch (status) {
    'RUNNING' => 'bezig',
    'COMPLETED' => 'voltooid',
    'FAILED' => 'mislukt',
    _ => status.toLowerCase(),
  };
}
