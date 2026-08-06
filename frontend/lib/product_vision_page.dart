import 'package:flutter/material.dart';

class ProductVisionPage extends StatelessWidget {
  const ProductVisionPage({super.key});

  static const _visionParagraphs = [
    'De HKH-app maakt de geschiedenis van Heemskerk toegankelijk als onderdeel van een veel grotere historische context.',
    'De app verbindt de collecties en kennis van de Historische Kring Heemskerk met relevante historische bronnen uit Noord-Holland, Nederland en daarbuiten, zoals archieven, musea, beeldbanken, kranten, kaarten en andere publieke collecties.',
    'Mensen moeten vanuit een gewone vraag, een plek, persoon, gebeurtenis of onderwerp op ontdekking kunnen gaan. Zij moeten verbanden kunnen vinden tussen verschillende tijden, gebieden, personen, bronnen en verhalen, zonder vooraf te hoeven weten waar informatie is opgeslagen.',
    'Wij ontsluiten en verbinden historische bronnen, zodat iedereen de geschiedenis van Heemskerk vanuit zijn eigen nieuwsgierigheid kan onderzoeken en beleven binnen de bredere geschiedenis van Noord-Holland, Nederland en de wereld.',
    'Zo ontstaat geen traditioneel digitaal archief, maar een toegankelijke en betrouwbare historische kenniswereld die uitnodigt tot ontdekken, doorvragen, onderzoeken, beleven en het maken van nieuwe verhalen.',
  ];

  static const _principles = [
    ('Verbonden', 'Heemskerk wordt nooit als een geïsoleerd eiland behandeld.'),
    ('Betrouwbaar', 'Antwoorden zijn herleidbaar tot bronnen.'),
    (
      'Meerstemmig',
      'Verschillende en tegenstrijdige verhalen mogen naast elkaar bestaan.',
    ),
    (
      'Toegankelijk',
      'Historische kennis moet ook vindbaar zijn zonder vakkennis.',
    ),
    ('Nieuwsgierig', 'Ieder antwoord moet uitnodigen tot verder ontdekken.'),
    (
      'Open',
      'Waar mogelijk worden publieke bronnen en open standaarden gebruikt.',
    ),
    (
      'Herbruikbaar',
      'Ontdekkingen moeten bruikbaar zijn voor verhalen, onderwijs, onderzoek en publicaties.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productvisie')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Productvisie',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    for (final paragraph in _visionParagraphs) ...[
                      Text(
                        paragraph,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Productprincipes',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    for (final principle in _principles)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.explore_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(principle.$1),
                          subtitle: Text(principle.$2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
