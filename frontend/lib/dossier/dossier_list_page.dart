import 'package:flutter/material.dart';
import '../navigation.dart';

import '../auth/google_login_dialog.dart';
import '../auth/user_session.dart';
import '../theme/app_style.dart';
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
    await openAppPage(
      context,
      '/dossiers/${Uri.encodeComponent(dossierId)}',
      () => DossierPage(
        source: widget.source,
        dossierId: dossierId,
        session: widget.session,
      ),
    );
    if (mounted && _signedIn) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: appDossierTheme(context),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: appBackground,
          appBar: AppBar(
            title: const Text(
              'Mijn dossiers',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
                child: _signedIn
                    ? _buildList(context)
                    : _buildSignedOut(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    final session = widget.session;
    final horizontal = isNarrowLayout(context) ? 16.0 : 24.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 24),
      children: [
        const Icon(Icons.folder_outlined, size: 56, color: appGreen),
        const SizedBox(height: 16),
        Text(
          'Dossiers zijn persoonlijk',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: appGreen,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          'In een dossier bewaar je vragen aan het archief, een feitenlijst en artikelen over één onderwerp, '
          'en deel je dat met anderen. Log in met je Google-account om je dossiers te zien.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: appSectionGap),
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
    final horizontal = isNarrowLayout(context) ? 16.0 : 24.0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 96),
        children: [
          if (_loading && dossiers == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: appSectionGap),
              child: Text(
                _error!,
                style: const TextStyle(color: appErrorForeground),
              ),
            ),
          if (dossiers != null && dossiers.isEmpty) const _EmptyState(),
          for (final dossier in dossiers ?? const <DossierSummary>[]) ...[
            _DossierCard(dossier: dossier, onOpen: () => _open(dossier.id)),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('dossier-empty-state'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.folder_outlined, size: 32, color: appGreen),
        const SizedBox(height: 16),
        Text(
          'Nog geen dossiers',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: appGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Een dossier is een onderzoek met een titel en een doel, bijvoorbeeld '
          '"Artikel over de Kerklaan en haar bewoners voor het verenigingsblad". '
          'Daarin stel je vragen aan het archief, houdt de AI een feitenlijst bij en schrijf je artikelen, '
          'alleen of samen met anderen. Begin met "Nieuw dossier".',
          style: TextStyle(color: appMutedText),
        ),
      ],
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
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      color: appGreen,
      fontWeight: FontWeight.w700,
    );
    final metaStyle = theme.textTheme.bodySmall?.copyWith(color: appMutedText);
    return AppCard(
      key: Key('dossier-card-${dossier.id}'),
      onTap: onOpen,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Bij weinig ruimte (smal scherm of grote letters) komt de rolchip op
          // een eigen regel, zodat de titel niet wordt weggedrukt.
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final stacked = constraints.maxWidth < 260 * scale;
          final title = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.folder_outlined, color: appGreen),
              const SizedBox(width: 12),
              Expanded(child: Text(dossier.title, style: titleStyle)),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: RoleChip(role: dossier.role),
                ),
                const SizedBox(height: 8),
                title,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    Flexible(child: RoleChip(role: dossier.role)),
                  ],
                ),
              if (dossier.goal.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  dossier.goal,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: appMutedText),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  Text(
                    '${dossier.questionCount} ${dossier.questionCount == 1 ? 'vraag' : 'vragen'}',
                    style: metaStyle,
                  ),
                  Text(
                    '${dossier.articleCount} ${dossier.articleCount == 1 ? 'artikel' : 'artikelen'}',
                    style: metaStyle,
                  ),
                  if (dossier.memberCount > 1)
                    Text('${dossier.memberCount} leden', style: metaStyle),
                  Text(
                    'Gewijzigd ${formatDateTime(dossier.updatedAt)}',
                    style: metaStyle,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compacte chip met de rol van de gebruiker in een dossier.
class RoleChip extends StatelessWidget {
  const RoleChip({required this.role, super.key});

  final DossierRole role;

  static Color background(DossierRole role) => switch (role) {
    DossierRole.owner => appRoleOwnerBackground,
    DossierRole.editor => appRoleEditorBackground,
    DossierRole.researcher => appRoleResearcherBackground,
    DossierRole.reader => appRoleReaderBackground,
  };

  static Color foreground(DossierRole role) => switch (role) {
    DossierRole.owner => appRoleOwnerForeground,
    DossierRole.editor => appRoleEditorForeground,
    DossierRole.researcher => appRoleResearcherForeground,
    DossierRole.reader => appRoleReaderForeground,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('role-chip-${role.wireName}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background(role),
        borderRadius: BorderRadius.circular(appControlRadius),
      ),
      child: Text(
        role.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground(role),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
