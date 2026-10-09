"""Genereert frontend/lib/content/generated_content.dart uit content.json en bestuur.json."""
import json, re, sys, html

OUT = sys.argv[1]
base = 'https://www.historischekringheemskerk.nl'
recs = json.load(open('content.json'))
board = json.load(open('bestuur.json'))

POSTS = {
    'vernieuwde-website-historische-kring-heemskerk', 'naar-school-in-heemskerk',
    'het-verhaal-rond-de-kruisberg', 'burgemeester-nielen-en-gemeentehuizen', 'raad-je-straat',
    'korte-film-over-arfa', 'de-tien-kastelen-van-heemskerk', 'raad-je-straat-2',
    'tentoonstelling-heemskerk-en-de-tweede-wereldoorlog', 'films-over-de-hoogovens',
    'fotowandeling-hkh-langs-de-grenzen-van-heemskerk', 'de-verjaardag-van-maerten',
    'wateratlas-van-noord-holland', 'etalage-kunstroute', 'het-verhaal-van-neeltje-snijders',
}
SKIP = {
    '', 'alle-berichten-van-historische-kring-heemskerk', 'evenementen', 'hkh-producten',
    'hkh-nieuwsbrieven', 'contact-formulier', 'juridische-disclaimer-2', 'scholen-uit-collecties',
    'test-evenementen-loop', 'lid-worden-van-de-historische-kring-heemskerk', 'hkh-bestuursleden',
}
PARTNER_EVENTS = {
    'het-zwijgende-landschap', 'in-de-voetsporen-van-de-romeinen', 'ommetje-bakkum',
    'ommetje-westerhout-tussen-aardbeien-en-staal', 'oertoer-2026', 'feestweek-heemskerk',
}
# Voorbeeldwaarden voor de inschrijfstatus van komende activiteiten (fase 1).
REGISTRATION = {
    'de-zoektocht-in-het-noorderveld': dict(capacity=25, registered=25, waitlist=3),
    'lezing-het-palmhoutwrak': dict(externalUrl='https://obijmond.op-shop.nl/1368/ontdek-het-palmhoutwrak/20-10-2026', externalLabel='Aanmelden via Bibliotheek IJmond'),
    'lezing-over-cornelis-corneliszoon': dict(capacity=25, registered=21),
    'piet-paree-de-terugkeer-van-een-kanaalgraver': dict(capacity=60, registered=22),
    'de-museumschuur-van-piet-diemeer': None,
}
GALLERIES = {
    'expositie-deutzstraat': [f'{base}/wp-content/uploads/2024/11/Deutzstraat-kapper-bekker-{n}.jpg' for n in
        [221,211,201,191,181,171,161,151,141,131,121,111,110,101,91,81,71,61,51,41,31,23]],
}
PRICES = {
    'piet-paree-de-terugkeer-van-een-kanaalgraver': '€ 5,00 · leden € 3,50',
    'lezing-het-palmhoutwrak': 'Leden € 5,00 · niet-leden € 7,50',
    'in-de-voetsporen-van-de-romeinen': '€ 8,50',
}


def d(s):
    """Dart-string (enkele aanhalingstekens)."""
    s = s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n')
    return "'" + s + "'"


def clean(t):
    t = html.unescape(t).replace('\xa0', ' ')
    return re.sub(r'\s+', ' ', t).strip()


def blocks_dart(blocks, indent='      '):
    out = []
    for b in blocks:
        if b['type'] == 'heading':
            out.append(f"{indent}HeadingBlock({d(clean(b['text']))}, level: {b['level']}),")
        elif b['type'] == 'paragraph':
            text = clean(b['text'])
            if not text:
                continue
            links = [l for l in b.get('links', []) if l.get('text') and l['text'] in text]
            parts = [d(text)]
            if links:
                ls = ', '.join(f"ContentLink({d(clean(l['text']))}, {d(absolute(l['href']))})" for l in links)
                parts.append(f'links: [{ls}]')
            if b.get('strong'):
                parts.append('strong: true')
            out.append(f"{indent}ParagraphBlock({', '.join(parts)}),")
        elif b['type'] == 'image':
            cap = clean(b.get('caption', ''))
            alt = clean(b.get('alt', ''))
            extra = ''
            if cap:
                extra += f', caption: {d(cap)}'
            if alt and alt != cap:
                extra += f', alt: {d(alt)}'
            out.append(f"{indent}ImageBlock({d(b['src'])}{extra}),")
        elif b['type'] == 'list':
            items = ', '.join(d(clean(i)) for i in b['items'])
            ordered = ', ordered: true' if b.get('ordered') else ''
            out.append(f"{indent}ListBlock([{items}]{ordered}),")
    return '\n'.join(out)


