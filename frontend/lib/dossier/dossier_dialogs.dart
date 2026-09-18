import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'dossier.dart';
import 'dossier_format.dart';

/// Titel en doel zoals ingevoerd in de dossierdialoog.
class DossierInput {
  const DossierInput({required this.title, required this.goal});
  final String title;
  final String goal;
}

/// Dialoog voor een nieuw dossier of voor het bewerken van titel en doel.
Future<DossierInput?> showDossierDialog(
  BuildContext context, {
  String title = '',
  String goal = '',
}) {
  return showDialog<DossierInput>(
    context: context,
    builder: (_) => _DossierDialog(initialTitle: title, initialGoal: goal),
  );
}

class _DossierDialog extends StatefulWidget {
  const _DossierDialog({required this.initialTitle, required this.initialGoal});

  final String initialTitle;
  final String initialGoal;

  @override
  State<_DossierDialog> createState() => _DossierDialogState();
}

class _DossierDialogState extends State<_DossierDialog> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _goal = TextEditingController(text: widget.initialGoal);

  @override
  void dispose() {
    _title.dispose();
    _goal.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, DossierInput(title: title, goal: _goal.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initialTitle.isEmpty;
    return AppDialog(
      title: isNew ? 'Nieuw dossier' : 'Titel en doel bewerken',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('dossier-title-field'),
            controller: _title,
            autofocus: true,
            maxLength: 200,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Titel',
              hintText: 'Bijv. De Kerklaan en haar bewoners',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('dossier-goal-field'),
            controller: _goal,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Doel',
              hintText:
                  'Wat wil je met dit onderzoek bereiken? Bijv. een artikel voor het verenigingsblad.',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          key: const Key('dossier-submit-button'),
          onPressed: _submit,
          child: Text(isNew ? 'Aanmaken' : 'Opslaan'),
        ),
      ],
    );
  }
}

/// Laat de gebruiker een dossier kiezen waarin een anonieme zoekopdracht wordt gezet.
/// Geeft de titel van het dossier terug als de adoptie is gelukt, anders null.
Future<String?> showAdoptToDossierDialog(
  BuildContext context,
  DossierSource source,
  String sessionId,
) async {
  final chosen = await showDialog<DossierSummary>(
    context: context,
    builder: (_) => _AdoptDialog(source: source),
  );
  if (chosen == null) return null;
  await source.adoptSearch(chosen.id, sessionId);
  return chosen.title;
}

class _AdoptDialog extends StatefulWidget {
  const _AdoptDialog({required this.source});
  final DossierSource source;

  @override
  State<_AdoptDialog> createState() => _AdoptDialogState();
}

class _AdoptDialogState extends State<_AdoptDialog> {
  List<DossierSummary>? _dossiers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dossiers = await widget.source.listDossiers();
      if (!mounted) return;
      setState(
        () => _dossiers = dossiers
            .where((dossier) => dossier.role.canResearch)
            .toList(growable: false),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'In dossier zetten',
      maxWidth: 440,
      content: _buildContent(context),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final dossiers = _dossiers;
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: appErrorForeground));
    }
    if (dossiers == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (dossiers.isEmpty) {
      return const Text(
        'Je hebt nog geen dossier waarin je vragen mag stellen. Maak eerst een dossier aan bij Mijn dossiers.',
        style: TextStyle(color: appMutedText),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Kies een dossier. Een kopie van de huidige vragen en antwoorden wordt zichtbaar voor alle dossierleden. Het origineel blijft bij Mijn zoekopdrachten staan. Latere vervolgvragen worden niet automatisch overgenomen.',
          style: TextStyle(color: appMutedText),
        ),
        const SizedBox(height: appSectionGap),
        for (final dossier in dossiers)
          _AdoptOption(
            dossier: dossier,
            onTap: () => Navigator.pop(context, dossier),
          ),
      ],
    );
  }
}

class _AdoptOption extends StatelessWidget {
  const _AdoptOption({required this.dossier, required this.onTap});

  final DossierSummary dossier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: Key('adopt-option-${dossier.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(appControlRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.folder_outlined, color: appGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dossier.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: appGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    dossier.role.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: appMutedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
