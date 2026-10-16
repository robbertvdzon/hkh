"""Zet voorstel-ai-zoeken.md om in voorstel-ai-zoeken.html en .pdf.

Gebruik:  python3 md2pdf.py
Ondersteunde markdown: # ## ### koppen, alinea's, - lijsten, 1. lijsten,
> citaten, | tabellen |, ![bijschrift](bestand), **vet**, *cursief*.
De eerste kop en de alinea's tot de eerste ## vormen de omslag; een ###-blok
wordt een gekleurd kader.
"""
import html
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'voorstel-ai-zoeken.md')
OUT_HTML = os.path.join(HERE, 'voorstel-ai-zoeken.html')
OUT_PDF = os.path.join(HERE, 'voorstel-ai-zoeken.pdf')
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

CSS = """
  @page { size: A4; margin: 18mm 18mm 20mm 18mm; }
  * { box-sizing: border-box; }
  :root { --green: #1f3b2e; --dark: #16302a; --sage: #dce9da; --sand: #f0e6d2; --muted: #5a6a5c; --line: #d9cfbb; }
  html, body { margin: 0; padding: 0; }
  body { font-family: "Helvetica Neue", Arial, sans-serif; font-size: 11.5pt; line-height: 1.5; color: #1d2320; }
  h1, h2, h3 { font-family: Georgia, "Times New Roman", serif; font-weight: normal; color: var(--green); margin: 0; }
  h2 { font-size: 17pt; margin: 0 0 8pt; padding-bottom: 4pt; border-bottom: 1.5px solid var(--line); page-break-after: avoid; }
  h3 { font-size: 13pt; margin: 0 0 4pt; }
  p { margin: 0 0 8pt; }
  ul, ol { margin: 0 0 8pt 18pt; padding: 0; }
  li { margin-bottom: 4pt; }
  section { page-break-before: always; }
  section:first-of-type { page-break-before: auto; }
  .pair { display: flex; gap: 6mm; margin: 8pt 0 10pt; page-break-inside: avoid; }
  .pair figure { flex: 1; margin: 0; }
  .pair figure img { max-height: 120mm; }
  .cover { background: var(--dark); color: #fff; padding: 16mm 14mm; margin: 0 0 10mm 0; border-radius: 6pt; }
  .cover h1 { color: #fff; font-size: 30pt; line-height: 1.2; max-width: 150mm; }
  .cover p { font-size: 13pt; opacity: .9; margin: 8pt 0 0; max-width: 150mm; }
  .cover p.meta { font-size: 10.5pt; opacity: .8; letter-spacing: 1px; text-transform: uppercase; margin-top: 18pt; }
  .logo { font-family: Georgia, serif; font-size: 34pt; letter-spacing: 2px; border-bottom: 3px solid #fff; display: inline-block; line-height: 1; margin-bottom: 14pt; }
  .box { background: var(--sage); border-radius: 8pt; padding: 10pt 12pt; margin: 8pt 0 12pt; page-break-inside: avoid; }
  .box p:last-child, .box ul:last-child { margin-bottom: 0; }
  figure { margin: 8pt 0 10pt; page-break-inside: avoid; }
  figure img { max-width: 100%; max-height: 190mm; border: 1px solid var(--line); border-radius: 4pt; display: block; margin: 0 auto; }
  figcaption { font-size: 9.5pt; color: var(--muted); margin-top: 3pt; }
  blockquote { border: 1px solid var(--line); border-radius: 8pt; padding: 10pt 12pt; margin: 8pt 0 10pt; background: #fff; font-size: 10.5pt; }
  blockquote p { margin-bottom: 6pt; }
  table { border-collapse: collapse; width: 100%; margin: 6pt 0 10pt; font-size: 11pt; page-break-inside: avoid; }
  th, td { text-align: left; padding: 6pt 8pt; border-bottom: 1px solid var(--line); vertical-align: top; }
  th { background: var(--sage); color: var(--green); font-weight: 600; }
  td.num, th.num { text-align: right; white-space: nowrap; }
  a { color: var(--green); }
"""


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)
    text = re.sub(r'(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)', r'<i>\1</i>', text)
    text = re.sub(r'(https?://[^\s)]+?)([.,;:]?(?=\s|$))', r'<a href="\1">\1</a>\2', text)
    return text


