"""Карточки MyLabs для форума: шесть PNG 1600x900 в том же формате, что у RaidPartyLeader.

  python3 promo/cards.py <папка-результат>
Нужен google-chrome (headless). Окно аддона собирается из тех же размеров и цветов, что и в игре
(единицы макета, см. gen/build.py), значки — картинки из ресурсов игры (assets/).
"""
import os, subprocess, sys, html

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(SRC, 'out', 'cards')
VERSION = '0.9.0'
os.makedirs(OUT, exist_ok=True)


def A(name):
    return 'file://' + os.path.join(SRC, 'assets', name)


FONT = 'file://' + os.path.join(SRC, 'assets', 'Allods.ttf')
BG = 'file://' + os.path.join(HERE, 'horn-shot.png')

PROD = {
    'gold': ('Золото', 'res-gold.png'), 'tear1': ('Сияющие слёзы', 'res-tears-shining.png'),
    'tear2': ('Сверкающие слёзы', 'res-tears-glowing.png'), 'granite': ('Гранит', 'res-granite.png'),
    'coral': ('Коралл', 'res-coral.png'), 'none': ('Не запускать', 'res-none.png'),
}
CHEST = {'gold': ('Золото', 'res-gold.png'), 'tear': ('Слеза дракона', 'res-tears-shining.png'),
         'coral': ('Коралл', 'res-coral.png'), 'granite': ('Гранит', 'res-granite.png'), 'none': ('Не открывать', 'res-none.png')}
RES_ICONS = ['res-granite.png', 'res-coral.png', 'res-embrium.png', 'res-meteorite.png', 'res-supplies.png', None]
FAC = {'L': 'faction-league.png', 'E': 'faction-empire.png'}

