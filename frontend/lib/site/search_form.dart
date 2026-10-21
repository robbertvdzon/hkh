import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ai_search/ai_search.dart';
import '../theme/app_style.dart';
import 'site_widgets.dart';

/// Hoe er gezocht wordt: met AI of zelf in het hele archief of één onderdeel. [aiThorough]
/// wordt niet meer aangeboden (de pijplijn kent geen diepte) maar blijft bestaan
/// voor bestaande verwijzingen.
enum SearchMode { ai, aiThorough, all, single }

/// De zes onderdelen van het archief, zoals op de oude site.
const publicCollections = [
  (
    id: 'beeldbank',
    label: 'Foto’s',
    description:
        'Meer dan 12.000 foto’s van straten, gebouwen, mensen en gebeurtenissen, op straatnaam, wijk en thema.',
  ),
  (
    id: 'archief',
    label: 'Krantenknipsels en documenten',
    description:
        'Ruim 1.700 krantenknipsels, kaarten en akten over Heemskerk, doorzoekbaar op tekst.',
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

/// Voert een zoekopdracht uit: zelf zoeken opent de zoekpagina, AI-zoeken
/// start een onderzoek. Geeft false terug als er geen vraag is ingevuld terwijl
/// die nodig is.
bool submitSearch(
  BuildContext context, {
  required SearchMode mode,
  required String query,
  required String collection,
}) {
  final trimmed = query.trim();
  switch (mode) {
    case SearchMode.all:
    case SearchMode.single:
      navigateTo(
        context,
        Uri(
          path: '/zoeken',
          queryParameters: {
            if (trimmed.isNotEmpty) 'q': trimmed,
            if (mode == SearchMode.single) 'collection': collection,
          },
        ).toString(),
      );
      return true;
    case SearchMode.ai:
    case SearchMode.aiThorough:
      if (trimmed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Typ eerst waar u naar op zoek bent.')),
        );
        return false;
      }
      final draft = AiQuestionDraft(
        trimmed,
        depth: mode == SearchMode.ai
            ? AiResearchDepth.fast
            : AiResearchDepth.thorough,
      );
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        router.go('/vragen', extra: draft);
      } else {
        navigateTo(context, '/vragen');
      }
      return true;
  }
}

/// Knoptekst bij een zoekwijze.
String searchButtonLabel(SearchMode mode) =>
    mode == SearchMode.ai || mode == SearchMode.aiThorough
    ? 'Onderzoek starten'
    : 'Zoeken';

/// De drie zoekwijzen als keuzerondjes, met AI bovenaan.
class SearchModeOptions extends StatelessWidget {
  const SearchModeOptions({
    required this.mode,
    required this.collection,
    required this.onModeChanged,
    required this.onCollectionChanged,
    this.questionsEnabled = true,
    super.key,
  });

  final SearchMode mode;
  final String collection;
  final ValueChanged<SearchMode> onModeChanged;
  final ValueChanged<String> onCollectionChanged;
  final bool questionsEnabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (questionsEnabled) ...[
        ModeOption(
          key: const Key('mode-ai'),
          mode: SearchMode.ai,
          groupValue: mode,
          title:
              'Met AI zoeken door het hele archief en hier een samenvatting van maken',
          subtitle:
              'Meestal binnen 2 minuten een beknopt antwoord met bronnen; daarna kun je het volledig laten uitwerken.',
          onChanged: onModeChanged,
        ),
      ],
      ModeOption(
        key: const Key('mode-all'),
        mode: SearchMode.all,
        groupValue: mode,
        title: 'Zelf zoeken in het hele archief',
        onChanged: onModeChanged,
      ),
      ModeOption(
        key: const Key('mode-single'),
        mode: SearchMode.single,
        groupValue: mode,
        title: 'Zelf zoeken in één onderdeel van het archief',
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: DropdownButtonFormField<String>(
            key: const Key('mode-single-collection'),
            initialValue: collection,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final c in publicCollections)
                DropdownMenuItem(value: c.id, child: Text(c.label)),
            ],
            onChanged: (v) {
              if (v != null) onCollectionChanged(v);
              onModeChanged(SearchMode.single);
            },
          ),
        ),
        onChanged: onModeChanged,
      ),
    ],
  );
}

class ModeOption extends StatelessWidget {
  const ModeOption({
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
