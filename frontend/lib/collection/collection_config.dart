import 'package:flutter/material.dart';

class CollectionConfig {
  const CollectionConfig(
    this.key,
    this.label,
    this.icon,
    this.number,
    this.facets,
    this.fields,
    this.detailFields,
  );
  final String key, label, number;
  final IconData icon;
  final List<String> facets, detailFields;
  final Map<String, String> fields;
  bool get gallery => key == 'beeldbank' || key == 'objecten';
  String get periodLabel => key == 'bidprent'
      ? 'Geboorteperiode'
      : (key == 'library' || key == 'artikelen')
      ? 'Verschijningsjaar'
      : 'Periode / jaar';
  String get detailsLabel => switch (key) {
    'bidprent' => 'Persoonsgegevens',
    'library' => 'Boekgegevens',
    'objecten' => 'Objectgegevens',
    _ => 'Gegevens',
  };
}

const collectionConfigs = [
  CollectionConfig(
    'archief',
    'Archief',
    Icons.inventory_2_outlined,
    'Documentnummer',
    ['Type publicatie', 'Thema', 'Auteur(s)', 'Uitgever'],
    {
      'ident': 'Documentnummer',
      'title_description': 'Titel + Omschrijving',
      'Oorspronkelijk archief': 'Oorspronkelijk archief',
      'Plaats': 'Plaats',
      'Auteur(s)': 'Auteur(s)',
      'Uitgever': 'Uitgever',
    },
    [
      'Type publicatie',
      'Thema',
      'Auteur(s)',
      'Uitgever',
      'Plaats',
      'Oorspronkelijk archief',
    ],
  ),
  CollectionConfig(
    'beeldbank',
    'Beeldbank',
    Icons.photo_outlined,
    'Object nr.',
    [
      'Thema',
      'Wijk in Heemskerk',
      'Straatnaam',
      'Fotograaf',
      'Uit Map of Album',
    ],
    {
      'ident': 'Object nr.',
      'title_description': 'Titel + Beschrijving',
      'Straatnaam': 'Straatnaam',
      'Uit Map of Album': 'Uit Map of Album',
      'Fotograaf': 'Fotograaf',
      'Wijk in Heemskerk': 'Wijk in Heemskerk',
      'Thema': 'Thema',
    },
    [
      'Straatnaam',
      'Wijk in Heemskerk',
      'Fotograaf',
      'Thema',
      'Uit Map of Album',
    ],
  ),
  CollectionConfig(
    'library',
    'Bibliotheek',
    Icons.menu_book_outlined,
    'Boeknummer',
    ['Genre', 'Medium', 'Auteur(s)'],
    {'ident': 'Boeknummer', 'Auteur(s)': 'Auteur(s)'},
    [
      'Auteur(s)',
      'Verschijningsjaar',
      'Genre',
      'Medium',
      'Uitgever',
      'Aantal pagina’s',
      'Aantal pagina\'s',
      'ISBN',
    ],
  ),
  CollectionConfig(
    'bidprent',
    'Bidprentjes',
    Icons.contact_page_outlined,
    'Volgnummer',
    ['Geboren te', 'Overleden te', 'Leeftijd'],
    {
      'ident': 'Volgnummer',
      'name_place': 'Achternaam overledene + Geboren te',
      'Voornaam': 'Voornaam',
      'Achternaam overledene': 'Achternaam overledene',
      'Geboren op': 'Geboren op',
      'Geboren te': 'Geboren te',
      'Overleden op': 'Overleden op',
      'Overleden te': 'Overleden te',
      'Achternaam echtgeno(o)t(e)': 'Achternaam echtgeno(o)t(e)',
      'Crematorium of laatste rustplaats': 'Crematorium of laatste rustplaats',
      'Leeftijd': 'Leeftijd',
      'Bijzonderheden': 'Bijzonderheden',
    },
    [
      'Voornaam',
      'Achternaam overledene',
      'Geboren op',
      'Geboren te',
      'Overleden op',
      'Overleden te',
      'Leeftijd',
      'Achternaam echtgeno(o)t(e)',
      'Crematorium of laatste rustplaats',
      'Bijzonderheden',
    ],
  ),
  CollectionConfig(
    'artikelen',
    'Artikelen',
    Icons.article_outlined,
    'Artikelnummer',
    ['Rubriek', 'Auteur(s)', 'Medium'],
    {
      'ident': 'Artikelnummer',
      'title_description': 'Titel artikel + Beschrijving',
      'Auteur(s)': 'Auteur(s)',
    },
    [
      'Auteur(s)',
      'Rubriek',
      'Verschijningsjaar',
      'Medium',
      'Uitgave',
      'Pagina’s',
      'Pagina\'s',
      'Paginanummer',
    ],
  ),
  CollectionConfig(
    'objecten',
    'Objecten',
    Icons.category_outlined,
    'Objectnummer',
    ['Thema object', 'Materiaal'],
    {
      'ident': 'Objectnummer',
      'title_description': 'Titel + Beschrijving',
      'Thema object': 'Thema object',
      'Materiaal': 'Materiaal',
    },
    [
      'Thema object',
      'Materiaal',
      'Afmetingen',
      'Vervaardiger',
      'Herkomst',
      'Datering',
    ],
  ),
];

CollectionConfig collectionConfig(String? key) =>
    collectionConfigs.where((c) => c.key == key).firstOrNull ??
    CollectionConfig(
      key ?? '',
      key == null
          ? 'Alle collecties'
          : key == 'transcripties'
          ? 'Transcripties'
          : key,
      Icons.collections_bookmark_outlined,
      'Collectienummer',
      const [],
      const {'ident': 'Collectienummer'},
      const [],
    );

Map<String, String> searchFields(String? collection) => {
  'all': 'Alle velden',
  'title': 'Titel',
  'description': 'Beschrijving',
  ...collectionConfig(collection).fields,
  for (final field in collectionConfig(collection).facets) field: field,
};

String itemMetadata(String collection, int? year, Map<String, String> fields) {
  final keys = switch (collection) {
    'beeldbank' => ['Straatnaam', 'Fotograaf'],
    'library' => ['Auteur(s)', 'Medium'],
    'bidprent' => ['Geboren op', 'Overleden op', 'Geboren te'],
    'artikelen' => ['Auteur(s)', 'Medium', 'Uitgave'],
    'objecten' => ['Materiaal', 'Afmetingen'],
    _ => ['Type publicatie', 'Uitgever'],
  };
  return [
    for (final k in keys)
      if (fields[k]?.trim().isNotEmpty == true)
        '${collection == 'bidprent' && k == 'Geboren op'
            ? 'Geboren: '
            : collection == 'bidprent' && k == 'Overleden op'
            ? 'Overleden: '
            : ''}${fields[k]}',
    if (year != null && collection != 'bidprent') '$year',
  ].join(' · ');
}

const documentFieldNames = [
  'OCR-tekst',
  'OCR tekst',
  'OCR',
  'Documenttekst',
  'Tekst publicatie',
];

String collectionTitle(
  String title,
  String collection,
  Map<String, String> fields,
) {
  if (title.trim().isNotEmpty) return title;
  if (collection == 'bidprent') {
    final name = [
      fields['Voornamen'] ??
          fields['Voornaam'] ??
          fields['Voornaam overledene'],
      fields['Achternaam overledene'],
    ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' ');
    if (name.isNotEmpty) return name;
  }
  return '(zonder titel)';
}
