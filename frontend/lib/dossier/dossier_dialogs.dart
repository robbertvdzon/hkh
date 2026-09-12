import 'package:flutter/material.dart';

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
    return AlertDialog(
      title: Text(isNew ? 'Nieuw dossier' : 'Titel en doel bewerken'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: 200,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Titel',
                hintText: 'Bijv. De Kerklaan en haar bewoners',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goal,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Doel',
                hintText:
                    'Wat wil je met dit onderzoek bereiken? Bijv. een artikel voor het verenigingsblad.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        FilledButton(
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
    final dossiers = _dossiers;
    return AlertDialog(
      title: const Text('In dossier zetten'),
      content: SizedBox(
        width: 440,
        child: _error != null
            ? Text(_error!)
            : dossiers == null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : dossiers.isEmpty
            ? const Text(
                'Je hebt nog geen dossier waarin je vragen mag stellen. Maak eerst een dossier aan bij Mijn dossiers.',
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Kies het dossier waarin deze zoekopdracht hoort. De vraag en het antwoord worden dan voor alle leden zichtbaar.',
                    ),
                  ),
                  for (final dossier in dossiers)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(dossier.title),
                      subtitle: Text(dossier.role.label),
                      onTap: () => Navigator.pop(context, dossier),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
      ],
    );
  }
}
