import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'answer_html.dart';

/// Aparte pagina met alle bronnen en beelden van één AI-antwoord.
/// De lijst komt kant-en-klaar als HTML uit de backend (`sourcesHtml`).
class AnswerSourcesPage extends StatelessWidget {
  const AnswerSourcesPage({
    required this.sourcesHtml,
    this.title,
    this.sourceCount,
    super.key,
  });

  final String sourcesHtml;
  final String? title;
  final int? sourceCount;

  /// Opent de bronnenpagina bovenop het huidige scherm.
  static Future<void> open(
    BuildContext context, {
    required String sourcesHtml,
    String? title,
    int? sourceCount,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AnswerSourcesPage(
        sourcesHtml: sourcesHtml,
        title: title,
        sourceCount: sourceCount,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: HkhAppBar(
      context: context,
      title: const Text('Bronnen en afbeeldingen'),
      onBack: () => Navigator.of(context).maybePop(),
      backLabel: 'Terug naar het antwoord',
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: appGreen,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                sourceCount == null
                    ? 'De bronnen waarop dit antwoord is gebaseerd.'
                    : 'De $sourceCount bronnen waarop dit antwoord is gebaseerd.',
                style: const TextStyle(color: appMutedText),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SelectionArea(child: AnswerHtml(sourcesHtml)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Knop "Alle bronnen (N)" onder een antwoord; alleen als er een losse bronnenlijst is.
class AnswerSourcesButton extends StatelessWidget {
  const AnswerSourcesButton({
    required this.sourcesHtml,
    required this.sourceCount,
    this.title,
    super.key,
  });

  final String? sourcesHtml;
  final int sourceCount;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final html = sourcesHtml;
    if (html == null || html.trim().isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: const Key('answer-sources-button'),
        onPressed: () => AnswerSourcesPage.open(
          context,
          sourcesHtml: html,
          title: title,
          sourceCount: sourceCount > 0 ? sourceCount : null,
        ),
        icon: const Icon(Icons.menu_book_outlined),
        label: Text(
          sourceCount > 0 ? 'Alle bronnen ($sourceCount)' : 'Alle bronnen',
        ),
      ),
    );
  }
}