def render_blocks(lines):
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        m = re.match(r'^!\[(.*?)\]\((.*?)\)\s*$', line)
        if m:
            # Opeenvolgende afbeeldingen (alleen lege regels ertussen) komen naast elkaar.
            figures = []
            j = i
            while j < len(lines):
                mm = re.match(r'^!\[(.*?)\]\((.*?)\)\s*$', lines[j])
                if mm:
                    cap, src = mm.groups()
                    figures.append(f'<figure><img src="{html.escape(src)}" alt="{html.escape(cap)}">'
                                   + (f'<figcaption>{inline(cap)}</figcaption>' if cap else '') + '</figure>')
                    j += 1
                elif not lines[j].strip() and j + 1 < len(lines) and re.match(r'^!\[', lines[j + 1]):
                    j += 1
                else:
                    break
            if len(figures) > 1:
                out.append('<div class="pair">' + ''.join(figures) + '</div>')
            else:
                out.append(figures[0])
            i = j
            continue
        if line.startswith('### '):
            # kader tot de volgende kop of de volgende lege regel na een alinea-blok
            j = i + 1
            while j < len(lines) and not lines[j].startswith('#'):
                j += 1
            body = render_blocks(lines[i + 1:j])
            out.append(f'<div class="box"><h3>{inline(line[4:].strip())}</h3>{body}</div>')
            i = j
            continue
        if line.startswith('> '):
            j = i
            quote = []
            while j < len(lines) and (lines[j].startswith('>') or not lines[j].strip() and j + 1 < len(lines) and lines[j + 1].startswith('>')):
                quote.append(re.sub(r'^>\s?', '', lines[j]))
                j += 1
            out.append('<blockquote>' + render_blocks(quote) + '</blockquote>')
            i = j
            continue
        if line.startswith('|'):
            j = i
            rows = []
            while j < len(lines) and lines[j].startswith('|'):
                rows.append([c.strip() for c in lines[j].strip().strip('|').split('|')])
                j += 1
            rows = [r for r in rows if not all(re.match(r'^:?-+:?$', c) for c in r)]
            head, body = rows[0], rows[1:]
            def cell(tag, c, k):
                num = ' class="num"' if k > 0 else ''
                return f'<{tag}{num}>{inline(c)}</{tag}>'
            t = '<table><tr>' + ''.join(cell('th', c, k) for k, c in enumerate(head)) + '</tr>'
            for r in body:
                t += '<tr>' + ''.join(cell('td', c, k) for k, c in enumerate(r)) + '</tr>'
            out.append(t + '</table>')
            i = j
            continue
        if re.match(r'^(-|\d+\.) ', line):
            ordered = line[0].isdigit()
            j = i
            items = []
            while j < len(lines) and re.match(r'^(-|\d+\.) ', lines[j]):
                items.append(re.sub(r'^(-|\d+\.) ', '', lines[j]))
                j += 1
            tag = 'ol' if ordered else 'ul'
            out.append(f'<{tag}>' + ''.join(f'<li>{inline(x)}</li>' for x in items) + f'</{tag}>')
            i = j
            continue
        # alinea: regels tot een lege regel
        j = i
        para = []
        while j < len(lines) and lines[j].strip() and not re.match(r'^(#|!\[|>|\||- |\d+\. )', lines[j]):
            para.append(lines[j].strip())
            j += 1
        out.append(f'<p>{inline(" ".join(para))}</p>')
        i = j
    return ''.join(out)


def convert(md):
    lines = md.splitlines()
    # omslag: eerste H1 en alles tot de eerste H2
    first_h2 = next(k for k, l in enumerate(lines) if l.startswith('## '))
    title = next(l[2:].strip() for l in lines[:first_h2] if l.startswith('# '))
    cover_paras = [l.strip() for l in lines[:first_h2] if l.strip() and not l.startswith('# ')]
    cover = '<div class="cover"><div class="logo">HKH</div>' + f'<h1>{inline(title)}</h1>'
    for k, ptext in enumerate(cover_paras):
        cls = ' class="meta"' if k == len(cover_paras) - 1 and len(cover_paras) > 1 else ''
        cover += f'<p{cls}>{inline(ptext)}</p>'
    cover += '</div>'
    # secties per H2
    sections = []
    idx = [k for k, l in enumerate(lines) if l.startswith('## ')] + [len(lines)]
    for a, b in zip(idx, idx[1:]):
        heading = lines[a][3:].strip().rstrip(':')
        sections.append(f'<h2>{inline(heading)}</h2>' + render_blocks(lines[a + 1:b]))
    body = '<section>' + cover + sections[0] + '</section>'
    for s in sections[1:]:
        body += '<section>' + s + '</section>'
    return f'<!doctype html><html lang="nl"><head><meta charset="utf-8"><title>{html.escape(title)}</title><style>{CSS}</style></head><body>{body}</body></html>'


if __name__ == '__main__':
    out = convert(open(SRC, encoding='utf-8').read())
    open(OUT_HTML, 'w', encoding='utf-8').write(out)
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--no-pdf-header-footer',
                    f'--print-to-pdf={OUT_PDF}', f'file://{OUT_HTML}'],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print('geschreven:', OUT_HTML, OUT_PDF)
