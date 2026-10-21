import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'site_widgets.dart';

const _crumbs = [('Vereniging', '/vereniging')];

/// Privacy- en cookieverklaring: welke cookies en gegevens de site gebruikt, waarvoor en hoe lang.
/// De tekst is een eerste versie; het bestuur controleert hem voor publicatie.
class PrivacyCookiePage extends StatelessWidget {
  const PrivacyCookiePage({super.key});

  static const contactEmail = 'info@historischekringheemskerk.nl';
  static const updated = '21 oktober 2026';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Text(text, style: theme.textTheme.titleLarge),
    );
    Widget paragraph(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SelectableText(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
      ),
    );
    Widget item(String name, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 10),
            child: Icon(Icons.circle, size: 7),
          ),
          Expanded(
            child: SelectableText.rich(
              TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                children: [
                  TextSpan(
                    text: '$name. ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return SitePage(
      title: 'Privacy- en cookieverklaring',
      children: [
        const PageHeading(
          title: 'Privacy- en cookieverklaring',
          crumbs: _crumbs,
          intro:
              'Welke gegevens deze website gebruikt, waarvoor en hoe lang. Laatst bijgewerkt op $updated.',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            key: const Key('privacy-page'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('Wie is verantwoordelijk'),
              paragraph(
                'De Historische Kring Heemskerk (HKH) is verantwoordelijk voor de gegevens die op deze website worden verwerkt. Vragen over privacy kunt u stellen via $contactEmail.',
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('privacy-regulation-link'),
                    onPressed: () => navigateTo(context, '/vereniging/anbi'),
                    child: const Text(
                      'Lees ook de Privacy- en Integriteitsregeling van de HKH',
                    ),
                  ),
                ),
              ),
              heading('Cookies en opslag in uw browser'),
              paragraph(
                'Deze website gebruikt alleen functionele cookies en functionele opslag in uw browser. Dat zijn gegevens die nodig zijn om de functies te laten werken die u zelf gebruikt. We gebruiken geen tracking-, advertentie- of analysecookies en delen geen gegevens met adverteerders. Daarom vragen we geen toestemming met een cookiemelding.',
              ),
              item(
                'hkh_ai_visitor',
                'Een cookie van de HKH dat onthoudt welke vragen aan de AI-zoekfunctie van u zijn, zodat u uw eerdere vragen en antwoorden terugvindt. Het bevat een willekeurig nummer zonder uw naam en blijft een jaar bewaard. Het wordt geplaatst zodra u de AI-zoekfunctie opent. Zonder dit cookie werkt de AI-zoekfunctie niet, tenzij u bent ingelogd.',
              ),
              item(
                'Technisch cookie van de server',
                'Een cookie met een naam van een lange reeks letters en cijfers. Het zorgt dat uw bezoek bij dezelfde server blijft en verdwijnt wanneer u de browser sluit.',
              ),
              item(
                'Inlogsessie',
                'Alleen als u inlogt met Google bewaart uw browser een sessiesleutel, zodat u ingelogd blijft tot u uitlogt.',
              ),
              item(
                'Weergavekeuze',
                'Uw browser onthoudt of u het zoekscherm of de volledige website als startpagina wilt.',
              ),
              paragraph(
                'U kunt cookies en opslag in uw browser altijd verwijderen of blokkeren via de instellingen van uw browser. De functies die ervan afhankelijk zijn, werken dan niet meer.',
              ),
              heading('Wat we bijhouden bij de zoekfuncties'),
              paragraph(
                'Bij elke AI-vraag en elke zoekopdracht in de collecties houden we een logboek bij met het tijdstip, uw IP-adres, het browsertype, de tekst van uw vraag of zoekopdracht, hoe lang het antwoord duurde, het gebruikte AI-model en de kosten. Bent u ingelogd, dan staat ook uw e-mailadres erbij. Daarnaast bewaren we een willekeurige sleutel, afgeleid van het bezoekerscookie of van uw IP-adres en browser, zodat we kunnen tellen hoeveel verschillende bezoekers de zoekfuncties gebruiken. Bezoeken van zoekmachines en scripts herkennen we en tellen we niet mee.',
              ),
              paragraph(
                'We doen dit om de zoekfuncties te beheren, de kwaliteit en de kosten te volgen, het gebruik te tellen en misbruik of storingen op te sporen. De grondslag is ons gerechtvaardigd belang om de website te beheren en te beveiligen.',
              ),
              paragraph(
                'Uw volledige IP-adres en de bezoekerssleutel bewaren we 30 dagen. Daarna kappen we het IP-adres af, zodat het laatste deel verdwijnt, en verwijderen we de sleutel. De tekst van vragen en zoekopdrachten bewaren we zonder IP-adres langer, om de AI-zoekfunctie te kunnen beoordelen en verbeteren. Vul daarom in een vraag geen persoonlijke gegevens in die u niet wilt laten bewaren.',
              ),
              heading('Wie krijgt uw AI-vraag'),
              paragraph(
                'Voor een AI-antwoord sturen we uw vraag en de gevonden stukken uit het archief naar een externe AI-dienst, op dit moment Anthropic (Claude), die daarmee het antwoord schrijft. Antwoorden kunnen fouten bevatten. Raadpleeg bij twijfel de oorspronkelijke bronnen.',
              ),
              heading('Inloggen en uw account'),
              paragraph(
                'Als u inlogt met Google bewaren we uw e-mailadres en naam, om u te herkennen en uw vragen aan uw account te koppelen. U kunt uw account en de bijbehorende gegevens laten verwijderen door contact met ons op te nemen.',
              ),
              heading('Hosting en beveiliging'),
              paragraph(
                'De website draait achter Cloudflare, dat het verkeer beveiligt en doorgeeft. Cloudflare verwerkt daarbij technische gegevens zoals uw IP-adres.',
              ),
              heading('Uw rechten'),
              paragraph(
                'U kunt ons vragen welke gegevens we van u hebben, ze te laten corrigeren of verwijderen, en bezwaar maken tegen de verwerking. Stuur daarvoor een e-mail naar $contactEmail. Bent u het niet eens met hoe we met uw gegevens omgaan, dan kunt u een klacht indienen bij de Autoriteit Persoonsgegevens.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse('https://autoriteitpersoonsgegevens.nl'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('autoriteitpersoonsgegevens.nl'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
