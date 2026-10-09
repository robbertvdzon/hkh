"""Genereert frontend/lib/content/generated_memory.dart uit geheugen.json."""
import json, re, sys, unicodedata

OUT = sys.argv[1]
data = json.load(open('geheugen.json'))


def d(s):
    s = s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n')
    return "'" + s + "'"


def slugify(title, href):
    base = unicodedata.normalize('NFKD', title).encode('ascii', 'ignore').decode()
    base = re.sub(r'[^a-zA-Z0-9]+', '-', base).strip('-').lower()[:50].strip('-')
    ident = re.search(r'article-1036\.(\d+)', href).group(1)
    return f'{base}-{ident}' if base else ident


stories = data['stories']
slug_by_href = {s['href']: slugify(s['title'], s['href']) for s in stories}
entries = []
for s in stories:
    related = [slug_by_href[r['href']] for r in s.get('related', []) if r['href'] in slug_by_href]
    related = [r for r in dict.fromkeys(related) if r != slug_by_href[s['href']]]
    figs = ', '.join(
        f"MemoryFigure({d(f['src'])}{', caption: ' + d(f['caption']) if f['caption'] else ''}{', alt: ' + d(f['alt']) if f.get('alt') and f['alt'] != f['caption'] else ''})"
        for f in s['figures'])
    entries.append(f"""  MemoryStory(
    slug: {d(slug_by_href[s['href']])},
    title: {d(s['title'])},
    narrator: {d(s['narrator'])},
    author: {d(s['author'])},
    theme: {d(s['theme'])},
    neighbourhood: {d(s['neighbourhood'])},
    period: {d(s['period'])},
    intro: [{', '.join(d(p) for p in s['intro'])}],
    body: [{', '.join(d(p) for p in s['body'])}],
    figures: [{figs}],
    relatedSlugs: [{', '.join(d(r) for r in related)}],
  ),""")

about = data['about']
about_paragraphs = about['intro'] + about['body']
out = f"""// GEGENEREERD BESTAND: niet met de hand bewerken.
//
// De verhalen van het Geheugen van Heemskerk, overgenomen van
// https://www.historischekringheemskerk.nl/Geheugen/ op 9 oktober 2026 met
// docs/website-vernieuwing/scripts/extract_geheugen.py en generate_memory_dart.py.
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'content_models.dart';

/// Alle verhalen, in de volgorde van de oude index.
const List<MemoryStory> generatedMemoryStories = [
{chr(10).join(entries)}
];

/// De tekst van de pagina 'Over de site' van het oude Geheugen.
const List<String> generatedMemoryAbout = [
{chr(10).join('  ' + d(p) + ',' for p in about_paragraphs)}
];
"""
open(OUT, 'w').write(out)
print('stories', len(entries), 'about', len(about_paragraphs))
