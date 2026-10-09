"""Haalt de verhalen van het Geheugen van Heemskerk op (index + verhaalpagina's) naar geheugen.json."""
import re, html, json, urllib.request, time
BASE = 'https://www.historischekringheemskerk.nl/Geheugen/geheugenvanheemskerk/'

def get(u):
    for attempt in range(3):
        try:
            req = urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0'})
            return urllib.request.urlopen(req, timeout=40).read().decode('utf-8', 'ignore')
        except Exception as e:
            if attempt == 2: raise
            time.sleep(2)

def clean(t):
    t = re.sub(r'<br\s*/?>', '\n', t)
    t = re.sub(r'<[^>]+>', '', t)
    t = html.unescape(t).replace('\xa0', ' ')
    return re.sub(r'[ \t]+', ' ', t).strip()

def paragraphs(wiki_html):
    out = []
    for p in re.findall(r'<p[^>]*>(.*?)</p>', wiki_html, re.S):
        for part in clean(p).split('\n'):
            part = part.strip()
            if part: out.append(part)
    if not out:
        t = clean(wiki_html)
        if t: out = [t]
    return out

def div_inner(s, start):
    """Inner HTML of the div that opens at index start (depth counting)."""
    i = s.index('>', start) + 1
    depth = 1
    for m in re.finditer(r'<div\b|</div>', s[i:]):
        depth += 1 if m.group(0) == '<div' else -1
        if depth == 0:
            return s[i:i + m.start()]
    return s[i:]

index = open('legacy/geheugen.html', encoding='utf-8', errors='ignore').read()
rows = re.findall(r'<tr[^>]*>(.*?)</tr>', index, re.S)
stories = []
for r in rows:
    cells = re.findall(r'<td[^>]*>(.*?)</td>', r, re.S)
    if len(cells) < 4: continue
    m = re.search(r'href=(\S+?\.html)', cells[3])
    if not m: continue
    href = m.group(1).lstrip('./')
    stories.append({'theme': clean(cells[0]), 'neighbourhood': clean(cells[1]), 'author': clean(cells[2]),
                    'title': clean(cells[3]), 'href': href.replace('geheugenvanheemskerk/', '')})
print('index', len(stories))

def parse_story(s):
    rec = {}
    i = s.find('<div class="detailed_view">')
    view = div_inner(s, i)
    h1 = re.search(r'<h1>(.*?)</h1>', view, re.S)
    rec['title'] = clean(h1.group(1)) if h1 else ''
    nar = re.search(r'class="narratorof"[^>]*>.*?<span>(.*?)</span>', view, re.S)
    rec['narrator'] = clean(nar.group(1)) if nar else ''
    dl = re.search(r'class="date_loc">(.*?)</p>', view, re.S)
    parts = [p.strip() for p in clean(dl.group(1)).split('|')] if dl else []
    parts = [p for p in parts if p]
    rec['period'] = parts[-1] if len(parts) >= 2 else ''
    intro = re.search(r'<div class="intro">', view)
    rec['intro'] = paragraphs(div_inner(view, intro.start())) if intro else []
    body = re.search(r'<div class="body">', view)
    rec['body'] = paragraphs(div_inner(view, body.start())) if body else []
    figs = []
    for fm in re.finditer(r'<div class="fig01">', view):
        fig = div_inner(view, fm.start())
        img = re.search(r'<img[^>]*src="image/([^"]*)"', fig)
        if not img: continue
        src = img.group(1)
        big = re.search(r"'image/([^']*-724-[^']*)'", fig)
        cap = re.search(r'<div class="caption">', fig)
        caption = ' '.join(paragraphs(div_inner(fig, cap.start()))) if cap else ''
        alt = re.search(r'alt="([^"]*)"', img.group(0))
        figs.append({'src': BASE + 'image/' + (big.group(1) if big else src), 'caption': caption,
                     'alt': html.unescape(alt.group(1)) if alt else ''})
    rec['figures'] = figs
    cd = re.search(r'class="createdate">(.*?)</p>', view, re.S)
    rec['created'] = clean(cd.group(1)) if cd else ''
    au = re.search(r'<div class="authorof">', view)
    rec['recorded_by'] = clean(div_inner(view, au.start())) if au else ''
    related = []
    for rm in re.finditer(r'<div id="li_([\d.]+)"', s[:i] if i > 0 else s):
        block = div_inner(s, rm.start())
        href = re.search(r'href="(article-[^"]+\.html)"', block)
        t = re.search(r'<h3[^>]*>(.*?)</h3>', block, re.S)
        if href and t:
            related.append({'href': href.group(1), 'title': clean(t.group(1))})
    rec['related'] = related
    return rec

out = []
for n, st in enumerate(stories):
    try:
        s = get(BASE + st['href'])
        rec = parse_story(s)
    except Exception as e:
        print('ERR', st['href'], e); continue
    rec.update({k: st[k] for k in ('theme', 'neighbourhood', 'author', 'href')})
    if not rec['title']: rec['title'] = st['title']
    out.append(rec)
    if n % 20 == 0: print(n, rec['title'], len(rec['body']), 'par', len(rec['figures']), 'fig', flush=True)
ab = {'intro': [], 'body': []}
try:
    about = get(BASE + 'article-1036.1024-nl.html')
    if '<div class="detailed_view">' in about:
        ab = parse_story(about)
except Exception as e:
    print('about not available', e)
json.dump({'stories': out, 'about': ab}, open('geheugen.json', 'w'), ensure_ascii=False, indent=1)
print('done', len(out), 'about paragraphs', len(ab['body']))
