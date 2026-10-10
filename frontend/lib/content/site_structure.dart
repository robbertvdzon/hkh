/// De indeling van de site: welke pagina's in welke rubriek staan, plus de
/// inhoud die niet als pagina van de oude site komt (educatie, nieuwsbrieven,
/// partnerlinks, praktische gegevens).
///
/// Zie docs/website-vernieuwing/03-voorstel-nieuwe-structuur.md.
library;

import 'content_models.dart';
import 'generated_content.dart';
import 'generated_memory.dart';

const siteName = 'Historische Kring Heemskerk';
const siteTagline = 'Vereniging voor de geschiedenis van Heemskerk';

/// Praktische gegevens; in fase 2 beheerbaar.
const practicalInfo = (
  address: 'A. Verherentstraat 5/2a',
  postalCode: '1961 GD Heemskerk',
  postbox: 'Postbus 46, 1960 AA Heemskerk',
  phone: '(0251) 25 26 58',
  email: 'info@historischekringheemskerk.nl',
  registrationEmail: 'opgeven@historischekringheemskerk.nl',
  openingHours: 'Elke maandag van 14.00 tot 16.00 uur',
  membershipFee: '€ 18,75 per jaar',
  mapsUrl: 'https://maps.google.com/maps?q=A.Verherentstraat+5+Heemskerk',
);

const socialLinks = [
  PartnerLink('YouTube', 'https://www.youtube.com/@HistorischeKringHeemskerk'),
  PartnerLink('Instagram', 'https://www.instagram.com/historischekringheemskerk/'),
  PartnerLink('Facebook', 'https://www.facebook.com/groups/historischekringheemskerk'),
];

/// Hoofdmenu: label en route.
const mainMenu = [
  (label: 'Agenda', path: '/agenda'),
  (label: 'Nieuws', path: '/nieuws'),
  (label: 'Ontdek Heemskerk', path: '/ontdek'),
  (label: 'Geheugen van Heemskerk', path: '/geheugen'),
  (label: 'Collecties', path: '/collecties'),
  (label: 'Educatie', path: '/educatie'),
  (label: 'Vereniging', path: '/vereniging'),
];

/// Submenubalk per hoofditem: alleen voor onderdelen met meerdere ingangen.
/// De balk blijft staan zolang de bezoeker binnen dat onderdeel is.
const subMenus = <String, List<({String label, String path})>>{
  '/nieuws': [
    (label: 'Berichten', path: '/nieuws'),
    (label: 'Nieuwsbrieven', path: '/nieuws/nieuwsbrieven'),
    (label: 'Heemskring', path: '/nieuws/heemskring'),
  ],
  '/ontdek': [
    (label: 'Kastelen', path: '/ontdek/kastelen'),
    (label: 'Gebouwen en monumenten', path: '/ontdek/gebouwen'),
    (label: 'Personen', path: '/ontdek/personen'),
    (label: 'Verhalen', path: '/ontdek/verhalen'),
    (label: 'Exposities', path: '/ontdek/exposities'),
  ],
  '/geheugen': [
    (label: 'Alle verhalen', path: '/geheugen'),
    (label: 'Thema’s', path: '/geheugen/themas'),
    (label: 'Buurten', path: '/geheugen/buurten'),
    (label: 'Over het project', path: '/geheugen/over'),
  ],
  '/collecties': [
    (label: 'Overzicht', path: '/collecties'),
    (label: 'Zoeken in de collecties', path: '/zoeken'),
    (label: 'Onderzoek', path: '/vragen'),
  ],
  '/vereniging': [
    (label: 'Over de HKH', path: '/vereniging/over-de-hkh'),
    (label: 'Bestuur', path: '/vereniging/bestuur'),
    (label: 'Werkgroepen', path: '/vereniging/werkgroepen'),
    (label: 'Historisch Huis', path: '/vereniging/historisch-huis'),
    (label: 'Uitgaven', path: '/vereniging/uitgaven'),
    (label: 'ANBI', path: '/vereniging/anbi'),
    (label: 'Contact', path: '/vereniging/contact'),
  ],
};

/// Bestemming van een hoofditem: het eerste subitem als er een submenubalk is.
String menuTargetFor(String menuPath) {
  final subs = subMenus[menuPath];
  return subs == null || subs.isEmpty ? menuPath : subs.first.path;
}

