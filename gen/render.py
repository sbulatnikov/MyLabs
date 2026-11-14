"""Грубый предпросмотр формы аддона: раскладка виджетов из xdb, текстуры из preview PNG."""
import os, re, sys
from PIL import Image, ImageDraw, ImageFont

ADDON = sys.argv[1]
PREV = sys.argv[2]
OUT = sys.argv[3]
ROOTW = sys.argv[4] if len(sys.argv) > 4 else 'BAAWindow.(WidgetPanel).xdb'
SHOW = set((sys.argv[5] if len(sys.argv) > 5 else '').split(',')) - {''}
VAR = {}  # имя кнопки -> вариант
for kv in (sys.argv[6] if len(sys.argv) > 6 else '').split(','):
    if '=' in kv:
        k, v = kv.split('='); VAR[k] = int(v)
TEXTS = {}
for kv in (sys.argv[7] if len(sys.argv) > 7 else '').split('|'):
    if '=' in kv:
        k, v = kv.split('=', 1); TEXTS[k] = v
WID = os.path.join(ADDON, 'Widgets')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed.ttf'
FONTB = '/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf'


def tag(x, t, default=None):
    m = re.search(r'<%s>([^<]*)</%s>' % (t, t), x)
    return m.group(1) if m else default


def axis(x, t, psize):
    m = re.search(r'<%s>(.*?)</%s>' % (t, t), x, re.S)
    if not m:
        return 0, psize
    a = m.group(1)
    pos = int(tag(a, 'Pos', 0)); size = tag(a, 'Size'); al = tag(a, 'Align', 'WIDGET_ALIGN_LOW'); hp = int(tag(a, 'HighPos', 0))
    if al == 'WIDGET_ALIGN_BOTH':
        return pos, psize - pos - hp
    size = int(size) if size else psize
    if al == 'WIDGET_ALIGN_HIGH':
        return psize - hp - size, size
    if al == 'WIDGET_ALIGN_CENTER':
        return (psize - size) // 2 + pos, size
    return pos, size


def layer_img(href, w, h):
    p = os.path.join(WID, href)
    x = open(p, encoding='utf-8').read()
    name = re.search(r'textureItem href="([^.]+)\.', x).group(1)
    im = Image.open(os.path.join(PREV, name + '.png')).convert('RGBA')
    if w <= 0 or h <= 0:
        return None
    if 'Tiled' in href:
        e = int(tag(x, 'LeftX'))
        e = min(e, w // 2, h // 2)
        out = Image.new('RGBA', (w, h))
        W0, H0 = im.size
        E0 = int(tag(x, 'LeftX'))
        def crop(a, b, c, d): return im.crop((a, b, c, d))
        sx = [(0, E0, 0, e), (E0, W0 - E0, e, w - e), (W0 - E0, W0, w - e, w)]
        sy = [(0, E0, 0, e), (E0, H0 - E0, e, h - e), (H0 - E0, H0, h - e, h)]
        for (a, b, c, d) in sx:
            for (aa, bb, cc, dd) in sy:
                if d - c > 0 and dd - cc > 0:
                    out.alpha_composite(crop(a, aa, b, bb).resize((d - c, dd - cc)), (c, cc))
        return out
    return im.resize((w, h), Image.LANCZOS)


def text_of(ref, value):
    p = os.path.normpath(os.path.join(WID, ref))
    t = open(p, 'rb').read().decode('utf-16')
    m = re.search(r'<html ([^>]*)>(.*)</html>', t, re.S)
    attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
    body = m.group(2)
    body = re.sub(r'<r name="[^"]+"/>', value or '', body)
    return attrs, body


def draw_text(img, box, attrs, s):
    if not s:
        return
    d = ImageDraw.Draw(img)
    size = int(attrs.get('fontsize', 14))
    f = ImageFont.truetype(FONTB if 'Bold' in attrs.get('fontname', '') or 'Fantasy' in attrs.get('fontname', '') else FONT, int(size * 0.9))
    col = attrs.get('color', '0xffffffff')
    c = (int(col[4:6], 16), int(col[6:8], 16), int(col[8:10], 16), 255)
    x0, y0, w, h = box
    tw, th = d.textbbox((0, 0), s, font=f)[2:]
    ax = attrs.get('alignx', 'left'); ay = attrs.get('aligny', 'top')
    x = x0 if ax == 'left' else (x0 + w - tw if ax == 'right' else x0 + (w - tw) // 2)
    y = y0 if ay == 'top' else (y0 + h - th if ay == 'bottom' else y0 + (h - th) // 2 - 1)
    d.text((x, y), s, font=f, fill=c)


def render(fn, img, ox, oy, pw, ph, force=False):
    p = os.path.join(WID, fn)
    x = open(p, encoding='utf-8').read()
    name = tag(x, 'Name')
    if '<Visible>false</Visible>' in x and name not in SHOW and not force:
        return
    px, w = axis(x, 'X', pw)
    py, h = axis(x, 'Y', ph)
    ax, ay = (ox, oy) if force else (ox + px, oy + py)
    m = re.search(r'<BackLayer href="([^"]+)"', x)
    if m:
        li = layer_img(m.group(1), w, h)
        if li: img.alpha_composite(li, (ax, ay))
    if fn.endswith('(WidgetButton).xdb'):
        items = re.findall(r'<Item>(.*?)</Item>', re.search(r'<Variants>(.*?)</Variants>', x, re.S).group(1), re.S)
        v = items[min(VAR.get(name, 0), len(items) - 1)]
        lm = re.search(r'<StateNormal>\s*<LayerMain href="([^"]+)"', v)
        if lm:
            li = layer_img(lm.group(1), w, h)
            if li: img.alpha_composite(li, (ax, ay))
        tf = re.search(r'<TextFileRef href="([^"]+)"', v)
        ff = re.search(r'<StateNormal>.*?<FormatFileRef href="([^"]+)"', v, re.S)
        if tf and ff:
            label = open(os.path.normpath(os.path.join(WID, tf.group(1))), 'rb').read().decode('utf-16')
            attrs, body = text_of(ff.group(1), label)
            draw_text(img, (ax, ay, w, h), attrs, body)
    if fn.endswith('(WidgetTextView).xdb') or fn.endswith('(WidgetEditLine).xdb'):
        ff = re.search(r'<FormatFileRef href="([^"]+)"', x)
        if ff:
            attrs, body = text_of(ff.group(1), TEXTS.get(name, ''))
            draw_text(img, (ax, ay, w, h), attrs, body)
    ch = re.search(r'<Children>(.*?)</Children>', x, re.S)
    if ch:
        for c in re.findall(r'href="([^"]+)"', ch.group(1)):
            render(c, img, ax, ay, w, h)


img = Image.new('RGBA', (int(sys.argv[8]) if len(sys.argv) > 8 else 600, int(sys.argv[9]) if len(sys.argv) > 9 else 760), (34, 38, 46, 255))
render(ROOTW, img, 20, 20, img.size[0] - 40, img.size[1] - 40, force=True)
img.save(OUT)
