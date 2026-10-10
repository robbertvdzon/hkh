import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ai_search/ai_search.dart';
import '../theme/app_style.dart';
import 'site_widgets.dart';

/// Hoe er gezocht wordt: zelf in alle of één collectie, of met AI.
enum SearchMode { all, single, ai, aiThorough }

/// Collecties › Zoeken: één zoekveld met daaronder de keuze hoe te zoeken.
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({this.questionsEnabled = true, super.key});
  final bool questionsEnabled;

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final _query = TextEditingController();
  SearchMode _mode = SearchMode.all;
  String _collection = publicCollections.first.id;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _query.text.trim();
    switch (_mode) {
      case SearchMode.all:
      case SearchMode.single:
        navigateTo(
          context,
          Uri(
            path: '/zoeken',
            queryParameters: {
              if (query.isNotEmpty) 'q': query,
              if (_mode == SearchMode.single) 'collection': _collection,
            },
          ).toString(),
        );
      case SearchMode.ai:
      case SearchMode.aiThorough:
        if (query.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Typ eerst waar u naar op zoek bent.'),
            ),
          );
          return;
        }
        final draft = AiQuestionDraft(
          query,
          depth: _mode == SearchMode.ai
              ? AiResearchDepth.fast
              : AiResearchDepth.thorough,
        );
        final router = GoRouter.maybeOf(context);
        if (router != null) {
          router.go('/vragen', extra: draft);
        } else {
          navigateTo(context, '/vragen');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiSelected = _mode == SearchMode.ai || _mode == SearchMode.aiThorough;
    return SitePage(
      title: 'Zoeken in de collecties',
      children: [
        const PageHeading(
          title: 'Zoeken in de collecties',
          crumbs: [('Collecties', '/collecties')],
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
              _ModeOption(
                key: const Key('mode-all'),
                mode: SearchMode.all,
                groupValue: _mode,
                title: 'Zoeken in alle collecties',
                onChanged: (m) => setState(() => _mode = m),
              ),
              _ModeOption(
                key: const Key('mode-single'),
                mode: SearchMode.single,
                groupValue: _mode,
                title: 'Zoeken in één collectie',
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: DropdownButtonFormField<String>(
                    key: const Key('mode-single-collection'),
                    initialValue: _collection,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: [
                      for (final c in publicCollections)
                        DropdownMenuItem(value: c.id, child: Text(c.label)),
                    ],
                    onChanged: (v) => setState(() {
                      _collection = v ?? _collection;
                      _mode = SearchMode.single;
                    }),
                  ),
                ),
                onChanged: (m) => setState(() => _mode = m),
              ),
              if (widget.questionsEnabled) ...[
                _ModeOption(
                  key: const Key('mode-ai'),
                  mode: SearchMode.ai,
                  groupValue: _mode,
                  title:
                      'Met AI zoeken door alle collecties en hier een samenvatting van maken',
                  subtitle:
                      'Meestal binnen 2 minuten een antwoord met bronnen.',
                  onChanged: (m) => setState(() => _mode = m),
                ),
                _ModeOption(
                  key: const Key('mode-ai-thorough'),
                  mode: SearchMode.aiThorough,
                  groupValue: _mode,
                  title:
                      'Extra uitgebreid met AI zoeken door alle collecties en hier een samenvatting van maken',
                  subtitle:
                      'Meerdere zoekrondes en vervolgvragen; dit kan een kwartier duren.',
                  onChanged: (m) => setState(() => _mode = m),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('collection-search-button'),
                onPressed: _submit,
                icon: Icon(
                  aiSelected ? Icons.auto_awesome : Icons.search,
                  size: 18,
                ),
                label: Text(aiSelected ? 'Onderzoek starten' : 'Zoeken'),
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

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.groupValue,
    required this.title,
    required this.onChanged,
    this.subtitle,
    this.trailing,
    super.key,
  });
  final SearchMode mode;
  final SearchMode groupValue;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final ValueChanged<SearchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = mode == groupValue;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 13, color: appMutedText),
          ),
      ],
    );
    return InkWell(
      onTap: () => onChanged(mode),
      borderRadius: BorderRadius.circular(appControlRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Op smalle schermen komt de keuzelijst onder de tekst.
            final stacked = trailing != null && constraints.maxWidth < 560;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Radio<SearchMode>(
                  value: mode,
                  // ignore: deprecated_member_use
                  groupValue: groupValue,
                  // ignore: deprecated_member_use
                  onChanged: (m) => onChanged(m ?? mode),
                ),
                Expanded(
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            text,
                            const SizedBox(height: 6),
                            trailing!,
                          ],
                        )
                      : text,
                ),
                if (trailing != null && !stacked) ...[
                  const SizedBox(width: 12),
                  Flexible(child: trailing!),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
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

/// De zes publieke collecties, zoals op de oude site.
const publicCollections = [
  (
    id: 'beeldbank',
    label: 'Foto’s',
    description:
        'Meer dan 12.000 foto’s van straten, gebouwen, mensen en gebeurtenissen, op straatnaam, wijk en thema.',
  ),
  (
    id: 'archief',
    label: 'Archief',
    description:
        'Ruim 1.800 krantenknipsels en documenten over Heemskerk, doorzoekbaar op tekst.',
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
