import 'package:flutter/material.dart';

import '../auth/google_login_dialog.dart';
import '../auth/user_session.dart';
import 'dossier.dart';
import 'dossier_dialogs.dart';
import 'dossier_format.dart';
import 'dossier_page.dart';

/// Overzicht van eigen en gedeelde dossiers.
class DossierListPage extends StatefulWidget {
  const DossierListPage({
    required this.source,
    this.session,
    this.googleButtonBuilder,
    super.key,
  });

  final DossierSource source;

  /// Optioneel: zonder sessie wordt de lijst gewoon geladen (bijv. in tests).
  final UserSessionController? session;
  final Widget Function()? googleButtonBuilder;

  @override
  State<DossierListPage> createState() => _DossierListPageState();
}

class _DossierListPageState extends State<DossierListPage> {
  List<DossierSummary>? _dossiers;
  bool _loading = false;
  String? _error;

  bool get _signedIn => widget.session?.signedIn ?? true;

  @override
  void initState() {
    super.initState();
    widget.session?.addListener(_onSessionChanged);
    if (_signedIn) _load();
  }

  @override
  void dispose() {
    widget.session?.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    if (_signedIn && _dossiers == null && !_loading) {
      _load();
    } else if (!_signedIn) {
      setState(() {
        _dossiers = null;
        _error = null;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dossiers = await widget.source.listDossiers();
      if (!mounted) return;
      setState(() {
        _dossiers = dossiers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorText(error);
      });
    }
  }

  Future<void> _create() async {
    final input = await showDossierDialog(context);
    if (input == null || !mounted) return;
    try {
      final dossier = await widget.source.createDossier(
        title: input.title,
        goal: input.goal,
      );
      if (!mounted) return;
      await _open(dossier.id);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _open(String dossierId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DossierPage(
          source: widget.source,
          dossierId: dossierId,
          session: widget.session,
        ),
      ),
    );
    if (mounted && _signedIn) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn dossiers'),
        actions: [
          if (_signedIn)
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Vernieuwen',
            ),
        ],
      ),
      floatingActionButton: _signedIn
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Nieuw dossier'),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _signedIn ? _buildList(context) : _buildSignedOut(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    final session = widget.session;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.folder_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Dossiers zijn persoonlijk',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'In een dossier bewaar je vragen aan het archief, een feitenlijst en artikelen over één onderwerp, '
          'en deel je dat met anderen. Log in met je Google-account om je dossiers te zien.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (session != null && session.configured)
          Center(
            child: FilledButton.icon(
              onPressed: () => startSignIn(
                context,
                session,
                googleButtonBuilder: widget.googleButtonBuilder,
              ),
              icon: const Icon(Icons.login),
              label: const Text('Inloggen'),
            ),
          ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final dossiers = _dossiers;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_loading && dossiers == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (dossiers != null && dossiers.isEmpty) const _EmptyState(),
          for (final dossier in dossiers ?? const <DossierSummary>[]) ...[
            _DossierCard(dossier: dossier, onOpen: () => _open(dossier.id)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nog geen dossiers',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Een dossier is een onderzoek met een titel en een doel, bijvoorbeeld '
            '"Artikel over de Kerklaan en haar bewoners voor het verenigingsblad". '
            'Daarin stel je vragen aan het archief, houdt de AI een feitenlijst bij en schrijf je artikelen, '
            'alleen of samen met anderen. Begin met "Nieuw dossier".',
          ),
        ],
      ),
    ),
  );
}

class _DossierCard extends StatelessWidget {
  const _DossierCard({required this.dossier, required this.onOpen});

  final DossierSummary dossier;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dossier.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RoleChip(role: dossier.role),
                ],
              ),
              if (dossier.goal.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  dossier.goal,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  Text(
                    '${dossier.questionCount} ${dossier.questionCount == 1 ? 'vraag' : 'vragen'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '${dossier.articleCount} ${dossier.articleCount == 1 ? 'artikel' : 'artikelen'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (dossier.memberCount > 1)
                    Text(
                      '${dossier.memberCount} leden',
                      style: theme.textTheme.bodySmall,
                    ),
                  Text(
                    'Gewijzigd ${formatDateTime(dossier.updatedAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compacte chip met de rol van de gebruiker in een dossier.
class RoleChip extends StatelessWidget {
  const RoleChip({required this.role, super.key});

  final DossierRole role;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(role.label),
      visualDensity: VisualDensity.compact,
      backgroundColor: switch (role) {
        DossierRole.owner => colorScheme.primaryContainer,
        DossierRole.editor => colorScheme.secondaryContainer,
        DossierRole.researcher => colorScheme.tertiaryContainer,
        DossierRole.reader => colorScheme.surfaceContainerHighest,
      },
    );
  }
}
