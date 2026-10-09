import re,html,json,sys,urllib.request
base='https://www.historischekringheemskerk.nl'
urls=[l.strip() for l in open('urls.txt') if l.strip()]
def get(u):
    req=urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'})
    return urllib.request.urlopen(req,timeout=30).read().decode('utf-8','ignore')
def widget_inner(s, wtype, start=0):
    """Return inner HTML of the first elementor widget of given type after start, else None."""
    m=re.search(r'<div class="elementor-element elementor-element-\w+[^"]*"[^>]*data-widget_type="'+re.escape(wtype)+r'"[^>]*>', s[start:])
    if not m: return None
    i=start+m.end()
    # find matching close by depth counting on <div
    depth=1; j=i
    for t in re.finditer(r'<div\b|</div>', s[i:]):
        depth+= 1 if t.group(0)=='<div' else -1
        if depth==0: j=i+t.start(); break
    return s[i:j]
def clean_text(h):
    t=re.sub(r'<[^>]+>','',h); return html.unescape(re.sub(r'\s+',' ',t)).strip()
def to_blocks(h):
    """Convert content HTML to simple blocks."""
    h=re.sub(r'<(script|style)[^>]*>.*?</\1>','',h,flags=re.S)
    blocks=[]
    # tokenise top-level-ish elements: figure/img, h2-h4, p, ul/ol, blockquote, table(skip)
    for m in re.finditer(r'<figure[^>]*>.*?</figure>|<img[^>]*>|<(?P<h>h[1-6])[^>]*>.*?</(?P=h)>|<p[^>]*>.*?</p>|<(?P<l>ul|ol)[^>]*>.*?</(?P=l)>', h, re.S):
        x=m.group(0)
        if x.startswith('<figure') or x.startswith('<img'):
            src=re.search(r'<img[^>]*src="([^"]*)"',x)
            cap=re.search(r'<figcaption[^>]*>(.*?)</figcaption>',x,re.S)
            alt=re.search(r'alt="([^"]*)"',x)
            if src:
                u=src.group(1); u=re.sub(r'-\d+x\d+(\.\w+)$',r'\1',u)
                if 'ezeltje' in u or 'icon-HKH' in u: continue
                blocks.append({'type':'image','src':u,'caption':clean_text(cap.group(1)) if cap else '','alt':html.unescape(alt.group(1)) if alt else ''})
            # inner imgs in p handled when figure
            continue
        if m.group('h'):
            t=clean_text(x)
            if t: blocks.append({'type':'heading','level':int(m.group('h')[1]),'text':t})
            continue
        if m.group('l'):
            items=[clean_text(li) for li in re.findall(r'<li[^>]*>(.*?)</li>',x,re.S)]
            items=[i for i in items if i]
            if items: blocks.append({'type':'list','ordered':m.group('l')=='ol','items':items})
            continue
        # paragraph: may contain img
        for im in re.finditer(r'<img[^>]*src="([^"]*)"[^>]*>',x):
            u=re.sub(r'-\d+x\d+(\.\w+)$',r'\1',im.group(1))
            blocks.append({'type':'image','src':u,'caption':'','alt':''})
        links=[(clean_text(t),hh) for hh,t in re.findall(r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',x,re.S)]
        t=clean_text(x)
        if t:
            b={'type':'paragraph','text':t}
            if links: b['links']=[{'text':a,'href':b2} for a,b2 in links if a]
            if re.search(r'<strong>\s*'+re.escape(t[:20]),x) and len(t)<80: b['strong']=True
            blocks.append(b)
    return blocks
out=[]
for u in urls:
    if '/hkh-bestuurslid/' in u or '/hkh-product-categorie/' in u or '/nav-' in u or 'test-evenementen' in u: continue
    try: s=get(u)
    except Exception as e:
        try: s=get(u)
        except Exception as e2: print('ERR',u,e2); continue
    rec={'url':u,'slug':u.replace(base,'').strip('/')}
    rec['title']=html.unescape(re.sub(r'\s+-\s+Historische Kring Heemskerk.*','',re.search(r'<title>(.*?)</title>',s,re.S).group(1))).strip()
    fi=widget_inner(s,'theme-post-featured-image.default') or widget_inner(s,'tec_events_elementor_widget_event_image.default')
    if fi:
        m=re.search(r'<img[^>]*src="([^"]*)"',fi); 
        if m: rec['image']=re.sub(r'-\d+x\d+(\.\w+)$',r'\1',m.group(1))
    body=widget_inner(s,'theme-post-content.default')
    rec['blocks']=to_blocks(body) if body else []
    rec['body_html']=body.strip() if body else ''
    gal=widget_inner(s,'gallery.default')
    if gal:
        gi=[]
        for u in re.findall(r'<img[^>]*src="([^"]*)"',gal):
            u=re.sub(r'-\d+x\d+(\.\w+)$',r'\1',u)
            if u not in gi: gi.append(u)
        rec['gallery']=gi
    try:
        urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=5)
    except Exception: pass
    if '/evenement/' in u:
        dt=widget_inner(s,'tec_events_elementor_widget_event_datetime.default'); rec['datetime']=clean_text(dt) if dt else ''
        ven=widget_inner(s,'tec_events_elementor_widget_event_venue.default'); rec['venue']=clean_text(ven) if ven else ''
        org=widget_inner(s,'tec_events_elementor_widget_event_organizer.default'); rec['organizer']=clean_text(org) if org else ''
        cost=widget_inner(s,'tec_events_elementor_widget_event_cost.default'); rec['cost']=clean_text(cost) if cost else ''
        m=re.search(r'"startDate":"([^"]+)","endDate":"([^"]+)"',s)
        if m: rec['start'],rec['end']=m.group(1),m.group(2)
        m=re.search(r'"offers":\{[^}]*"price":"([^"]*)"',s)
        if m: rec['price']=m.group(1)
    m=re.search(r'"datePublished":"([^"]+)"',s)
    if m: rec['published']=m.group(1)
    # price fields on products
    if '/hkh-product/' in u:
        rec['product_text']=clean_text(re.sub(r'<(script|style)[^>]*>.*?</\1>','',s,flags=re.S))
    out.append(rec)
    print(f"{len(rec['blocks']):3d} blocks  img={'y' if rec.get('image') else '-'}  {rec['slug']}")
json.dump(out,open('content.json','w'),ensure_ascii=False,indent=1)
