import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'auth/admin_session.dart';
import 'config/app_config.dart';
import 'google_signin_button_stub.dart'
    if (dart.library.html) 'google_signin_button_web.dart'
    as google_button;
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
    ),
  );
}

class HkhAdminApp extends StatelessWidget {
  const HkhAdminApp({
    required this.sessionSource,
    required this.newsSource,
    required this.scrapeSource,
    this.googleButtonBuilder,
    super.key,
  });

  final AdminSessionSource sessionSource;
  final AdminLatestNewsSource newsSource;
  final AdminScrapeSource scrapeSource;
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
    super.key,
  });

  final AdminSessionSource sessionSource;
  final AdminLatestNewsSource newsSource;
  final AdminScrapeSource scrapeSource;
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
      _error = 'Inloggen mislukt. Controleer je HKH-beheeraccount.';
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
  });

  final AdminIdentity identity;
  final AdminLatestNewsSource newsSource;
  final AdminScrapeSource scrapeSource;
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
  const _CollectionScrapeSection({required this.identity, required this.source});

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

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.source.start(
        identity: widget.identity,
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
              title: const Text('Alles opnieuw ophalen (i.p.v. alleen nieuwe)'),
            ),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: running || _loading ? null : _start,
              icon: running || _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(running ? 'Bezig met ophalen…' : 'Start scrape'),
            ),
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
        Text('Laatste run: ${_label(status.status)}'),
        if (status.running && status.currentCollection != null) ...[
          const SizedBox(height: 4),
          Text('Bezig met: ${status.currentCollection}'),
        ],
        const SizedBox(height: 8),
        LinearProgressIndicator(value: status.running ? fraction : (fraction == null ? 0 : fraction)),
        const SizedBox(height: 8),
        Text(
          'Opgehaald: ${status.processed}  ·  Overgeslagen: ${status.skipped}'
          '  ·  Mislukt: ${status.failed}'
          '${total > 0 ? '  ·  Totaal: $total' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (status.message != null) ...[
          const SizedBox(height: 4),
          Text(
            status.message!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