def absolute(href):
    href = html.unescape(href)
    if href.startswith('/'):
        return base + href
    return href


KIND_OVERRIDES = {'de-zoektocht-in-het-noorderveld': 'overig', 'bezoek-aan-de-laurentiuskerk-en-begraafplaats': 'wandeling'}


def kind_for(slug, title):
    if slug in KIND_OVERRIDES:
        return KIND_OVERRIDES[slug]
    t = (slug + ' ' + title).lower()
    if 'lezing' in t or 'palmhoutwrak' in t:
        return 'lezing'
    if 'film' in t or 'burgemeester-nielen' in t:
        return 'film'
    if 'wandeling' in t or 'ommetje' in t or 'oertoer' in t or 'zoektocht' in t or 'bezoek-aan' in t or 'voetsporen' in t or 'landschap' in t:
        return 'wandeling'
    if 'tentoonstelling' in t or 'expositie' in t or 'museumschuur' in t:
        return 'expositie'
    return 'overig'


def venue_split(v):
    v = clean(v)
    v = re.sub(r'\s*\+ Google Maps.*$', '', v)
    v = re.sub(r'\s*Bekijk de site.*$', '', v)
    v = re.sub(r'\s*\d{10}\s*$', '', v)
    for name in ['Historisch Huis HKH', 'Bibliotheek Beverwijk', 'Gemeentehuis Heemskerk']:
        if v.startswith(name):
            return name, clean(v[len(name):].strip(' ,'))
    parts = v.split(' ', 1)
    m = re.match(r'^(.*?)(\s[A-Z]?[a-z]*\.?\s?[A-Z][\w\.]*(straat|weg|plein|laan)\b.*)$', v)
    if m:
        return clean(m.group(1)), clean(m.group(2))
    return v, ''


def dt(iso):
    # 2026-10-20T19:30:00+02:00 -> DateTime(2026, 10, 20, 19, 30)
    m = re.match(r'(\d+)-(\d+)-(\d+)T(\d+):(\d+)', iso)
    y, mo, da, h, mi = (int(x) for x in m.groups())
    return f'DateTime({y}, {mo}, {da}, {h}, {mi})'


