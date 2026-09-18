import 'package:flutter/material.dart';
import '../theme/app_style.dart';

/// Hetzelfde ruime vraagblok op de homepage en boven het vragenoverzicht.
class AiQuestionCard extends StatelessWidget {
  const AiQuestionCard({
    required this.controller,
    required this.onSubmit,
    this.enabled = true,
    this.onHistory,
    super.key,
  });
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback? onHistory;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Theme(
    data: appSurfaceTheme(context),
    child: Card(
      key: const Key('ai-question-card'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: appAccentBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appCardRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(isNarrowLayout(context) ? 20 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Wat wilt u weten?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: appGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stel gerust een uitgebreide onderzoeksvraag over families, relaties tussen mensen en plekken, of veranderingen door de tijd. De digitale onderzoeker zoekt de bronnen erbij; dit kan enkele minuten duren.',
              style: TextStyle(color: appGreen),
            ),
            const SizedBox(height: 18),
            _questionField(),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('ai-question-button'),
              onPressed: enabled ? onSubmit : null,
              child: const Text('Vraag stellen'),
            ),
            if (onHistory != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onHistory,
                  child: const Text(
                    'Eerdere vragen',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _questionField() => TextField(
    key: const Key('ai-question-field'),
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.multiline,
    textInputAction: TextInputAction.newline,
    minLines: 5,
    maxLines: 10,
    decoration: const InputDecoration(
      labelText: 'Uw vraag',
      floatingLabelBehavior: FloatingLabelBehavior.always,
      alignLabelWithHint: true,
      hintText:
          'Bijvoorbeeld: Onderzoek de geschiedenis van de familie Jansen in Heemskerk. Welke relaties vind je met andere families, de Kerklaan en lokale verenigingen? Beschrijf hoe die verbanden door de tijd veranderden en vermeld bij je bevindingen de bronnen.',
    ),
  );
}