CSS = '''
@font-face{font-family:AllodsWest;src:url("%s")}
*{box-sizing:border-box}
body{margin:0;background:#0B0C10}
.card{width:1600px;height:900px;position:relative;overflow:hidden;background:#0B0C10;font-family:Inter,Arial,sans-serif;color:#ECE6EF}
.bg{position:absolute;left:-40px;top:-40px;width:1680px;height:980px;object-fit:cover;filter:blur(7px) saturate(1.05) brightness(.8)}
.scrim{position:absolute;inset:0;background:linear-gradient(90deg,rgba(11,9,14,.95) 0%%,rgba(11,9,14,.86) 30%%,rgba(11,9,14,.42) 62%%,rgba(11,9,14,.5) 100%%)}
.copy{position:absolute;left:72px;top:96px;width:404px;display:flex;flex-direction:column;gap:22px}
.kick{display:flex;align-items:center;gap:10px;font-size:15px;font-weight:700;letter-spacing:.12em;text-transform:uppercase;color:#F2B8F3}
.kick i{width:12px;height:12px;border-radius:4px;background:#BB1ABD;display:block}
h1{margin:0;font-family:Lora,Georgia,serif;font-weight:700;color:#fff;line-height:1.06;letter-spacing:-.005em}
.lead{margin:0;font-size:20px;line-height:1.45;color:#D9D1DE}
.pts{display:flex;flex-direction:column;gap:14px;margin-top:6px}
.pt{display:flex;align-items:flex-start;gap:14px;font-size:18.5px;line-height:1.35}
.pt>span:last-child{padding-top:6px}
.tile{width:36px;height:36px;flex:0 0 36px;border-radius:9px;background:#2A2230;border:1px solid #4A3B52;display:flex;align-items:center;justify-content:center;font-size:19px;font-weight:700;color:#F2B8F3}
.tile img{width:22px;height:22px;object-fit:contain}
.foot{position:absolute;left:72px;bottom:58px;display:flex;align-items:center;gap:14px;font-size:16px;color:#A79DAE}
.foot b{font-family:Lora,Georgia,serif;font-size:21px;font-weight:700;color:#ECE6EF}
.view{position:absolute;overflow:hidden;border-radius:16px;box-shadow:0 30px 80px rgba(0,0,0,.55),0 0 0 1px rgba(255,255,255,.06)}
.stage{position:absolute;transform-origin:0 0}
.chat{position:absolute;width:440px;display:flex;flex-direction:column;gap:7px;font-size:15px;line-height:1.3;color:#F5E6A8;white-space:nowrap}
.chat-h{font-size:13px;font-weight:700;letter-spacing:.1em;text-transform:uppercase;color:#A79DAE;margin-bottom:3px}
.chat span{background:rgba(8,7,10,.78);padding:8px 13px;border-radius:9px;border:1px solid #2A2330}
.callout{position:absolute;display:flex;align-items:center;gap:12px;font-size:18px;color:#D9D1DE;white-space:nowrap}
.callout i{width:26px;height:2px;background:#4A3B52;display:block}
.nb{display:inline-flex;align-items:center;justify-content:center;height:30px;padding:0 14px;border-radius:15px;border:1px solid;font-size:16px}
.nb.ok{background:#12301F;border-color:#2E6B47;color:#6FD99A}
.nb.warn{background:#2E2410;border-color:#6A5420;color:#F5B841}
.nb.time{background:#221D27;border-color:#3A3141;color:#BDB4C4}
.note{position:absolute;font-size:17px;color:#D9D1DE;text-shadow:0 1px 3px #000}

/* ---- окно аддона, единицы макета ---- */
.w{position:absolute;left:0;top:0;width:824px;height:676px;background:#17141B;border:1.2px solid #3A2F42;border-radius:12px;font-size:13px;letter-spacing:-.012em;color:#ECE6EF;overflow:hidden}
.w .abs{position:absolute}
.w .hdr{position:absolute;left:0;top:0;width:824px;height:40px;background:#1D1922;border-bottom:1px solid #2A2330}
.w .fan{font-family:AllodsWest,Lora,serif;letter-spacing:.01em}
.w .gold{color:#D9BE7A}
.w .dim{color:#8C8393}
.w .sm{font-size:11.7px}
.w .num{font-weight:600;font-variant-numeric:tabular-nums}
.w .pill{position:absolute;height:20px;border-radius:10px;border:1px solid;font-size:11.7px;display:flex;align-items:center;justify-content:center;white-space:nowrap}
.w .ok{background:#12301F;border-color:#2E6B47;color:#6FD99A}
.w .warn{background:#2E2410;border-color:#6A5420;color:#F5B841}
.w .mute{background:#221D27;border-color:#3A3141;color:#8C8393}
.w .acc{background:#2C1230;border-color:#6A2A6E;color:#F2B8F3}
.w .box{position:absolute;background:#100E13;border:1px solid #2A2330;border-radius:7px}
.w .line{position:absolute;height:1px;background:#2A2330}
.w .chip{position:absolute;height:30px;background:#1D1922;border:1px solid #2A2330;border-radius:6px}
.w .field{position:absolute;background:#100E13;border:1px solid #3A3141;border-radius:6px}
.w .field.attn{background:#2C1230;border-color:#BB1ABD}
.w .field.open{background:#17131B;border-color:#E58BE7}
.w .no{position:absolute;width:22px;height:20px;border-radius:5px;background:#221D27;border:1px solid #3A3141;color:#BDB4C4;font-weight:600;display:flex;align-items:center;justify-content:center;font-size:12.5px}
.w .row{position:absolute;left:2px;width:540px;height:26px}
.w .crow{position:absolute;left:4px;width:224px;height:30px;border-radius:6px}
.w .crow.sel{background:#2C1230;border:1px solid #6A2A6E}
.w .menu{position:absolute;width:190px;background:#0F0D12;border:1px solid #4A3B52;border-radius:7px;box-shadow:0 10px 30px rgba(0,0,0,.6)}
.w .mi{position:absolute;left:4px;width:182px;height:26px;border-radius:5px}
.w .mi.sel{background:#3A1440}
.w .mi.hov{background:#241D2A}
.w img{position:absolute;object-fit:contain}
.w .t{position:absolute;white-space:nowrap;display:flex;align-items:center}
''' % FONT


def e(s):
    return html.escape(str(s))


def swords(x, y, s):
    return ('<svg class="abs" style="left:%dpx;top:%dpx" width="%d" height="%d" viewBox="0 0 16 16" fill="none" stroke="#D9BE7A" stroke-width="1.5" '
            'stroke-linecap="round"><path d="M3 3l8.5 8.5M9.5 13.5l4-4M12 12l1.5 1.5M13 3l-8.5 8.5M6.5 13.5l-4-4M4 12l-1.5 1.5"/></svg>' % (x, y, s, s))