/// Hoofditem waar een route onder valt, of null.
String? mainMenuPathFor(String location) {
  for (final item in mainMenu) {
    if (isMainMenuPathActive(item.path, location)) return item.path;
  }
  return null;
}

/// Of een hoofdingang als actief telt voor de huidige route.
bool isMainMenuPathActive(String menuPath, String currentPath) {
  if (menuPath == '/collecties') {
    return currentPath.startsWith('/collecties') ||
        currentPath.startsWith('/zoeken') ||
        currentPath.startsWith('/objecten') ||
        currentPath.startsWith('/vragen') ||
        currentPath.startsWith('/gedeeld');
  }
  if (menuPath == '/ontdek') {
    return currentPath.startsWith('/ontdek') ||
        currentPath.startsWith('/luchtfoto');
  }
  return currentPath == menuPath || currentPath.startsWith('$menuPath/');
}

/// Subitems van de hoofdingang waar [location] onder valt; leeg als er geen
/// submenubalk hoort.
List<({String label, String path})> subMenuFor(String location) =>
    subMenus[mainMenuPathFor(location) ?? ''] ?? const [];

/// Actieve subitem-route voor [location]: het subitem met het langste pad
/// dat een voorvoegsel van de route is.
String? activeSubMenuPath(String location) {
  final normalized = location.startsWith('/objecten') ||
          location.startsWith('/gedeeld')
      ? '/zoeken'
      : location;
  String? best;
  for (final item in subMenuFor(location)) {
    final matches =
        normalized == item.path || normalized.startsWith('${item.path}/');
    if (matches && (best == null || item.path.length > best.length)) {
      best = item.path;
    }
  }
  return best;
}

// ---------------------------------------------------------------------------
// Ontdek Heemskerk
// ---------------------------------------------------------------------------

const storyCategories = [
  StoryCategory(
    slug: 'kastelen',
    title: 'Kastelen',
    description:
        'In Heemskerk stonden meer kastelen dan u zou denken. Van de meeste zijn nog sporen te vinden.',
    pageSlugs: [
      'alle-kastelen-op-de-kaart',
      'kastelen-assumburg',
      'kastelen-marquette',
      'kastelen-oud-haarlem',
      'kastelen-meeresteijn',
      'kastelen-poelenburg',
      'kastelen-de-vlotter',
      'kastelen-rietwijk-of-reewijk',
      'kastelen-beijerlust',
      'kastelen-t-hoge-werfje',
    ],
  ),
  StoryCategory(
    slug: 'gebouwen',
    title: 'Gebouwen en monumenten',
    description:
        'Kerken, een fort en een eeuwenoude rechtsplaats: de gebouwde geschiedenis van het dorp.',
    pageSlugs: [
      'dorpskerk-en-kerkhof',
      'laurentiuskerk',
      'fort-veldhuis',
      'huldtoneel',
      'historisch-huis',
    ],
  ),
  StoryCategory(
    slug: 'personen',
    title: 'Personen',
    description: 'Heemskerkers die hun sporen nalieten.',
    pageSlugs: ['maerten-van-heemskerck'],
  ),
  StoryCategory(
    slug: 'verhalen',
    title: 'Verhalen',
    description:
        'Hoe het dorp ontstond en hoe Heemskerkers aan hun bijnaam kwamen. Persoonlijke herinneringen staan in het Geheugen van Heemskerk.',
    pageSlugs: ['heemskerker-ezels', 'over-heemskerk'],
  ),
  StoryCategory(
    slug: 'exposities',
    title: 'Exposities',
    description:
        'Tentoonstellingen die de HKH door de jaren heen inrichtte, met de fotoboeken die ervan zijn gemaakt.',
    pageSlugs: [
      'exposities-van-historische-kring-heemskerk',
      'expositie-deutzstraat',
    ],
  ),
];

/// Google My Maps met alle kastelen (op de oude site als iframe).
const castleMapUrl =
    'https://www.google.com/maps/d/viewer?mid=1wK6MtL019sdSv1KXr0noGkSMfwtJ2XRu';

// ---------------------------------------------------------------------------
// Geheugen van Heemskerk
// ---------------------------------------------------------------------------

const memoryIntro =
    'In 2005 initieerde Welschap Welzijn het Geheugen van Heemskerk als interactief project om gewone, alledaagse en bijzondere herinneringen en verhalen samen te laten komen. Meer dan twintig verhalenverzamelaars tekenden verhalen van Heemskerkers op. In 2010 stopte het project; sinds 2012 bewaart de Historische Kring Heemskerk de verhalen.';

