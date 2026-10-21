import 'package:flutter/material.dart';

import '../theme/app_style.dart';
import 'search_form.dart';
import 'site_widgets.dart';

/// Archief › Zoeken: één zoekveld met daaronder de keuze hoe te zoeken.
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({this.questionsEnabled = true, super.key});
  final bool questionsEnabled;

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final _query = TextEditingController();
  late SearchMode _mode = widget.questionsEnabled
      ? SearchMode.ai
      : SearchMode.all;
  String _collection = publicCollections.first.id;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _submit() => submitSearch(
    context,
    mode: _mode,
    query: _query.text,
    collection: _collection,
  );

  @override
  Widget build(BuildContext context) {
    return SitePage(
      title: 'Zoeken in het archief',
      children: [
        const PageHeading(
          title: 'Zoeken in het archief',
          crumbs: [('Archief', '/archief')],
          intro:
              'Ruim 18.000 foto’s, archiefstukken, boeken, bidprentjes, Heemskring-artikelen en voorwerpen. Typ een naam, straat, onderwerp of jaartal en kies hoe u wilt zoeken.',
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
                  hintText: 'Bijvoorbeeld: Kerklaan, Diemeer, aardbeien, 1953',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 14),
              SearchModeOptions(
                mode: _mode,
                collection: _collection,
                questionsEnabled: widget.questionsEnabled,
                onModeChanged: (m) => setState(() => _mode = m),
                onCollectionChanged: (c) => setState(() => _collection = c),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('collection-search-button'),
                onPressed: _submit,
                icon: Icon(
                  _mode == SearchMode.ai || _mode == SearchMode.aiThorough
                      ? Icons.auto_awesome
                      : Icons.search,
                  size: 18,
                ),
                label: Text(searchButtonLabel(_mode)),
              ),
              if (widget.questionsEnabled) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('collections-earlier-questions'),
                    onPressed: () => navigateTo(context, '/vragen'),
                    child: const Text(
                      'Eerdere AI-onderzoeken bekijken',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => navigateTo(context, '/zoeken'),
            icon: const Icon(Icons.tune, size: 18),
            label: const Text(
              'Uitgebreid zoeken: filters op straat, thema, periode, auteur en meer',
            ),
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