def chevron(x, y):
    return ('<svg class="abs" style="left:%dpx;top:%dpx" width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="#BDB4C4" stroke-width="1.8" '
            'stroke-linecap="round" stroke-linejoin="round"><path d="M4 6l4 4 4-4"/></svg>' % (x, y))


def arrow(x, y, on):
    return ('<svg class="abs" style="left:%dpx;top:%dpx" width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="%s" stroke-width="1.8" '
            'stroke-linecap="round" stroke-linejoin="round"><path d="M3 8h10M9 4l4 4-4 4"/></svg>' % (x, y, '#E58BE7' if on else '#5E5664'))


def field(x, y, w, h, icon, name, cls=''):
    o = '<div class="field %s" style="left:%dpx;top:%dpx;width:%dpx;height:%dpx">' % (cls, x, y, w, h)
    if icon:
        o += '<img src="%s" style="left:6px;top:%dpx;width:16px;height:16px">' % (A(icon), (h - 18) // 2)
    o += '<div class="t" style="left:28px;top:0;height:%dpx">%s</div>' % (h - 2, e(name))
    o += chevron(w - 19, (h - 14) // 2) + '</div>'
    return o


def window(d):
    """d: chars, sel, card (см. данные карточек ниже), menu."""
    c = d['card']
    o = ['<div class="w">']
    # шапка
    o.append('<div class="hdr"></div><div class="abs" style="left:12px;top:15px;width:10px;height:10px;border-radius:3px;background:#BB1ABD"></div>')
    o.append('<div class="t fan" style="left:28px;top:0;height:40px;font-size:15px">MyLabs</div>')
    if d.get('ready'):
        o.append('<div class="pill ok" style="left:118px;top:10px;width:92px">Готово: %d</div>' % d['ready'])
    else:
        o.append('<div class="pill mute" style="left:118px;top:10px;width:92px">Готовых нет</div>')
    o.append('<svg class="abs" style="left:796px;top:13px" width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="#BDB4C4" stroke-width="1.8" '
             'stroke-linecap="round"><path d="M4 4l8 8M12 4l-8 8"/></svg>')
    # список персонажей
    o.append('<div class="t fan gold" style="left:12px;top:52px;height:22px">Персонажи</div>')
    o.append('<div class="t sm dim" style="left:184px;top:52px;width:60px;height:22px;justify-content:flex-end">%d</div>' % len(d['chars']))
    o.append('<div class="box" style="left:12px;top:80px;width:232px;height:584px">')
    for i, ch in enumerate(d['chars']):
        o.append('<div class="crow %s" style="top:%dpx">' % ('sel' if i == d.get('sel', 0) else '', 4 + 32 * i))
        if ch.get('cur'):
            o.append('<div class="abs" style="left:4px;top:12px;width:6px;height:6px;border-radius:3px;background:#D045D2"></div>')
        o.append('<img src="%s" style="left:14px;top:5px;width:27px;height:20px">' % A(FAC[ch['fac']]))
        o.append('<div class="t" style="left:47px;top:0;height:30px">%s</div>' % e(ch['name']))
        if ch.get('pill'):
            o.append('<div class="pill %s" style="left:153px;top:5px;width:64px">%s</div>' % (ch['pill'][0], e(ch['pill'][1])))
        else:
            o.append('<div class="t sm dim" style="left:147px;top:0;width:70px;height:30px;justify-content:flex-end">%s</div>' % e(ch.get('time', '')))
        o.append('</div>')
    o.append('</div><div class="abs" style="left:256px;top:40px;width:1px;height:636px;background:#2A2330"></div>')
    # карточка
    X, Y = 268, 52
    o.append('<div class="abs" style="left:%dpx;top:%dpx;width:544px;height:612px">' % (X, Y))
    o.append('<img src="%s" style="left:0;top:3px;width:40px;height:30px">' % A(FAC[c['fac']]))
    o.append('<div class="t fan" style="left:50px;top:0;height:36px;font-size:15px">%s</div>' % e(c['name']))
    if c.get('here'):
        o.append('<div class="pill acc" style="left:468px;top:8px;width:76px">Вы здесь</div>')
    else:
        o.append('<div class="t sm dim" style="left:324px;top:8px;width:220px;height:20px;justify-content:flex-end">%s</div>' % e(c.get('seen', '')))
    cw = (544 - 30) / 6.0
    for i, v in enumerate(c['res']):
        x = i * (cw + 6)
        o.append('<div class="chip" style="left:%.1fpx;top:46px;width:%.1fpx">' % (x, cw))
        if RES_ICONS[i]:
            o.append('<img src="%s" style="left:6px;top:5px;width:18px;height:18px">' % A(RES_ICONS[i]))
        else:
            o.append(swords(6, 5, 18))
        o.append('<div class="t sm" style="left:26px;top:0;width:%.1fpx;height:28px;justify-content:flex-end">%s</div></div>' % (cw - 34, e(v)))
    o.append('<div class="line" style="left:0;top:86px;width:544px"></div>')
    o.append('<div class="t fan gold" style="left:0;top:94px;height:22px">Рога изобилия</div>')
    o.append('<div class="t sm dim" style="left:404px;top:94px;width:140px;height:22px;justify-content:flex-end">%s</div>' % e(c['count']))
    for x, w, text, j in ((8, 22, '№', 'center'), (38, 140, 'Запущен', 'flex-start'), (214, 160, 'Назначен', 'flex-start'), (416, 120, 'Осталось', 'flex-end')):
        o.append('<div class="t sm dim" style="left:%dpx;top:118px;width:%dpx;height:18px;justify-content:%s">%s</div>' % (x, w, j, text))
    o.append('<div class="box" style="left:0;top:138px;width:544px;height:318px">')
    for i, h in enumerate(c['horns']):
        o.append('<div class="row" style="top:%dpx">' % (3 + 26 * i))
        o.append('<div class="no" style="left:6px;top:3px">%d</div>' % h.get('no', i + 1))
        if h.get('run'):
            n, ic = PROD[h['run']]
            o.append('<img src="%s" style="left:36px;top:4px;width:18px;height:18px"><div class="t" style="left:60px;top:0;height:26px">%s</div>' % (A(ic), n))
        else:
            o.append('<div class="t dim" style="left:36px;top:0;height:26px">Не запущен</div>')
        a = h.get('assign')
        differs = a is not None and ((h.get('run') and a != h['run']) or (not h.get('run') and a != 'none'))
        o.append(arrow(190, 6, differs))
        n, ic = PROD[a] if a else ('Не выбрано', None)
        cls = 'open' if h.get('open') else ('attn' if differs else '')
        o.append(field(212, 2, 190, 22, ic, n, cls))
        st = h['st']
        if st[0] == 'time':
            o.append('<div class="t num" style="left:414px;top:0;width:120px;height:20px;justify-content:flex-end">%s</div>' % st[1])
            o.append('<div class="abs" style="left:454px;top:21px;width:80px;height:3px;border-radius:2px;background:#3A3141">'
                     '<div style="width:%d%%;height:3px;border-radius:2px;background:#BB1ABD"></div></div>' % int(st[2] * 100))
        else:
            o.append('<div class="pill %s" style="left:438px;top:3px;width:96px">%s</div>' % (st[0], st[1]))
        o.append('</div>')
    o.append('</div>')
    o.append('<div class="line" style="left:0;top:466px;width:544px"></div>')
    o.append('<img src="%s" style="left:0;top:478px;width:24px;height:24px">' % A('chest.png'))
    o.append('<div class="t fan gold" style="left:32px;top:474px;height:32px">Сундучок хранителя</div>')
    n, ic = CHEST[c['chest']]
    o.append(field(214, 478, 190, 24, ic, n, 'open' if c.get('chestOpen') else ''))
    o.append('<div class="t sm dim" style="left:410px;top:474px;width:126px;height:32px;justify-content:flex-end">%s</div>' % e(c.get('chestNote', '')))
    o.append('<div class="line" style="left:0;top:514px;width:544px"></div>')
    o.append('<div class="t fan gold" style="left:0;top:522px;height:22px">Новый Рог Изобилия</div>')
    nb = c['new']
    o.append('<div class="pill %s" style="left:306px;top:523px;width:230px">%s</div>' % nb['badge'])
    for x, text in ((272, 'Нужно'), (360, 'Есть'), (448, 'Не хватает')):
        o.append('<div class="t sm dim" style="left:%dpx;top:546px;width:88px;height:16px;justify-content:flex-end">%s</div>' % (x, text))
    for i, (ic, name, need, have, lack, bad) in enumerate(nb['rows']):
        y = 564 + 24 * i
        o.append('<img src="%s" style="left:0;top:%dpx;width:18px;height:18px"><div class="t" style="left:26px;top:%dpx;height:24px">%s</div>' % (A(ic), y + 3, y, name))
        o.append('<div class="t num" style="left:272px;top:%dpx;width:88px;height:24px;justify-content:flex-end">%s</div>' % (y, need))
        o.append('<div class="t num" style="left:360px;top:%dpx;width:88px;height:24px;justify-content:flex-end;color:#BDB4C4">%s</div>' % (y, have))
        o.append('<div class="t num" style="left:448px;top:%dpx;width:88px;height:24px;justify-content:flex-end;color:%s">%s</div>' % (y, '#F5B841' if bad else '#6FD99A', lack))
    # выпадающий список (в координатах карточки)
    m = d.get('menu')
    if m:
        o.append('<div class="menu" style="left:%dpx;top:%dpx;height:%dpx">' % (m['x'], m['y'], 8 + 26 * len(m['items'])))
        for i, (key, table, sel, owner, hov) in enumerate(m['items']):
            n, ic = table[key]
            o.append('<div class="mi %s" style="top:%dpx">' % ('sel' if sel else ('hov' if hov else ''), 4 + 26 * i))
            o.append('<img src="%s" style="left:6px;top:5px;width:16px;height:16px;%s">' % (A(ic), 'opacity:.35' if owner else ''))
            o.append('<div class="t %s" style="left:28px;top:0;height:26px">%s</div>' % ('dim' if owner else '', n))
            if owner:
                o.append('<div class="no" style="left:156px;top:4px;height:18px;font-size:11.7px">%d</div>' % owner)
            o.append('</div>')
        o.append('</div>')
    o.append('</div></div>')
    return ''.join(o)


def launcher(x, y, s, count):
    o = '<div class="abs" style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx">' % (x, y, 48 * s, 48 * s)
    o += ('<div style="position:absolute;left:0;top:0;width:%dpx;height:%dpx;border-radius:%dpx;background:#2C1230;border:2px solid #BB1ABD;'
          'box-shadow:0 6px 20px rgba(0,0,0,.5)"></div>' % (44 * s, 44 * s, 10 * s))
    o += '<img src="%s" style="position:absolute;left:%dpx;top:%dpx;width:%dpx;height:%dpx">' % (A('horn.png'), 6 * s, 6 * s, 32 * s, 32 * s)
    if count:
        o += ('<div style="position:absolute;left:%dpx;top:%dpx;min-width:%dpx;height:%dpx;border-radius:%dpx;background:#BB1ABD;border:1.5px solid #EFA0F0;'
              'color:#fff;font-weight:700;font-size:%dpx;display:flex;align-items:center;justify-content:center;padding:0 5px">%d</div>'
              % (26 * s, 28 * s, 22 * s, 18 * s, 9 * s, 13 * s, count))
    return o + '</div>'


# ------------------------------------------------------------------ данные (имена вымышленные)
def T(days):
    return ('time', '%d дн.' % days, (15 - days) / 15.0)


OK, FREE_W, FREE_M = ('ok', 'Готов'), ('warn', 'Свободен'), ('mute', 'Свободен')
CHARS = [
    {'name': 'Аргенар', 'fac': 'L', 'cur': True, 'pill': ('ok', 'Готово: 2')},
    {'name': 'Вельмира', 'fac': 'L', 'time': '5 дн.'},
    {'name': 'Торбьорн', 'fac': 'E', 'pill': ('warn', 'Ждут: 1')},
    {'name': 'Ксаэль', 'fac': 'E', 'time': '11 дн.'},
    {'name': 'Лиорана', 'fac': 'L', 'time': '2 дн.'},
]
HORNS = [
    {'run': 'gold', 'assign': 'gold', 'st': OK}, {'run': 'gold', 'assign': 'gold', 'st': OK},
    {'run': 'gold', 'assign': 'coral', 'st': T(1)}, {'run': 'coral', 'assign': 'gold', 'st': T(1)},
    {'run': 'granite', 'assign': 'granite', 'st': T(4)}, {'run': 'tear1', 'assign': 'tear1', 'st': T(4)},
    {'run': 'tear2', 'assign': 'tear2', 'st': T(6)}, {'run': 'gold', 'assign': 'gold', 'st': T(6)},
    {'run': 'gold', 'assign': 'gold', 'st': T(9)}, {'run': 'gold', 'assign': 'none', 'st': T(9)},
    {'run': 'gold', 'assign': 'gold', 'st': T(13)}, {'run': None, 'assign': 'none', 'st': FREE_M},
]
NEW_ALL = {'badge': ('mute', 'Все рога построены'), 'rows': [('res-coral.png', 'Коралл', '—', '1 240', '—', False),
                                                            ('res-embrium.png', 'Эмбриум на обмен', '—', '2 583', '—', False)]}
CARD = {'name': 'Аргенар', 'fac': 'L', 'here': True, 'res': ['1 645', '1 240', '2 583', '14', '1 млн', '750'], 'count': '12',
        'horns': HORNS, 'chest': 'coral', 'chestNote': 'открыт 12.11 в 21:40', 'new': NEW_ALL}


def card2(**kw):
    c = dict(CARD)
    c.update(kw)
    return c


CARD_T = card2(name='Торбьорн', fac='E', here=False, seen='данные от 11.11 в 19:05', res=['310', '690', '2 583', '0', '179 500', '0'], count='7',
               horns=[{'run': 'gold', 'assign': 'gold', 'st': T(8)}, {'run': 'gold', 'assign': 'gold', 'st': T(8)},
                      {'run': 'coral', 'assign': 'coral', 'st': T(8)}, {'run': 'gold', 'assign': 'gold', 'st': T(8)},
                      {'run': 'tear1', 'assign': 'tear1', 'st': T(10)}, {'run': 'gold', 'assign': 'gold', 'st': T(10)},
                      {'run': None, 'assign': 'granite', 'st': FREE_W}],
               chest='gold', chestNote='открыт 09.11 в 20:12',
               new={'badge': ('ok', 'Можно строить за Эмбриум'), 'rows': [('res-coral.png', 'Коралл', '2 880', '690', '2 190', True),
                                                                             ('res-embrium.png', 'Эмбриум на обмен', '438', '2 583', '0', False)]})
CHARS_T = [dict(ch) for ch in CHARS]
PRODUCTS_MENU = [('gold', PROD, False, None, False), ('tear1', PROD, False, None, False), ('tear2', PROD, False, None, False),
                 ('granite', PROD, False, 5, False), ('coral', PROD, True, None, False), ('none', PROD, False, None, False)]
CHEST_MENU = [('gold', CHEST, False, None, False), ('tear', CHEST, False, None, True), ('coral', CHEST, True, None, False),
              ('granite', CHEST, False, None, False), ('none', CHEST, False, None, False)]


def horns_open(i):
    hs = [dict(h) for h in HORNS]
    hs[i]['open'] = True
    return hs


def tile(inner):
    return '<span class="tile">%s</span>' % inner


def timg(name):
    return tile('<img src="%s" alt="">' % A(name))


def page(n, kick, h1, size, lead, points, body, foot=None):
    pts = ''.join('<div class="pt">%s<span>%s</span></div>' % (t, e(text)) for t, text in points)
    foot = foot or '<b>MyLabs</b><span>%d / 6</span>' % n
    return ('<!doctype html><html lang="ru"><head><meta charset="utf-8"><style>%s</style></head><body><div class="card">'
            '<img class="bg" src="%s" alt=""><div class="scrim"></div>'
            '<div class="copy"><div class="kick"><i></i>%s</div><h1 style="font-size:%dpx">%s</h1><p class="lead">%s</p><div class="pts">%s</div></div>'
            '%s<div class="foot">%s</div></div></body></html>') % (CSS, BG, e(kick), size, h1, e(lead), pts, body, foot)


ZONE = (520, 80, 1540, 820)        # где на карточке живёт окно аддона


def view(d, region, zone=ZONE, smax=1.8, valign='center'):
    """Кусок окна region = (x0, y0, x1, y1) в единицах окна, вписанный в zone и выровненный по центру."""
    x0, y0, x1, y1 = region
    zx0, zy0, zx1, zy1 = zone
    s = min((zx1 - zx0) / (x1 - x0), (zy1 - zy0) / (y1 - y0), smax)
    w, h = (x1 - x0) * s, (y1 - y0) * s
    left = zx0 + ((zx1 - zx0) - w) / 2
    top = zy0 if valign == 'top' else zy0 + ((zy1 - zy0) - h) / 2
    return ('<div class="view" style="left:%.0fpx;top:%.0fpx;width:%.0fpx;height:%.0fpx;background:#17141B">'
            '<div class="stage" style="left:%.1fpx;top:%.1fpx;transform:scale(%.4f)">%s</div></div>') % (left, top, w, h, -x0 * s, -y0 * s, s, window(d)), (left, top, s)


def chat(top, lines):
    return '<div class="chat" style="left:72px;top:%dpx"><div class="chat-h">В чате игры</div>%s</div>' % (
        top, ''.join('<span>%s</span>' % e(l) for l in lines))


CARD_AREA = (257, 40, 824, 676)

cards = []
# 1. Обложка: окно целиком
S1 = 1.1
v, (vx, vy, vs) = view({'chars': CHARS, 'sel': 0, 'ready': 2, 'card': CARD}, (0, 0, 824, 676), zone=(520, 112, 1540, 860), smax=S1, valign='top')
v = v.replace('left:%.0fpx' % vx, 'left:520px', 1)
cards.append(('1-cover', page(
    1, 'Аддон для Аллодов Онлайн', 'Лабиринт без&nbsp;рутины', 58,
    'MyLabs помнит рога изобилия, ресурсы и сундучки всех персонажей аккаунта — и сам забирает добычу.',
    [(timg('horn.png'), 'Забирает добычу и запускает рог заново'),
     (timg('faction-league.png'), 'Помнит рога всех персонажей аккаунта'),
     (timg('chest.png'), 'Открывает сундучки хранителя')],
    launcher(520, 44, 1.1, 2) + '<div class="note" style="left:588px;top:60px">Число на кнопке — рога с готовой добычей</div>' + v,
    '<b>MyLabs %s</b><span>бета-версия</span>' % VERSION)))

# 2. Рога: карточка персонажа до конца таблицы
v, _ = view({'chars': CHARS, 'sel': 0, 'ready': 2, 'card': CARD}, (257, 40, 824, 520))
cards.append(('2-horns', page(
    2, 'Рога изобилия', 'Все рога в&nbsp;одном окне', 52,
    'Что добывает каждый рог, что запустится следом и сколько осталось до готовности.',
    [(tile('1'), '«Запущен» — что рог добывает сейчас'),
     (tile('2'), '«Назначен» — что запустить в следующий раз'),
     (tile('3'), '«Осталось» — дни до готовности'),
     (timg('horn.png'), 'Готовые рога — числом на кнопке аддона')], v)))

# 3. Автоматика: список «Назначен» и сообщения в чате
v, _ = view({'chars': CHARS, 'sel': 0, 'ready': 2, 'card': card2(horns=horns_open(2)),
             'menu': {'x': 214, 'y': 138 + 3 + 26 * 2 + 26, 'items': PRODUCTS_MENU}}, (257, 140, 824, 520))
cards.append(('3-auto', page(
    3, 'Автоматика', 'Заговорил — и&nbsp;готово', 52,
    'Подошли к рогу, начали разговор — остальное аддон сделает сам. Нажимать в нём ничего не нужно.',
    [(tile('1'), 'Забирает готовую добычу'),
     (tile('2'), 'Запускает то, что назначено'),
     (timg('res-none.png'), '«Не запускать» — заберёт и оставит рог свободным'),
     (timg('res-coral.png'), 'Коралл и гранит — по одному рогу, аддон следит сам')],
    v + chat(668, ['[MyLabs] рог 1: забрано — Золото 40 170', '[MyLabs] рог 1: запущено — Золото']))))

# 4. Аккаунт: ресурсы персонажа и список персонажей с пояснениями
d4 = {'chars': CHARS_T, 'sel': 2, 'ready': 2, 'card': CARD_T}
v1, _ = view(d4, (257, 44, 824, 136), zone=(520, 96, 1540, 270), valign='top')
v2, (lx, ly, ls) = view(d4, (0, 44, 256, 252), zone=(520, 300, 1060, 820), smax=2.1, valign='top')
v2 = v2.replace('left:%.0fpx' % lx, 'left:%.0fpx' % 546, 1)
notes = ''
for i, (cls, pill, text) in enumerate((('ok', 'Готово: 2', 'добычу можно забирать'), ('time', '5 дн.', 'до ближайшего готового рога'),
                                       ('warn', 'Ждут: 1', 'рог простаивает, ждёт запуска'))):
    y = ly + (80 + 4 + 32 * i + 15 - 44) * ls - 16
    badge = ('<span class="nb %s">%s</span>' % (cls, pill))
    notes += '<div class="callout" style="left:%.0fpx;top:%.0fpx"><i></i>%s<span>— %s</span></div>' % (546 + 256 * ls + 18, y, badge, text)
cards.append(('4-account', page(
    4, 'Аккаунт', 'Весь аккаунт сразу', 52,
    'Данные общие для всех персонажей: проверяйте и назначайте, не перезаходя.',
    [(timg('horn.png'), 'По каждому: готово, простаивает или сколько ждать'),
     (timg('res-embrium.png'), 'Шесть ресурсов лабиринта у каждого персонажа'),
     (timg('faction-empire.png'), 'Лига и Империя — в одном списке')], v1 + v2 + notes)))

# 5. Сундучок
v, _ = view({'chars': CHARS, 'sel': 0, 'ready': 2, 'card': card2(chestOpen=True),
             'menu': {'x': 214, 'y': 478 - 2 - (8 + 26 * 5), 'items': CHEST_MENU}}, (257, 322, 824, 676))
cards.append(('5-chest', page(
    5, 'Сундучок хранителя', 'Сундучок откроется сам', 50,
    'Выберите, что брать из сундучка хранителя подземелий, — аддон откроет все сундучки в сумке сразу.',
    [(timg('res-gold.png'), 'Золото, слеза дракона, коралл или гранит'),
     (timg('faction-league.png'), 'Свой выбор у каждого персонажа'),
     (timg('chest.png'), 'Вся стопка — одним действием')],
    v + chat(620, ['[MyLabs] сундучки хранителя открыты: 4 шт. — Коралл']))))

# 6. Новый рог: ресурсы сверху, расчёт снизу
d6 = {'chars': CHARS_T, 'sel': 2, 'ready': 2, 'card': CARD_T}
v1, _ = view(d6, (257, 44, 824, 136), zone=(520, 150, 1540, 330), valign='top')
v2, _ = view(d6, (257, 566, 824, 676), zone=(520, 350, 1540, 760), valign='top')
cards.append(('6-newhorn', page(
    6, 'Новый рог изобилия', 'Хватит&nbsp;ли на&nbsp;новый рог', 52,
    'Цену следующего рога называет прораб. Аддон считает, чего не хватает и чем это закрыть.',
    [(timg('res-coral.png'), 'Сколько коралла нужно и сколько есть'),
     (timg('res-embrium.png'), 'Сколько эмбриума уйдёт на обмен'),
     (tile('✓'), 'Итог одной строкой: можно строить или нет')], v1 + v2)))

for name, doc in cards:
    hp = os.path.join(OUT, name + '.html')
    open(hp, 'w', encoding='utf-8').write(doc)
    png = os.path.join(OUT, 'MyLabs-%s.png' % name)
    subprocess.run(['google-chrome', '--headless=new', '--no-sandbox', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
                    '--window-size=1600,900', '--screenshot=' + png, 'file://' + hp], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(png)