/// Thema's met het aantal verhalen, meest voorkomende eerst.
List<({String name, int count})> memoryThemes() => _countBy((s) => s.theme);

/// Buurten met het aantal verhalen, meest voorkomende eerst.
List<({String name, int count})> memoryNeighbourhoods() =>
    _countBy((s) => s.neighbourhood);

/// Verhalenverzamelaars met het aantal verhalen, alfabetisch.
List<({String name, int count})> memoryAuthors() {
  final list = _countBy((s) => s.author);
  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}

List<({String name, int count})> _countBy(String Function(MemoryStory) key) {
  final counts = <String, int>{};
  for (final story in generatedMemoryStories) {
    final k = key(story).trim();
    if (k.isEmpty || k == '.') continue;
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final list = [
    for (final entry in counts.entries) (name: entry.key, count: entry.value),
  ]..sort((a, b) => b.count.compareTo(a.count));
  return list;
}

MemoryStory? memoryStoryBySlug(String slug) {
  for (final story in generatedMemoryStories) {
    if (story.slug == slug) return story;
  }
  return null;
}

/// Verhalen op alfabet, optioneel beperkt tot thema, buurt of auteur.
List<MemoryStory> memoryStories({
  String? theme,
  String? neighbourhood,
  String? author,
}) {
  final list = generatedMemoryStories
      .where((s) => theme == null || s.theme == theme)
      .where((s) => neighbourhood == null || s.neighbourhood == neighbourhood)
      .where((s) => author == null || s.author == author)
      .toList();
  list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return list;
}

// ---------------------------------------------------------------------------
// Vereniging
// ---------------------------------------------------------------------------

/// Onderdelen van Vereniging: label, route-slug en een korte omschrijving.
const associationSections = [
  (
    slug: 'over-de-hkh',
    title: 'Over de HKH',
    description: 'Doel en ontstaan van de vereniging, en wat zij doet.',
    pageSlug: 'over-historische-kring-heemskerk',
  ),
  (
    slug: 'bestuur',
    title: 'Bestuur',
    description: 'De bestuursleden, hun rol en hoe u ze bereikt.',
    pageSlug: null,
  ),
  (
    slug: 'werkgroepen',
    title: 'Werkgroepen en meedoen',
    description: 'Twaalf werkgroepen en ruim honderd vrijwilligers.',
    pageSlug: 'werkgroepen',
  ),
  (
    slug: 'historisch-huis',
    title: 'Historisch Huis',
    description: 'Adres, openingstijden en de geschiedenis van de St. Mariaschool.',
    pageSlug: 'openstelling-historisch-huis',
  ),
  (
    slug: 'heemsstichting',
    title: 'Heemsstichting',
    description: 'Bewaker van monumentaal erfgoed in Heemskerk.',
    pageSlug: 'heemsstichting',
  ),
  (
    slug: 'uitgaven',
    title: 'Uitgaven en winkel',
    description: 'Heemskring, boeken, wandelingen en fotoafdrukken.',
    pageSlug: null,
  ),
  (
    slug: 'anbi',
    title: 'ANBI en documenten',
    description: 'Financiën, beleidsplan, privacy en disclaimer.',
    pageSlug: null,
  ),
  (
    slug: 'contact',
    title: 'Contact',
    description: 'Stuur een bericht, bel of kom langs.',
    pageSlug: null,
  ),
  (
    slug: 'links',
    title: 'Links',
    description: 'Partnerorganisaties in de regio.',
    pageSlug: null,
  ),
];

/// Documenten onder ANBI: de pagina's die samen de verantwoording vormen.
const documentPageSlugs = [
  'financien',
  'beleidsplan',
  'privacy-integriteitsregeling',
  'juridische-disclaimer',
];

const partnerLinks = [
  PartnerLink('Museum Kennemerland', 'https://museumkennemerland.nl/'),
  PartnerLink('Historisch Genootschap Midden-Kennemerland', 'https://hgmk.nl/'),
  PartnerLink('Oud Castricum', 'https://www.oud-castricum.nl/'),
  PartnerLink('Oud Uitgeest', 'https://www.ouduitgeest.nl/'),
  PartnerLink(
    'Historisch Genootschap Assendelft',
    'https://historischgenootschapassendelft.nl/',
  ),
  PartnerLink('Historische Kring Velsen', 'https://historischekringvelsen.nl/'),
  PartnerLink('Stichting Oer-IJ', 'https://www.oerij.eu/'),
  PartnerLink(
    'Aircraft Recovery Group 40-45',
    'https://www.fortveldhuis1940-1945.nl/',
  ),
  PartnerLink('Gemeente Heemskerk', 'https://www.heemskerk.nl/'),
  PartnerLink('Reclamebureau ARTbeving', 'https://www.artbeving.nl'),
];

/// Ontvangers van het contactformulier, zoals op de oude site.
const contactRecipients = [
  'Voorzitter',
  'Secretaris',
  'Penningmeester',
  'Bezorging - ledenadministratie',
  'Webmaster',
];

// ---------------------------------------------------------------------------
// Nieuws
// ---------------------------------------------------------------------------

const newsletters = [
  Newsletter(
    number: 97,
    title: 'Nieuwsbrief 97 · april 2026',
    description:
        'In deze nieuwsbrief treft u aan de uitnodiging voor de voorjaarsledenvergadering op 14 april 2026, notulen van de najaarsledenvergadering van 19 november 2025, jaarverslagen 2025 van het secretariaat, exploitatie overzicht en balans 2025 door de penningmeester, terugblik van het bestuur op het afgelopen jaar. Verder berichten van de werkgroep educatie over activiteiten voor het schooljaar 2026-2027. Een vooruitblik op de expositie over Heemskerk in de tweede wereldoorlog en diverse andere wetenswaardigheden.',
    pdfUrl:
        'https://www.historischekringheemskerk.nl/wp-content/uploads/2026/04/130426_Nieuwsbrief-97_LR.pdf',
  ),
  Newsletter(
    number: 96,
    title: 'Nieuwsbrief 96 · november 2025',
    description:
        'In deze nieuwsbrief staat de uitnodiging voor de najaarsledenvergadering op 19 november 2025, het verslag van de voorjaarsledenvergadering 2025, de financiële Begroting 2026 en diverse berichten over activiteiten en statutenwijziging.',
    pdfUrl:
        'https://www.historischekringheemskerk.nl/wp-content/uploads/2026/04/211025_Nieuwsbrief-96_LR.pdf',
  ),
  Newsletter(
    number: 95,
    title: 'Nieuwsbrief 95 · april 2025',
    description:
        'In deze nieuwsbrief 95 van april 2025 zijn opgenomen: de uitnodiging voor onze voorjaarsledenvergadering op 15 april; berichten van het bestuur en diverse werkgroepen; het verslag van de najaarsledenvergadering van 12 november 2024; het financieel jaarverslag 2024 met toelichting; een overpeinzing van onze voorzitter; gedicht en verder berichtgevingen over de viering rond de tentoonstelling ‘Heemskerk toen en nu’. Tenslotte is evenals de voorgaande nieuwsbrieven ruimte voor de komende statutenwijziging met de mogelijkheid voor onze leden hun stem daarover uit te brengen.',
    pdfUrl:
        'https://www.historischekringheemskerk.nl/wp-content/uploads/2025/05/Nieuwsbrief-95.pdf',
  ),
  Newsletter(
    number: 94,
    title: 'Nieuwsbrief 94 · november 2024',
    description:
        'In deze nieuwsbrief 94 van november 2024 zijn opgenomen: de uitnodiging voor onze najaarsledenvergadering op 12 november; berichten van het bestuur en diverse werkgroepen; het verslag van de voorjaarsledenvergadering van 18 april 2024; de financiële begroting 2025 met toelichting; even wat anders, overpeinzingen van onze voorzitter; gedicht “Maerten” door Gaijus (Gerard Castricum) en verder berichtgevingen over de viering rond de herdenking aan Maerten van Heemskerck; aankondiging tentoonstelling ‘Heemskerk toen en nu’.',
    pdfUrl:
        'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/11/Nieuwsbrief-94.pdf',
  ),
];

const heemskringIntro =
    'De Heemskring is het lijfblad van de HKH: twee keer per jaar verhalen uit de geschiedenis van ons ‘dorp’. Leden krijgen het magazine thuisbezorgd; losse nummers zijn te koop in het Historisch Huis. Artikelen uit de Heemskring van meer dan vijf jaar geleden zijn volledig te lezen in de collectie Artikelen.';

const heemskringImage =
    'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/08/Heemskringen.webp';

// ---------------------------------------------------------------------------
// Educatie (uit Lesaanbod-HKH.pdf, maart 2026)
// ---------------------------------------------------------------------------

const educationIntro =
    'De Historische Kring Heemskerk (HKH) biedt een gevarieerd educatief programma voor het basisonderwijs. De activiteiten sluiten expliciet aan bij de kerndoelen voor Oriëntatie op jezelf en de wereld (met name tijd, plaats, cultuur en erfgoed), Burgerschap en Kunstzinnige oriëntatie. Het aanbod draagt bij aan betekenisvol onderwijs vanuit de eigen leefomgeving.';

const educationBrochureUrl =
    'https://www.historischekringheemskerk.nl/wp-content/uploads/2026/03/Lesaanbod-HKH.pdf';

const educationItems = [
  EducationItem(
    slug: 'rondleidingen-kastelen',
    title: 'Rondleidingen kastelen Assumburg en Marquette',
    kind: 'Rondleiding',
    groups: 'Alle groepen',
    description:
        'Leerlingen maken kennis met de geschiedenis van Heemskerk aan de hand van een rondleiding door kasteel Assumburg en/of kasteel Marquette.',
    goals: [
      'Oriëntatie op jezelf en de wereld – Tijd: kennismaken met het verleden van de eigen omgeving',
      'Oriëntatie op jezelf en de wereld – Cultuur en erfgoed',
      'Burgerschap: bewustwording van lokaal cultureel erfgoed',
    ],
    duration:
        'De duur van de activiteit is een uur. De voorbereidingstijd is afhankelijk van de interesse in het onderwerp maar minimaal een uur.',
    cost: '€ 45 per groep van 20 kinderen',
    organisation:
        'De rondleidingen worden gecoördineerd door Piet van Zwieten (vrijwilliger HKH), die tevens de praktische afspraken verzorgt.',
    registration: 'Op aanvraag.',
    image:
        'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/11/Kasteel-Assumburg-20947-1024x1024.webp',
  ),
  EducationItem(
    slug: 'heemskerk-in-oorlogstijd',
    title: 'Presentatie: Heemskerk in oorlogstijd (1940–1945)',
    kind: 'Presentatie',
    groups: 'Groep 8',
    description:
        'Interactieve presentatie over het leven in Heemskerk tijdens de Tweede Wereldoorlog, aangepast aan het niveau van de leerlingen.',
    goals: [
      'Oriëntatie op jezelf en de wereld – Tijd: de Tweede Wereldoorlog in nationaal en lokaal perspectief',
      'Burgerschap: vrijheid, democratie, omgaan met verschillen',
      'Sociaal-emotionele ontwikkeling: reflecteren op keuzes en gevolgen',
    ],
    duration:
        'De duur van de activiteit is een uur. De voorbereidingstijd is afhankelijk van de interesse in het onderwerp maar minimaal een uur.',
    cost: 'Aan deze activiteit zijn geen kosten verbonden.',
    organisation: 'Gecoördineerd door Wim Smeels (vrijwilliger HKH).',
    registration:
        'Deze activiteit is bekend bij een aantal scholen. Alle scholen ontvangen jaarlijks een uitnodiging.',
    image:
        'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/11/Luchtfoto-Heemskerk-Oud-10291-1024x1024.webp',
  ),
  EducationItem(
    slug: 'historische-wandelingen',
    title: 'Historische wandelingen rondom scholen',
    kind: 'Wandeling',
    groups: 'Groep 7 en 8',
    description:
        'Historische wandelingen in de directe omgeving van de school, gericht op lokale geschiedenis en herkenbare plekken.',
    goals: [
      'Oriëntatie op jezelf en de wereld – Plaats: leren over de eigen leefomgeving en kaartvaardigheden',
      'Oriëntatie op jezelf en de wereld – Tijd: veranderingen in de omgeving door de tijd heen',
      'Bewegingsonderwijs / actief leren: leren buiten het klaslokaal',
    ],
    duration: 'De duur van de activiteit is 2 uur inclusief voorbereiding.',
    cost: 'Aan deze activiteit zijn geen kosten verbonden.',
    organisation:
        'Het is de bedoeling dat scholen deze activiteit zelfstandig uitvoeren.',
    status:
        'Bestaande wandelingen worden opnieuw bekeken en beoordeeld. Een pilotwandeling (geschikt voor Zevenhoeven en Otterkolken) is gereed.',
    actionLabel: 'Materiaal aanvragen',
    image:
        'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/11/header-hkh-beelden-vierkant-mariaschool-1280x1280-1-1024x1024.jpg',
  ),
  EducationItem(
    slug: 'beroemd-als-maerten',
    title: 'Lesprogramma ‘Beroemd als Maerten’',
    kind: 'Lesprogramma',
    groups: 'Groep 7 en 8',
    description:
        'Dit lesprogramma behandelt het leven van Maerten van Heemskerck aan de hand van filmbeelden en een korte dorpswandeling langs locaties die naar hem verwijzen.',
    goals: [
      'Oriëntatie op jezelf en de wereld – Tijd: historische personen uit de eigen regio',
      'Kunstzinnige oriëntatie: kennismaken met beeldende kunst en cultureel erfgoed',
      'Taal: luisteren, spreken en reflecteren',
    ],
    duration:
        'De duur van de activiteit is een uur. De voorbereidingstijd is afhankelijk van de interesse in het onderwerp maar minimaal een uur.',
    cost: '€ 65 per groep',
    registration: 'Via Cultuurhuis Heemskerk.',
    image:
        'https://www.historischekringheemskerk.nl/wp-content/uploads/2025/07/Maerten-1.png',
  ),
  EducationItem(
    slug: 'workshops',
    title: 'Workshops: monumentenkist, archeologie, familiegeschiedenis',
    kind: 'Workshops',
    groups: 'Nog te bepalen',
    description:
        'Onderzoekend en ontdekkend leren met echte voorwerpen en bronnen. Het is de bedoeling dat scholen deze activiteiten zelfstandig uitvoeren.',
    goals: [
      'Oriëntatie op jezelf en de wereld – Tijd en Cultuur',
      'Onderzoekend en ontdekkend leren',
      '21e-eeuwse vaardigheden: vragen stellen, bronnen gebruiken en verbanden leggen',
    ],
    status: 'De bestaande workshops worden opnieuw bekeken en beoordeeld.',
    requestable: false,
    actionLabel: 'Houd mij op de hoogte',
    image:
        'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/11/53A14005-e1753361555462.jpg',
  ),
  EducationItem(
    slug: 'verjaardag-van-maerten',
    title: 'Jaarlijkse activiteit rond de geboortedag van Maerten van Heemskerck',
    kind: 'Jaarlijks · rond 1 juli',
    groups: 'Nog te bepalen',
    description:
        'Een kerngroep Maerten van Heemskerck werkt aan een doorlopende jaarlijkse activiteit om Maerten blijvend onder de aandacht te brengen binnen Heemskerk. Voorbeeldinvulling: een tentoonstelling zoals ‘De Maertens van Heemskerck’, met tekeningen en schilderingen van leerlingen rond een gekozen thema. De werken kunnen worden gepresenteerd en tentoongesteld rondom de jaarlijkse activiteit.',
    goals: [
      'Kunstzinnige oriëntatie: creatief werken en presenteren',
      'Oriëntatie op jezelf en de wereld – Cultuur en erfgoed',
      'Burgerschap: samenwerken en deelnemen aan culturele activiteiten',
    ],
    requestable: false,
    actionLabel: 'Meedoen met uw school',
    image:
        'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/11/Standbeeld-Maerten-van-Heemskerck-10304.webp',
  ),
];

// ---------------------------------------------------------------------------
// Homepage
// ---------------------------------------------------------------------------

/// Foto's in de strook bovenaan de homepage (van de oude site).
const homeHeroImages = [
  'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/11/Luchtfoto-Heemskerk-Oud-10291-1024x1024.webp',
  'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/11/Kasteel-Assumburg-20947-1024x1024.webp',
  'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/11/Standbeeld-Maerten-van-Heemskerck-10304.webp',
  'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/11/Chateau-Marquette-15533.webp',
  'https://www.historischekringheemskerk.nl/wp-content/uploads/2024/11/header-hkh-beelden-vierkant-mariaschool-1280x1280-1-1024x1024.jpg',
];

/// Uitgelichte verhalen op de homepage: pagina-slug en rubriek.
const homeFeaturedStories = [
  (pageSlug: 'alle-kastelen-op-de-kaart', category: 'Kastelen'),
  (pageSlug: 'maerten-van-heemskerck', category: 'Personen'),
  (pageSlug: 'heemskerker-ezels', category: 'Verhalen en herinneringen'),
];

// ---------------------------------------------------------------------------
// Hulpfuncties over de vaste inhoud
// ---------------------------------------------------------------------------

ContentPage? pageBySlug(String slug) {
  for (final page in generatedPages) {
    if (page.slug == slug) return page;
  }
  return null;
}

Activity? activityBySlug(String slug) {
  for (final activity in generatedActivities) {
    if (activity.slug == slug) return activity;
  }
  return null;
}

NewsPost? newsBySlug(String slug) {
  for (final post in generatedNews) {
    if (post.slug == slug) return post;
  }
  return null;
}

EducationItem? educationBySlug(String slug) {
  for (final item in educationItems) {
    if (item.slug == slug) return item;
  }
  return null;
}

StoryCategory? storyCategoryBySlug(String slug) {
  for (final category in storyCategories) {
    if (category.slug == slug) return category;
  }
  return null;
}

/// Rubriek waarin een pagina staat, of null.
StoryCategory? storyCategoryOfPage(String pageSlug) {
  for (final category in storyCategories) {
    if (category.pageSlugs.contains(pageSlug)) return category;
  }
  return null;
}

/// Komende activiteiten, eerstvolgende eerst.
List<Activity> upcomingActivities(DateTime now) =>
    generatedActivities.where((a) => a.isUpcoming(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

/// Afgelopen activiteiten, meest recente eerst.
List<Activity> pastActivities(DateTime now) =>
    generatedActivities.where((a) => !a.isUpcoming(now)).toList()
      ..sort((a, b) => b.start.compareTo(a.start));

/// Berichten, nieuwste eerst.
List<NewsPost> get newsPosts =>
    [...generatedNews]..sort((a, b) => b.published.compareTo(a.published));

/// Zet een link van de oude site om naar een route in deze app, of null als
/// de link extern blijft.
String? internalRouteFor(String href) {
  final uri = Uri.tryParse(href);
  if (uri == null) return null;
  if (uri.host.isNotEmpty && !uri.host.endsWith('historischekringheemskerk.nl')) {
    return null;
  }
  if (uri.path.startsWith('/cgi-bin/')) {
    final collection = switch (uri.path) {
      '/cgi-bin/archief.pl' => 'archief',
      '/cgi-bin/beeldbank.pl' => 'beeldbank',
      '/cgi-bin/library.pl' => 'bibliotheek',
      '/cgi-bin/bidprent.pl' => 'bidprentjes',
      '/cgi-bin/artikelen.pl' => 'artikelen',
      '/cgi-bin/objecten.pl' => 'objecten',
      _ => null,
    };
    if (collection == null) return null;
    final search = uri.queryParameters['search'];
    return Uri(
      path: '/zoeken',
      queryParameters: {
        'collection': collection,
        if (search != null && search.isNotEmpty) 'q': search,
      },
    ).toString();
  }
  if (uri.path.startsWith('/Geheugen')) return '/geheugen';
  final slug = uri.path.replaceAll(RegExp(r'^/|/$'), '');
  if (slug.isEmpty) return '/';
  if (slug == 'evenementen') return '/agenda';
  if (slug.startsWith('evenement/')) return '/agenda/${slug.substring(10)}';
  if (slug == 'alle-berichten-van-historische-kring-heemskerk') return '/nieuws';
  if (slug == 'hkh-nieuwsbrieven') return '/nieuws/nieuwsbrieven';
  if (slug == 'hkh-producten' || slug.startsWith('hkh-product')) {
    return '/vereniging/uitgaven';
  }
  if (slug == 'lid-worden-van-de-historische-kring-heemskerk') return '/lid-worden';
  if (slug == 'hkh-bestuursleden') return '/vereniging/bestuur';
  if (slug == 'werkgroepen') return '/vereniging/werkgroepen';
  if (slug == 'openstelling-historisch-huis' || slug == 'historisch-huis') {
    return '/vereniging/historisch-huis';
  }
  if (slug == 'heemsstichting') return '/vereniging/heemsstichting';
  if (slug == 'over-historische-kring-heemskerk') return '/vereniging/over-de-hkh';
  if (slug == 'links') return '/vereniging/links';
  if (slug == 'contact-formulier') return '/vereniging/contact';
  if (documentPageSlugs.contains(slug) || slug == 'juridische-disclaimer-2') {
    return '/vereniging/anbi';
  }
  if (newsBySlug(slug) != null) return '/nieuws/$slug';
  if (pageBySlug(slug) != null) return '/ontdek/$slug';
  return null;
}