pages, activities, news, pubs = [], [], [], []
for r in recs:
    slug = r['slug']
    if slug in SKIP or slug.startswith('hkh-nieuwsbrief/') or slug.startswith('nav-'):
        continue
    title = clean(r['title'])
    img = r.get('image')
    img_dart = f"\n      image: {d(img)}," if img else ''
    if slug.startswith('evenement/'):
        s = slug.split('/', 1)[1]
        venue_name, venue_addr = venue_split(r.get('venue', ''))
        org = clean(re.sub(r'^Organisator\s*', '', r.get('organizer', '')))
        allday = 'T00:00' in r.get('start', '') and 'T23:59' in r.get('end', '')
        reg = REGISTRATION.get(s, 'absent')
        reg_dart = ''
        if reg == 'absent':
            # Afgelopen activiteiten: alleen vermelden dat opgeven nodig was.
            reg_dart = ''
        elif reg is None:
            reg_dart = ''
        else:
            args = []
            for k, v in reg.items():
                args.append(f'{k}: {d(v) if isinstance(v, str) else v}')
            reg_dart = f"\n      registration: ActivityRegistration({', '.join(args)}),"
        price = PRICES.get(s) or (clean(r['price']) if r.get('price') else None)
        if price and price.strip() in ('0', '0,00', ''):
            price = 'Gratis'
        if not price and ('gratis' in r.get('cost', '').lower() or 'Gratis' in r.get('body_html', '')):
            price = 'Gratis'
        activities.append(f"""  Activity(
      slug: {d(s)},
      title: {d(title)},
      start: {dt(r['start'])},
      end: {dt(r['end'])},{' allDay: true,' if allday else ''}
      kind: ActivityKind.{kind_for(s, title)},
      venueName: {d(venue_name)},
      venueAddress: {d(venue_addr)},
      organizer: {d(org)},{f' price: {d(price)},' if price else ''}{img_dart}{' partner: true,' if s in PARTNER_EVENTS else ''}{reg_dart}
      published: {d(r.get('published', ''))},
      blocks: [
{blocks_dart(r['blocks'], '        ')}
      ],
    ),""")
    elif slug.startswith('hkh-product/'):
        s = slug.split('/', 1)[1]
        pt = r.get('product_text', '')
        m1 = re.search(r'Prijs voor leden\s*(.*?)\s*Prijs voor niet-leden\s*(.*?)\s*(?:Vorige|Volgende|terug naar)', pt)
        avail = re.search(r'Verkrijgbaar bij:\s*(.*?)\s*Prijs voor leden', pt)
        desc = clean(r['blocks'][0]['text']) if r['blocks'] else ''
        cat = 'Wandelingen' if 'wandeling' in s else ("Foto's" if 'foto' in s else 'Boeken')
        pubs.append(f"""  Publication(
      slug: {d(s)},
      title: {d(title)},
      description: {d(desc)},
      category: {d(cat)},{img_dart}
      memberPrice: {d(clean(m1.group(1))) if m1 else 'null'},
      price: {d(clean(m1.group(2))) if m1 else 'null'},
      availability: {d(clean(avail.group(1))) if avail else d('Het Historisch Huis van de HKH')},
    ),""")
    elif slug in POSTS:
        pub = r.get('published', '2026-01-01T00:00')
        news.append(f"""  NewsPost(
      slug: {d(slug)},
      title: {d(title)},
      published: {dt(pub)},{img_dart}
      blocks: [
{blocks_dart(r['blocks'], '        ')}
      ],
    ),""")
    else:
        gal = GALLERIES.get(slug) or r.get('gallery') or []
        gal_dart = f"\n      gallery: [{', '.join(d(g) for g in gal)}]," if gal else ''
        pages.append(f"""  ContentPage(
      slug: {d(slug)},
      title: {d(title)},{img_dart}{gal_dart}
      published: {d(r.get('published', ''))},
      blocks: [
{blocks_dart(r['blocks'], '        ')}
      ],
    ),""")

members = []
for b in board:
    t = b['text']
    lines = [l.strip() for l in t.split('\n') if l.strip()]
    name, role = lines[0], lines[1]
    email = re.search(r'[\w.]+@historischekringheemskerk\.nl', t).group(0)
    since = re.search(r'actief sinds\n\s*(.*)', t).group(1).strip()
    bio = t.split(since, 1)[1].strip()
    bio = re.split(r'\n(?:Olga Lievers|Jan Daas|Joke Kranendonk|Piet van Zwieten|Jan Bos|Klaas Pelgrim|Nieuws)\n', bio)[0]
    bio = clean(bio.split('<div')[0])
    members.append(f"""  BoardMember(
      name: {d(name)},
      role: {d(role[0].upper() + role[1:])},
      email: {d(email)},
      since: {d(since)},
      bio: {d(bio)},
      image: {d(b['image']) if b.get('image') else 'null'},
    ),""")

out = f"""// GEGENEREERD BESTAND: niet met de hand bewerken.
//
// Inhoud overgenomen van https://www.historischekringheemskerk.nl/ op 9 oktober 2026
// met docs/website-vernieuwing (scripts extract.py en generate_dart.py).
// In fase 2 vervangt de backend deze lijsten.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'content_models.dart';

/// Alle gewone pagina's (verhalen, vereniging, documenten), op slug.
const List<ContentPage> generatedPages = [
{chr(10).join(pages)}
];

/// Alle activiteiten uit de agenda, verleden en toekomst.
final List<Activity> generatedActivities = [
{chr(10).join(activities)}
];

/// Alle berichten.
final List<NewsPost> generatedNews = [
{chr(10).join(news)}
];

/// Uitgaven in de winkel.
const List<Publication> generatedPublications = [
{chr(10).join(pubs)}
];

/// Bestuursleden.
const List<BoardMember> generatedBoard = [
{chr(10).join(members)}
];
"""
open(OUT, 'w').write(out)
print(f'pages={len(pages)} activities={len(activities)} news={len(news)} pubs={len(pubs)} board={len(members)}')
