import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ai_search/ai_search_page.dart';
import '../auth/user_session.dart';
import '../theme/app_style.dart';
import 'dossier.dart';
import 'dossier_articles_tab.dart';
import 'dossier_dialogs.dart';
import 'dossier_fact_sheet_tab.dart';
import 'dossier_format.dart';
import 'dossier_members_dialog.dart';
import 'dossier_question_source.dart';

enum _DossierMenuItem { edit, members, delete, leave }

/// Eén dossier met de tabbladen Vragen, Feitenlijst en Artikelen.
class DossierPage extends StatefulWidget {
  const DossierPage({
    required this.source,
    required this.dossierId,
    this.session,
    this.initialTab = 0,
    this.initialQuestionId,
    super.key,
  });

  final DossierSource source;
  final String dossierId;

  /// Voor "Verlaten": het eigen e-mailadres komt uit de sessie.
  final UserSessionController? session;
  final int initialTab;
  final String? initialQuestionId;

  @override
  State<DossierPage> createState() => _DossierPageState();
}

class _DossierPageState extends State<DossierPage>
    with SingleTickerProviderStateMixin {
  static const _pollInterval = Duration(seconds: 5);

  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab,
  );
  late final DossierQuestionSource _questionSource = DossierQuestionSource(
    source: widget.source,
    dossierId: widget.dossierId,
  );
  DossierDetail? _detail;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _tabs.addListener(_syncTab);
  }

  @override
  void didUpdateWidget(covariant DossierPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != _tabs.index) _tabs.index = widget.initialTab;
  }

  void _syncTab() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final uri = router.routeInformationProvider.value.uri;
    if (!uri.path.startsWith('/dossiers/')) return;
    final params = {...uri.queryParameters, 'tab': '${_tabs.index}'};
    if (uri.queryParameters['tab'] != '${_tabs.index}') {
      router.replace(uri.replace(queryParameters: params).toString());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.source.loadDossier(widget.dossierId);
      if (!mounted) return;
      _apply(detail);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
      _pollTimer?.cancel();
    }
  }

  /// Zet een nieuwe dossierstand en start of stopt het pollen op basis van lopende AI-jobs.
  void _apply(DossierDetail detail) {
    setState(() {
      _detail = detail;
      _error = null;
    });
    final busy =
        detail.factSheet.isRunning ||
        detail.articles.any((article) => article.proposalState == 'RUNNING');
    if (busy && _pollTimer == null) {
      _pollTimer = Timer.periodic(_pollInterval, (_) => _load());
    } else if (!busy) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _run(Future<DossierDetail> Function() action) async {
    try {
      _apply(await action());
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _edit() async {
    final detail = _detail!;
    final input = await showDossierDialog(
      context,
      title: detail.title,
      goal: detail.goal,
    );
    if (input == null) return;
    await _run(
      () => widget.source.updateDossier(
        detail.id,
        title: input.title,
        goal: input.goal,
      ),
    );
  }

  Future<void> _members() async {
    final updated = await showMembersDialog(
      context,
      source: widget.source,
      detail: _detail!,
    );
    if (updated != null && mounted) _apply(updated);
  }

  Future<void> _delete() async {
    final detail = _detail!;
    final ok = await confirm(
      context,
      title: 'Dossier verwijderen?',
      message:
          'Het dossier "${detail.title}" met alle vragen, de feitenlijst en de artikelen wordt definitief verwijderd, ook voor de andere leden.',
    );
    if (!ok || !mounted) return;
    try {
      await widget.source.deleteDossier(detail.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _leave() async {
    final email = widget.session?.identity?.email;
    if (email == null) return;
    final ok = await confirm(
      context,
      title: 'Dossier verlaten?',
      message:
          'Je verliest de toegang tot dit dossier. De eigenaar kan je later opnieuw uitnodigen.',
      confirmLabel: 'Verlaten',
    );
    if (!ok || !mounted) return;
    try {
      await widget.source.removeMember(widget.dossierId, email);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  void _onMenu(_DossierMenuItem item) => switch (item) {
    _DossierMenuItem.edit => _edit(),
    _DossierMenuItem.members => _members(),
    _DossierMenuItem.delete => _delete(),
    _DossierMenuItem.leave => _leave(),
  };

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final role = detail?.role;
    final canLeave =
        role != null && !role.canManage && widget.session?.identity != null;
    return Theme(
      data: appDossierTheme(context),
      child: Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          title: Text(
            detail?.title ?? 'Dossier',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (detail != null)
              PopupMenuButton<_DossierMenuItem>(
                tooltip: 'Dossiermenu',
                onSelected: _onMenu,
                itemBuilder: (_) => [
                  if (role!.canEdit)
                    const PopupMenuItem(
                      value: _DossierMenuItem.edit,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Titel en doel bewerken'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: _DossierMenuItem.members,
                    child: ListTile(
                      leading: Icon(Icons.people_outline),
                      title: Text('Delen en leden'),
                    ),
                  ),
                  if (role.canManage)
                    const PopupMenuItem(
                      value: _DossierMenuItem.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Dossier verwijderen'),
                      ),
                    ),
                  if (canLeave)
                    const PopupMenuItem(
                      value: _DossierMenuItem.leave,
                      child: ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Dossier verlaten'),
                      ),
                    ),
                ],
              ),
          ],
          bottom: detail == null
              ? null
              : TabBar(
                  controller: _tabs,
                  tabs: const [
                    Tab(
                      text: 'Vragen',
                      icon: Icon(Icons.question_answer_outlined),
                    ),
                    Tab(
                      text: 'Feitenlijst',
                      icon: Icon(Icons.fact_check_outlined),
                    ),
                    Tab(text: 'Artikelen', icon: Icon(Icons.article_outlined)),
                  ],
                ),
        ),
        body: detail == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: appErrorForeground),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _load,
                              child: const Text('Opnieuw proberen'),
                            ),
                          ],
                        ),
                      ),
              )
            : TabBarView(
                controller: _tabs,
                children: [
                  AiSearchPage(
                    initialSessionId: widget.initialQuestionId,
                    source: _questionSource,
                    embedded: true,
                    overviewTitle: 'Vragen in dit dossier',
                    emptyMessage:
                        'In dit dossier zijn nog geen vragen gesteld. Stel hieronder je eerste vraag aan het archief.',
                    introduction: _DossierIntro(detail: detail),
                    canAsk: detail.role.canResearch,
                    readOnlyMessage:
                        'Je bent lezer van dit dossier: je kunt meelezen, maar geen vragen stellen.',
                  ),
                  FactSheetTab(
                    factSheet: detail.factSheet,
                    canResearch: detail.role.canResearch,
                    onSave: (markdown) => _run(
                      () => widget.source.updateFactSheet(detail.id, markdown),
                    ),
                    onRefresh: () =>
                        _run(() => widget.source.refreshFactSheet(detail.id)),
                  ),
                  ArticlesTab(
                    source: widget.source,
                    detail: detail,
                    onChanged: _load,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Kop boven de vragenlijst: doel van het dossier.
class _DossierIntro extends StatelessWidget {
  const _DossierIntro({required this.detail});
  final DossierDetail detail;

  @override
  Widget build(BuildContext context) {
    final goal = detail.goal.trim();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (goal.isNotEmpty) ...[
            Text(
              'Doel',
              style: theme.textTheme.labelMedium?.copyWith(
                color: appMutedText,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              goal,
              style: theme.textTheme.titleMedium?.copyWith(
                color: appGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Elke vraag krijgt het doel, de feitenlijst en de eerdere antwoorden van dit dossier mee. '
            'Na een geslaagd antwoord werkt de AI de feitenlijst bij.',
            style: theme.textTheme.bodySmall?.copyWith(color: appMutedText),
          ),
        ],
      ),
    );
  }
}
