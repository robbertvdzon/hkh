import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ai_search/ai_search.dart';
import 'site_widgets.dart';

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

/// Uitleg onder het vraagveld van Zoeken: wat er gebeurt en dat het even duurt.
const aiSearchExplanation =
    'Zoekt in het hele archief: foto’s, krantenknipsels, boeken, bidprentjes en artikelen. Op basis van wat er gevonden wordt schrijft het een antwoord met bronnen. Dit duurt even, ongeveer twee minuten; onderweg ziet u de eerste treffers.';

/// Start een AI-onderzoek met de ingevulde vraag. Zonder AI (of zonder
/// ingevulde vraag) verandert er niets, behalve een melding bij een lege vraag.
/// Geeft false terug als er geen vraag is ingevuld.
bool submitAiQuestion(BuildContext context, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Typ eerst waar u naar op zoek bent.')),
    );
    return false;
  }
  final draft = AiQuestionDraft(trimmed, depth: AiResearchDepth.fast);
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go('/vragen', extra: draft);
  } else {
    navigateTo(context, '/vragen');
  }
  return true;
}

/// Opent het handmatige zoeken in het archief, eventueel met een zoekterm.
void openManualSearch(BuildContext context, [String query = '']) {
  final trimmed = query.trim();
  navigateTo(
    context,
    Uri(
      path: '/zoeken',
      queryParameters: {if (trimmed.isNotEmpty) 'q': trimmed},
    ).toString(),
  );
}
