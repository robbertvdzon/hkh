import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ai_search/ai_question_card.dart';
import '../ai_search/ai_search.dart';
import '../collection/collection_config.dart';
import '../theme/app_style.dart';
import 'site_widgets.dart';

/// Collecties: ingang naar zoeken en naar 'Vraag het archief'.
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({this.questionsEnabled = true, super.key});
  final bool questionsEnabled;

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final _question = TextEditingController();
  final _query = TextEditingController();
  AiResearchDepth _depth = AiResearchDepth.fast;

  @override
  void dispose() {
    _question.dispose();
    _query.dispose();
    super.dispose();
  }

  void _ask() {
    final question = _question.text.trim();
    final draft = question.isEmpty
        ? null
        : AiQuestionDraft(question, depth: _depth);
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/vragen', extra: draft);
    } else {
      navigateTo(context, '/vragen');
    }
  }

  void _search([String? collection]) {
    final query = _query.text.trim();
    navigateTo(
      context,
      Uri(
        path: '/zoeken',
        queryParameters: {
          if (query.isNotEmpty) 'q': query,
          if (collection != null) 'collection': collection,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) => SitePage(
    title: 'Collecties',
    children: [
      const PageHeading(
        title: 'Collecties',
        intro:
            'Ruim 18.000 foto’s, archiefstukken, boeken, bidprentjes, Heemskring-artikelen en voorwerpen, verzameld en beschreven door de werkgroepen van de HKH. Zoek zelf, of stel een vraag aan het archief.',
      ),
      AppCard(
        key: const Key('collection-search-section'),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Zelf zoeken in de collecties',
              style: TextStyle(
                fontFamily: appSerifFont,
                fontSize: 24,
                color: appGreen,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Zoek een naam, straat, onderwerp of collectienummer. Kies daarna een collectie of verfijn met filters.',
              style: TextStyle(color: appMutedText, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('collections-query'),
              controller: _query,
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Bijvoorbeeld: Kerklaan, Diemeer, aardbeien, 1953',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('collection-search-button'),
              onPressed: _search,
              child: const Text('Zoeken in alle collecties'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Of ga direct naar een collectie',
              style: TextStyle(color: appMutedText),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final collection in publicCollections)
                  ActionChip(
                    key: Key('collection-chip-${collection.id}'),
                    label: Text(collection.label),
                    onPressed: () => _search(collection.id),
                  ),
              ],
            ),
          ],
        ),
      ),
      if (widget.questionsEnabled) ...[
        const SizedBox(height: appSectionGap),
        AiQuestionCard(
          controller: _question,
          onSubmit: _ask,
          onHistory: () => navigateTo(context, '/vragen'),
          depth: _depth,
          onDepthChanged: (depth) => setState(() => _depth = depth),
        ),
      ],
      const SizedBox(height: appSectionGap),
      const _AboutCollections(),
    ],
  );
}

class _AboutCollections extends StatelessWidget {
  const _AboutCollections();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader('Over de collecties'),
      CardGrid(
        children: [
          for (final collection in publicCollections)
            ContentCard(
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
      const SizedBox(height: 28),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zelf iets aanleveren?',
              style: TextStyle(
                fontFamily: appSerifFont,
                fontSize: 22,
                color: appGreen,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Heeft u foto’s, bidprentjes, documenten of voorwerpen die voor de geschiedenis van Heemskerk van belang kunnen zijn? Breng ze langs in het Historisch Huis op maandagmiddag; dan kijken we samen of we er een mooie bestemming voor kunnen vinden. Een afdruk van een foto uit de beeldbank bestellen kan ook.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      navigateTo(context, '/vereniging/historisch-huis'),
                  child: const Text('Historisch Huis en openingstijden'),
                ),
                OutlinedButton(
                  onPressed: () => navigateTo(context, '/vereniging/uitgaven'),
                  child: const Text('Foto laten afdrukken'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

/// De zes publieke collecties, zoals op de oude site.
const publicCollections = [
  (
    id: 'archief',
    label: 'Archief',
    description:
        'Ruim 1.800 krantenknipsels en documenten over Heemskerk, doorzoekbaar op tekst.',
  ),
  (
    id: 'beeldbank',
    label: 'Foto’s',
    description:
        'Meer dan 12.000 foto’s van straten, gebouwen, mensen en gebeurtenissen, op straatnaam, wijk en thema.',
  ),
  (
    id: 'bibliotheek',
    label: 'Bibliotheek',
    description:
        'Ruim 1.600 boeken en tijdschriften over Heemskerk en de regio, in te zien in het Historisch Huis.',
  ),
  (
    id: 'bidprentjes',
    label: 'Bidprentjes',
    description:
        'Ruim 1.300 gedachtenisprentjes met genealogische gegevens, doorzoekbaar op naam en geboortedatum.',
  ),
  (
    id: 'artikelen',
    label: 'Artikelen',
    description:
        'Ruim 500 artikelen uit de Heemskring, het magazine van de HKH, met doorzoekbare tekst.',
  ),
  (
    id: 'objecten',
    label: 'Objecten',
    description:
        'Ruim 750 voorwerpen uit het depot: gereedschap, huishouden, kerk en bedrijf.',
  ),
];

/// Het zoekscherm kent dezelfde collecties onder dezelfde id's.
// ignore: unused_element
final _collectionIdsKnown = publicCollections.every(
  (c) => collectionConfig(c.id).label.isNotEmpty,
);
