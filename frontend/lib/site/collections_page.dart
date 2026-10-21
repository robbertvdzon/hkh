import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'search_form.dart';
import 'site_widgets.dart';

/// Archief › Zoeken: één vraagveld; de vraag wordt door AI beantwoord. Zelf
/// zoeken kan via Handmatig zoeken.
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({this.questionsEnabled = true, super.key});
  final bool questionsEnabled;

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
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
    return SitePage(
      title: 'Zoeken in het archief',
      children: [
        const PageHeading(
          title: 'Zoeken in het archief',
          crumbs: [('Archief', '/archief')],
          intro:
              'Ruim 18.000 foto’s, krantenknipsels, boeken, bidprentjes, Heemskring-artikelen en voorwerpen. Stel uw vraag in gewone woorden.',
        ),
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('collections-query'),
                controller: _query,
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 17),
                decoration: const InputDecoration(
                  hintText: 'Bijvoorbeeld: wie was burgemeester Nielen?',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              if (widget.questionsEnabled) ...[
                const SizedBox(height: 12),
                const Text(
                  aiSearchExplanation,
                  key: Key('collections-explanation'),
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: appMutedText,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('collection-search-button'),
                onPressed: _submit,
                icon: Icon(
                  widget.questionsEnabled ? Icons.auto_awesome : Icons.search,
                  size: 18,
                ),
                label: Text(
                  widget.questionsEnabled ? 'Vraag stellen' : 'Zoeken',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (widget.questionsEnabled)
                    TextButton(
                      key: const Key('collections-earlier-questions'),
                      onPressed: () => navigateTo(context, '/vragen'),
                      child: const Text(
                        'Eerdere AI-onderzoeken bekijken',
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                  TextButton(
                    key: const Key('collections-manual'),
                    onPressed: () => openManualSearch(context),
                    child: const Text(
                      'Liever zelf zoeken? Handmatig zoeken in het archief',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: appSectionGap),
        const _AboutCollections(),
      ],
    );
  }
}

class _AboutCollections extends StatelessWidget {
  const _AboutCollections();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader('Over het archief'),
      CardGrid(
        children: [
          for (final collection in publicCollections)
            ContentCard(
              key: Key('collection-card-${collection.id}'),
              title: collection.label,
              text: collection.description,
              actionLabel: 'Bekijk',
              actionFilled: false,
              onTap: () => navigateTo(
                context,
                Uri(
                  path: '/zoeken',
                  queryParameters: {'collection': collection.id},
                ).toString(),
              ),
            ),
        ],
      ),
    ],
  );
}
