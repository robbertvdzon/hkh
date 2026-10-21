import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'search_form.dart';
import 'site_widgets.dart';

/// Voorbeeldvragen op het zoekscherm; een klik zet de vraag in het veld.
const exampleQuestions = [
  'Wat is er bekend over de aardbeienteelt in Heemskerk?',
  'Wie woonden er rond 1900 aan de Kerkweg?',
  'Wat gebeurde er in Heemskerk tijdens de Tweede Wereldoorlog?',
];

/// Het zoekscherm: één vraagveld dat door AI wordt beantwoord, met een
/// verwijzing naar handmatig zoeken in het archief.
class SimpleSearchPage extends StatefulWidget {
  const SimpleSearchPage({this.questionsEnabled = true, super.key});
  final bool questionsEnabled;

  @override
  State<SimpleSearchPage> createState() => _SimpleSearchPageState();
}

class _SimpleSearchPageState extends State<SimpleSearchPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _submit() => widget.questionsEnabled
      ? submitAiQuestion(context, _query.text)
      : openManualSearch(context, _query.text);

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrowLayout(context);
    return SitePage(
      title: 'Zoeken in de geschiedenis van Heemskerk',
      children: [
        SizedBox(height: narrow ? 28 : 56),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Stel een vraag over de geschiedenis van Heemskerk',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: appSerifFont,
                      fontSize: narrow ? 28 : 38,
                      height: 1.2,
                      color: appGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Zoekt in het hele archief van de Historische Kring Heemskerk: ruim 18.000 foto’s, documenten, boeken, bidprentjes en artikelen. Op basis van wat er gevonden wordt schrijft het een antwoord met bronnen. Dit duurt even, ongeveer twee minuten.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.5,
                    color: appMutedText,
                  ),
                ),
                const SizedBox(height: 28),
                AppCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('simple-query'),
                        controller: _query,
                        onSubmitted: (_) => _submit(),
                        textInputAction: TextInputAction.search,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(
                          hintText:
                              'Bijvoorbeeld: wie was burgemeester Nielen?',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        key: const Key('simple-submit'),
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        icon: Icon(
                          widget.questionsEnabled
                              ? Icons.auto_awesome
                              : Icons.search,
                          size: 20,
                        ),
                        label: Text(
                          widget.questionsEnabled ? 'Vraag stellen' : 'Zoeken',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton(
                            key: const Key('simple-collections'),
                            onPressed: () => openManualSearch(context),
                            child: const Text(
                              'Liever zelf zoeken? Handmatig zoeken',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          if (widget.questionsEnabled)
                            TextButton(
                              key: const Key('simple-earlier'),
                              onPressed: () => navigateTo(context, '/vragen'),
                              child: const Text(
                                'Eerdere vragen',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.questionsEnabled) ...[
                  const SizedBox(height: 22),
                  const Text(
                    'Probeer bijvoorbeeld',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: appMutedText),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final question in exampleQuestions)
                        ActionChip(
                          label: Text(question),
                          onPressed: () => setState(() {
                            _query.text = question;
                          }),
                        ),
                    ],
                  ),
                ],
                SizedBox(height: narrow ? 32 : 72),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
