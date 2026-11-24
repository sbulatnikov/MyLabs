"""Сборка ресурсов MyLabs: виджеты, тексты, текстуры.

Размеры в макете — в «пикселях макета»; в игре всё умножается на S (как в BestAutoAccept и RPL, 1.2).
"""
import os, sys, shutil
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tex as T
import xdb as X
from xdb import placement as PL, fmt

S = 1.2


def P(v):
    return int(round(v * S))


OUT = sys.argv[1]
PREV = sys.argv[2]
ASSETS = sys.argv[3]
for d in ('Widgets', 'Texts'):
    shutil.rmtree(os.path.join(OUT, d), ignore_errors=True)
shutil.rmtree(PREV, ignore_errors=True)
X.setup(OUT, PREV)

# ------------------------------------------------------------------ палитра (общая для аддонов семейства)
ACC = '#BB1ABD'; ACC_B = '#D045D2'; ACC_I = '#E58BE7'; ACC_T = '#F2B8F3'
SEG_ON = '#3A1440'; CHIP_BG = '#2C1230'; CHIP_BR = '#6A2A6E'
BG_WIN = '#17141B'; BG_HDR = '#1D1922'; BG_HOVER = '#1F1A24'; BG_OFF = '#221D27'; BG_IN = '#100E13'
BR_WIN = '#3A2F42'; BR_CTL = '#3A3141'; LINE = '#2A2330'
GOLD = '#D9BE7A'; TXT = '#ECE6EF'; TXT2 = '#BDB4C4'; TXT_OFF = '#8C8393'; TXT_DIS = '#5E5664'
AMBER = '#F5B841'; AMBER_BG = '#2E2410'; AMBER_BR = '#6A5420'
OK = '#6FD99A'; OK_BG = '#12301F'; OK_BR = '#2E6B47'
TIP_BG = '#0F0D12'; TIP_BR = '#4A3B52'

F_TITLE = ('AllodsFantasy', 18)
F_SECT = ('AllodsFantasy', 16)
F_BODY = ('AllodsSystem', 16)
F_SMALL = ('AllodsSystem', 14)
F_NUM = ('ContentNarrowBold', 16)

# ------------------------------------------------------------------ текстуры


def box(w, h, r, fill=None, border=None, bw=1.2):
    return T.rrect(T.blank(w, h), 0, 0, w, h, r, fill=fill, border=border, bw=bw)


def fr(name, fill, border=None, size=32, r=6, e=None, bw=1.2):
    return X.frame(name, box(size, size, r, fill, border, bw), e or (r + 3))


def solid(name, color, alpha=1.0):
    img = T.blank(4, 4)
    img[...] = T.hex2rgba(color, alpha)
    return X.stretch(name, img)


TRANSP = X.stretch('Transparent', T.blank(4, 4))
LINE_TEX = solid('Line', LINE)
WIN_FRAME = fr('WindowFrame', BG_WIN, BR_WIN, 128, 12, 16)
HDR_FRAME = X.frame('HeaderBack', T.rrect(T.blank(64, 64), 1.2, 1.2, 62.8, 64, (11, 11, 0, 0), fill=BG_HDR), 14)
ACCENT_MARK = X.stretch('AccentMark', box(16, 16, 4, ACC))
DOT = X.stretch('Dot', box(8, 8, 4, ACC_B))
LIST_FRAME = fr('ListFrame', BG_IN, LINE, 64, 7)
MENU_FRAME = fr('MenuFrame', TIP_BG, TIP_BR, 64, 7)
CHIP = fr('Chip', BG_HDR, LINE, 32, 6, 9)
NO_CHIP = fr('NoChip', BG_OFF, BR_CTL, 32, 5, 8)
OWNER_CHIP = fr('OwnerChip', BG_OFF, BR_CTL, 32, 5, 8)
PILL = {
    'ok': fr('PillOk', OK_BG, OK_BR, 32, 11, 12), 'warn': fr('PillWarn', AMBER_BG, AMBER_BR, 32, 11, 12),
    'mute': fr('PillMute', BG_OFF, BR_CTL, 32, 11, 12), 'acc': fr('PillAcc', CHIP_BG, CHIP_BR, 32, 11, 12),
}
FIELD = {
    'n': fr('Field', BG_IN, BR_CTL, 32, 6, 9), 'h': fr('FieldHover', '#17131B', '#5A4A62', 32, 6, 9),
    'open': fr('FieldOpen', '#17131B', ACC_I, 32, 6, 9), 'attn': fr('FieldAttn', CHIP_BG, ACC, 32, 6, 9),
    'attnH': fr('FieldAttnHover', '#38163D', ACC_B, 32, 6, 9), 'dis': fr('FieldDisabled', '#141117', LINE, 32, 6, 9),
}
ROW = {'h': fr('RowHover', BG_HOVER, None, 32, 6, 9), 'sel': fr('RowSelected', CHIP_BG, CHIP_BR, 32, 6, 9),
       'selH': fr('RowSelectedHover', '#38163D', ACC, 32, 6, 9)}
ITEM = {'h': fr('ItemHover', '#241D2A', None, 32, 5, 8), 'sel': fr('ItemSelected', SEG_ON, None, 32, 5, 8),
        'selH': fr('ItemSelectedHover', '#46184D', None, 32, 5, 8)}
HB_H = fr('IconBtnHover', BG_HOVER, '#3A3141', 32, 6, 9)
MAIN = {
    'n': X.stretch('MainNormal', box(64, 64, 13, '#1E1A22', BR_CTL, 1.6)),
    'h': X.stretch('MainHover', box(64, 64, 13, '#28222D', ACC_B, 1.6)),
    'on': X.stretch('MainOpen', box(64, 64, 13, CHIP_BG, ACC, 1.6)),
    'onH': X.stretch('MainOpenHover', box(64, 64, 13, '#3A1640', ACC_B, 1.6)),
}
BADGE = X.stretch('CountBadge', box(40, 32, 9, ACC, '#EFA0F0', 1.6))
BAR_BACK = X.stretch('BarBack', box(32, 4, 2, BR_CTL))
BAR_FILL = X.stretch('BarFill', box(32, 4, 2, ACC))

# ------------------------------------------------------------------ иконки


def png(name, w, h):
    """Картинка из игры, вписанная в холст w x h (кратно 4) с сохранением пропорций."""
    im = Image.open(os.path.join(ASSETS, name)).convert('RGBA')
    k = min(w / im.width, h / im.height)
    nw, nh = max(1, int(round(im.width * k))), max(1, int(round(im.height * k)))
    im = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    canvas.paste(im, ((w - nw) // 2, (h - nh) // 2))
    a = np.asarray(canvas).astype(np.float64) / 255.0
    # цвет прозрачных пикселей — средний цвет картинки, чтобы края в DXT не темнели
    vis = a[..., 3] > 0.05
    mean = a[vis][:, :3].mean(0) if vis.any() else np.zeros(3)
    a[..., :3] = np.where(a[..., 3:4] > 0.003, a[..., :3], mean)
    return a


def svg(paths, color, size=32, stroke=1.6, fill=False):
    return T.svg_icon(paths, color, size, stroke, fill=fill)


RES_ICONS = {
    'RES_GOLD': 'res-gold.png', 'RES_TEAR1': 'res-tears-shining.png', 'RES_TEAR2': 'res-tears-glowing.png',
    'RES_TEAR3': 'res-tears-sparkling.png', 'RES_GRANITE': 'res-granite.png', 'RES_CORAL': 'res-coral.png',
    'RES_EMBRIUM': 'res-embrium.png', 'RES_METEOR': 'res-meteorite.png', 'RES_SUPPLIES': 'res-supplies.png',
    'RES_NONE': 'res-none.png', 'CHEST': 'chest.png',
}
for key, f in RES_ICONS.items():
    X.icon(key, 'Icon_' + key.title().replace('_', ''), png(f, 32, 32))
# «Плата наёмникам»: картинки в распакованных ресурсах нет — рисуем знак, в игре поверх ставится картинка валюты
X.icon('RES_MERCS', 'Icon_ResMercs', svg(['M3 3l8.5 8.5M9.5 13.5l4-4M12 12l1.5 1.5M13 3l-8.5 8.5M6.5 13.5l-4-4M4 12l-1.5 1.5'], GOLD, 32, 1.5))
X.icon('FAC_LEAGUE', 'Icon_FacLeague', png('faction-league.png', 64, 48))
X.icon('FAC_EMPIRE', 'Icon_FacEmpire', png('faction-empire.png', 64, 48))
X.icon('FAC_NONE', 'Icon_FacNone', T.paste(T.blank(64, 48), svg(['M5.5 6a2.5 2.5 0 1 1 3.5 2.3c-.7.4-1 .9-1 1.7M8 12.5v.3'], TXT_OFF, 48, 1.5), 8, 0))
X.icon('ARROW_ON', 'Icon_ArrowOn', svg(['M3 8h10M9 4l4 4-4 4'], ACC_I, 32, 1.8))
X.icon('ARROW_OFF', 'Icon_ArrowOff', svg(['M3 8h10M9 4l4 4-4 4'], TXT_DIS, 32, 1.6))
X.write_icon_group()
CHEVRON = X.stretch('Chevron', svg(['M4 6l4 4 4-4'], TXT2, 32, 1.8))
CLOSE_IC = X.stretch('Close', svg(['M4 4l8 8M12 4l-8 8'], TXT2, 32, 1.8))
HORN_IC = X.stretch('HornIcon', png('horn.png', 64, 64))


def ic(key):
    return 'Textures/Icon_%s.Stretch.(WidgetLayerSimpleTexture).xdb' % key.title().replace('_', '')


# ------------------------------------------------------------------ помощники


def F(name, f, color, alignx='left', **kw):
    return fmt(name, f[0], f[1], color, alignx, **kw)


def tv(name, x, y, w, h, fref, **kw):
    return X.textview(name, PL(x, y, w, h), '../Texts/%s.txt' % fref, **kw)


def img(name, x, y, w, h, href, **kw):
    kw.setdefault('transparent', True)
    return X.panel(name, PL(x, y, w, h), back=href, **kw)


def pill(name, x, y, w, h, kind, fref, **kw):
    """Плашка: рамка + текст по центру (текст — дочерний <name>Text)."""
    X.textview(name + 'Text', PL(0, 0, w, h), '../Texts/%s.txt' % fref)
    kw.setdefault('transparent', True)
    return X.panel(name, PL(x, y, w, h), back=PILL[kind], children=[name + 'Text.(WidgetTextView).xdb'], **kw)


# форматы текста
F('Title', F_TITLE, TXT)
F('Name', F_TITLE, TXT)
F('Sect', F_SECT, GOLD)
F('Body', F_BODY, TXT)
F('BodyDim', F_BODY, TXT_OFF)
F('BodyRight', F_BODY, TXT, 'right')
F('Small', F_SMALL, TXT_OFF)
F('SmallRight', F_SMALL, TXT_OFF, 'right')
F('SmallCenter', F_SMALL, TXT_OFF, 'center')
F('Num', F_NUM, TXT, 'right')
F('NumDim', F_NUM, TXT2, 'right')
F('NumWarn', F_NUM, AMBER, 'right')
F('NumOk', F_NUM, OK, 'right')
F('NumCenter', F_NUM, TXT2, 'center')
F('ChipValue', F_SMALL, TXT, 'right')
F('PillOk', F_SMALL, OK, 'center')
F('PillWarn', F_SMALL, AMBER, 'center')
F('PillMute', F_SMALL, TXT_OFF, 'center')
F('PillAcc', F_SMALL, ACC_T, 'center')
F('Badge', F_NUM, '#FFFFFF', 'center')

# ------------------------------------------------------------------ размеры окна (макет)
W_, H_, HDR = 860, 676, 40
WW, WH = P(W_), P(H_)
LEFT_X, LEFT_W = 12, 268          # в строке персонажа — колонка посещений лабиринтов
CARD_X, CARD_W = 304, 544
PANE_Y, PANE_H = 52, 612
ROWS = 12                      # рогов у персонажа не больше двенадцати
CHARS = 12
MENU_ITEMS = 8

# ------------------------------------------------------------------ кнопка на экране
X.panel('MLButtonIcon', PL(0, 0, 30, 30, 'WIDGET_ALIGN_CENTER', 'WIDGET_ALIGN_CENTER'), back=HORN_IC, transparent=True)
X.button('MLButton', PL(2, 2, 40, 40),
         [{'normal': MAIN['n'], 'hover': MAIN['h'], 'pressed': MAIN['h'], 'reaction': 'ml_main'},
          {'normal': MAIN['on'], 'hover': MAIN['onH'], 'pressed': MAIN['onH'], 'reaction': 'ml_main'}],
         children=['MLButtonIcon.(WidgetPanel).xdb'])
X.textview('MLBadgeText', PL(0, 0, 22, 17), '../Texts/Badge.txt')
X.panel('MLBadge', PL(24, 28, 22, 17), back=BADGE, children=['MLBadgeText.(WidgetTextView).xdb'], transparent=True, visible=False)
X.panel('MLHost', PL(300, 12, 48, 48), children=['MLButton.(WidgetButton).xdb', 'MLBadge.(WidgetPanel).xdb'],
        pick_children=True, priority=800)

# ------------------------------------------------------------------ шапка окна
F('TitleText', F_TITLE, TXT, literal='MyLabs')
img('AccentMark', P(12), P(15), 12, 12, ACCENT_MARK)
tv('TitleText', P(28), 0, P(90), P(HDR), 'TitleText')
pill('ReadyBadge', P(118), P(10), P(92), P(20), 'ok', 'PillOk')
pill('ReadyBadgeNone', P(118), P(10), P(92), P(20), 'mute', 'PillMute')
img('HdrCloseIcon', (P(28) - P(16)) // 2, (P(28) - P(16)) // 2, P(16), P(16), CLOSE_IC)
X.button('HdrClose', PL(WW - P(6) - P(28), P(6), P(28), P(28)),
         [{'normal': TRANSP, 'hover': HB_H, 'pressed': HB_H, 'reaction': 'ml_close'}],
         children=['HdrCloseIcon.(WidgetPanel).xdb'])
X.panel('Header', PL(0, 0, WW, P(HDR)), back=HDR_FRAME,
        children=['AccentMark.(WidgetPanel).xdb', 'TitleText.(WidgetTextView).xdb', 'ReadyBadge.(WidgetPanel).xdb',
                  'ReadyBadgeNone.(WidgetPanel).xdb', 'HdrClose.(WidgetButton).xdb'])
img('HeaderLine', 1, P(HDR) - 1, WW - 2, 1, LINE_TEX)

# ------------------------------------------------------------------ список персонажей
LW = P(LEFT_W)
CRH = P(30)                    # высота строки
CRW = LW - 2 * P(4)
img('CharDot', P(4), (CRH - 6) // 2, 6, 6, DOT)
img('CharFac', P(14), (CRH - P(20)) // 2, P(27), P(20), ic('FAC_LEAGUE'))
tv('CharName', P(47), 0, P(103), CRH, 'Body')
tv('CharVisits', P(152), 0, P(32), CRH, 'SmallCenter')      # посещения лабиринтов за неделю: «3/5»
pill('CharPillOk', CRW - P(6) - P(64), (CRH - P(20)) // 2, P(64), P(20), 'ok', 'PillOk', visible=False)
pill('CharPillWarn', CRW - P(6) - P(64), (CRH - P(20)) // 2, P(64), P(20), 'warn', 'PillWarn', visible=False)
tv('CharTime', CRW - P(6) - P(70), 0, P(70), CRH, 'SmallRight')
char_rows = []
for i in range(CHARS):
    char_rows.append(X.button(
        'CharRow%d' % (i + 1), PL(P(4), P(4) + P(32) * i, CRW, CRH),
        [{'normal': TRANSP, 'hover': ROW['h'], 'pressed': ROW['h'], 'reaction': 'ml_char', 'push': 0},
         {'normal': ROW['sel'], 'hover': ROW['selH'], 'pressed': ROW['selH'], 'reaction': 'ml_char', 'push': 0}],
        children=['CharDot.(WidgetPanel).xdb', 'CharFac.(WidgetPanel).xdb', 'CharName.(WidgetTextView).xdb',
                  'CharVisits.(WidgetTextView).xdb',
                  'CharPillOk.(WidgetPanel).xdb', 'CharPillWarn.(WidgetPanel).xdb', 'CharTime.(WidgetTextView).xdb'],
        visible=False))
tv('CharsTitle', 0, 0, P(150), P(22), 'Sect')
tv('CharsCount', LW - P(60), 0, P(60), P(22), 'SmallRight')
X.panel('CharsBox', PL(0, P(28), LW, P(PANE_H - 28)), back=LIST_FRAME, children=char_rows, pick_children=True)
X.panel('LeftPane', PL(P(LEFT_X), P(PANE_Y), LW, P(PANE_H)),
        children=['CharsTitle.(WidgetTextView).xdb', 'CharsCount.(WidgetTextView).xdb', 'CharsBox.(WidgetPanel).xdb'], pick_children=True)
img('VLine', P(LEFT_X + LEFT_W + 12), P(HDR), 1, WH - P(HDR) - 1, LINE_TEX)

# ------------------------------------------------------------------ карточка персонажа
CW = P(CARD_W)
card = []
card.append(img('CardFac', 0, P(3), P(40), P(30), ic('FAC_LEAGUE')))
card.append(tv('CardName', P(50), 0, P(300), P(36), 'Name'))
card.append(pill('HereBadge', CW - P(76), P(8), P(76), P(20), 'acc', 'PillAcc', visible=False))
card.append(tv('CardSeen', CW - P(220), P(8), P(220), P(20), 'SmallRight'))
card.append(tv('CardVisits', CW - P(260), P(27), P(260), P(17), 'SmallRight'))

# ресурсы: шесть плашек в ряд
GAP = P(6)
CHW = (CW - 5 * GAP) // 6
CHH = P(30)
img('ChipIcon', P(6), (CHH - P(18)) // 2, P(18), P(18), ic('RES_CORAL'))
tv('ChipValue', P(26), 0, CHW - P(26) - P(7), CHH, 'ChipValue')
for i in range(6):
    card.append(X.panel('Chip%d' % (i + 1), PL(i * (CHW + GAP), P(46), CHW, CHH), back=CHIP,
                        children=['ChipIcon.(WidgetPanel).xdb', 'ChipValue.(WidgetTextView).xdb']))
card.append(img('Line1', 0, P(86), CW, 1, LINE_TEX))

# рога
card.append(tv('HornsTitle', 0, P(94), P(240), P(22), 'Sect'))
card.append(tv('HornsCount', CW - P(140), P(94), P(140), P(22), 'SmallRight'))
C_NO, C_RUN, C_ARROW, C_ASSIGN, C_STATE = 8, 38, 192, 214, 416     # x колонок внутри карточки
ASSIGN_W, STATE_W = 190, 120
card.append(tv('ColNo', P(C_NO), P(118), P(22), P(18), 'SmallCenter'))
card.append(tv('ColRun', P(C_RUN), P(118), P(140), P(18), 'Small'))
card.append(tv('ColAssign', P(C_ASSIGN), P(118), P(160), P(18), 'Small'))
card.append(tv('ColLeft', P(C_STATE), P(118), P(STATE_W), P(18), 'SmallRight'))

RH = P(26)
RW = CW - 4
X.textview('HornNoText', PL(0, 0, P(22), P(20)), '../Texts/NumCenter.txt')
X.panel('HornNo', PL(P(C_NO) - 2, (RH - P(20)) // 2, P(22), P(20)), back=NO_CHIP, children=['HornNoText.(WidgetTextView).xdb'], transparent=True)
img('RunIcon', P(C_RUN) - 2, (RH - P(18)) // 2, P(18), P(18), ic('RES_GOLD'))
tv('RunName', P(C_RUN + 24) - 2, 0, P(126), RH, 'Body')
tv('RunNameDim', P(C_RUN) - 2, 0, P(150), RH, 'BodyDim', visible=False)
img('Arrow', P(C_ARROW) - 2, (RH - P(14)) // 2, P(14), P(14), ic('ARROW_OFF'))
AH = P(22)
AW = P(ASSIGN_W)
img('AssignIcon', P(6), (AH - P(16)) // 2, P(16), P(16), ic('RES_GOLD'))
tv('AssignName', P(28), 0, AW - P(28) - P(20), AH, 'Body')
img('AssignChevron', AW - P(18), (AH - P(12)) // 2, P(12), P(12), CHEVRON)
field_vars = lambda r: [
    {'normal': FIELD['n'], 'hover': FIELD['h'], 'pressed': FIELD['h'], 'disabled': FIELD['dis'], 'reaction': r, 'push': 0},
    {'normal': FIELD['open'], 'hover': FIELD['open'], 'pressed': FIELD['open'], 'disabled': FIELD['dis'], 'reaction': r, 'push': 0},
    {'normal': FIELD['attn'], 'hover': FIELD['attnH'], 'pressed': FIELD['attnH'], 'disabled': FIELD['dis'], 'reaction': r, 'push': 0},
]
X.button('AssignBtn', PL(P(C_ASSIGN) - 2, (RH - AH) // 2, AW, AH), field_vars('ml_assign'),
         children=['AssignIcon.(WidgetPanel).xdb', 'AssignName.(WidgetTextView).xdb', 'AssignChevron.(WidgetPanel).xdb'])
SX, SW_ = P(C_STATE) - 2, P(STATE_W)
PW, PH = P(96), P(20)
tv('HornTime', SX, 0, SW_, RH - P(5), 'Num')
BARW = P(80)
img('HornBarFill', 0, 0, BARW, 3, BAR_FILL)
X.panel('HornBar', PL(SX + SW_ - BARW, RH - P(5), BARW, 3), back=BAR_BACK, children=['HornBarFill.(WidgetPanel).xdb'], transparent=True)
for kind in ('Ok', 'Warn', 'Mute'):
    pill('HornPill' + kind, SX + SW_ - PW, (RH - PH) // 2, PW, PH, kind.lower(), 'Pill' + kind,
         transparent=False, visible=False)
horn_children = ['HornNo.(WidgetPanel).xdb', 'RunIcon.(WidgetPanel).xdb', 'RunName.(WidgetTextView).xdb', 'RunNameDim.(WidgetTextView).xdb',
                 'Arrow.(WidgetPanel).xdb', 'AssignBtn.(WidgetButton).xdb', 'HornTime.(WidgetTextView).xdb', 'HornBar.(WidgetPanel).xdb',
                 'HornPillOk.(WidgetPanel).xdb', 'HornPillWarn.(WidgetPanel).xdb', 'HornPillMute.(WidgetPanel).xdb']
horn_rows = [X.panel('HornRow%d' % (i + 1), PL(2, P(3) + RH * i, RW, RH), children=horn_children, pick_children=True, visible=False)
             for i in range(ROWS)]
BOX_Y, BOX_H = P(138), P(6) + RH * ROWS
# пока о рогах ничего не известно — одна строка-пояснение на всю ширину
tv('HornsHint', P(12), P(3), CW - P(24), RH, 'BodyDim', visible=False)
card.append(X.panel('HornsBox', PL(0, BOX_Y, CW, BOX_H), back=LIST_FRAME, children=['HornsHint.(WidgetTextView).xdb'] + horn_rows,
                    pick_children=True))

# сундучок хранителя
y = BOX_Y + BOX_H + P(10)
card.append(img('Line2', 0, y, CW, 1, LINE_TEX))
y += P(8)
CHEST_H = P(32)
card.append(img('ChestIcon', 0, y + (CHEST_H - P(24)) // 2, P(24), P(24), ic('CHEST')))
card.append(tv('ChestTitle', P(32), y, P(176), CHEST_H, 'Sect'))
img('ChestBtnIcon', P(6), (P(24) - P(16)) // 2, P(16), P(16), ic('RES_CORAL'))
tv('ChestBtnName', P(28), 0, AW - P(28) - P(20), P(24), 'Body')
img('ChestChevron', AW - P(18), (P(24) - P(12)) // 2, P(12), P(12), CHEVRON)
card.append(X.button('ChestBtn', PL(P(C_ASSIGN), y + (CHEST_H - P(24)) // 2, AW, P(24)), field_vars('ml_chest'),
                     children=['ChestBtnIcon.(WidgetPanel).xdb', 'ChestBtnName.(WidgetTextView).xdb', 'ChestChevron.(WidgetPanel).xdb']))
card.append(tv('ChestNote', P(C_STATE) - P(4), y, P(STATE_W) + P(4), CHEST_H, 'SmallRight'))
CHEST_BTN_Y = y + (CHEST_H - P(24)) // 2
y += CHEST_H + P(8)
card.append(img('Line3', 0, y, CW, 1, LINE_TEX))

# новый рог
y += P(8)
card.append(tv('NewTitle', 0, y, P(260), P(22), 'Sect'))
NBW = P(230)
for kind in ('Ok', 'Warn', 'Mute'):
    card.append(pill('NewBadge' + kind, P(C_STATE + STATE_W) - NBW, y + P(1), NBW, P(20), kind.lower(), 'Pill' + kind,
                     transparent=False, visible=False))
y += P(24)
N_NEED, N_HAVE, N_LACK, NCW = 272, 360, 448, 88       # правый край — как у колонки «Осталось»
card.append(tv('NewColNeed', P(N_NEED), y, P(NCW), P(16), 'SmallRight'))
card.append(tv('NewColHave', P(N_HAVE), y, P(NCW), P(16), 'SmallRight'))
card.append(tv('NewColLack', P(N_LACK), y, P(NCW), P(16), 'SmallRight'))
y += P(18)
NRH = P(24)
img('NewIcon', 0, (NRH - P(18)) // 2, P(18), P(18), ic('RES_CORAL'))
tv('NewName', P(26), 0, P(240), NRH, 'Body')
tv('NewNeed', P(N_NEED), 0, P(NCW), NRH, 'Num')
tv('NewHave', P(N_HAVE), 0, P(NCW), NRH, 'NumDim')
tv('NewLackWarn', P(N_LACK), 0, P(NCW), NRH, 'NumWarn')
tv('NewLackOk', P(N_LACK), 0, P(NCW), NRH, 'NumOk')
new_children = ['NewIcon.(WidgetPanel).xdb', 'NewName.(WidgetTextView).xdb', 'NewNeed.(WidgetTextView).xdb', 'NewHave.(WidgetTextView).xdb',
                'NewLackWarn.(WidgetTextView).xdb', 'NewLackOk.(WidgetTextView).xdb']
for i in range(2):
    card.append(X.panel('NewRow%d' % (i + 1), PL(0, y + NRH * i, CW, NRH), children=new_children))
y += NRH * 2
assert y <= P(PANE_H), (y, P(PANE_H))

X.panel('Card', PL(P(CARD_X), P(PANE_Y), CW, P(PANE_H)), children=card, pick_children=True)

# ------------------------------------------------------------------ выпадающий список (один на окно)
MW = AW
MIH = P(26)
MIW = MW - 2 * P(4)
img('MenuIcon', P(6), (MIH - P(16)) // 2, P(16), P(16), ic('RES_GOLD'))
tv('MenuName', P(28), 0, MIW - P(28) - P(30), MIH, 'Body')
tv('MenuNameDim', P(28), 0, MIW - P(28) - P(30), MIH, 'BodyDim', visible=False)
X.textview('MenuOwnerText', PL(0, 0, P(22), P(18)), '../Texts/NumCenter.txt')
X.panel('MenuOwner', PL(MIW - P(26), (MIH - P(18)) // 2, P(22), P(18)), back=OWNER_CHIP, children=['MenuOwnerText.(WidgetTextView).xdb'],
        transparent=True, visible=False)
menu_items = []
for i in range(MENU_ITEMS):
    menu_items.append(X.button(
        'MenuItem%d' % (i + 1), PL(P(4), P(4) + MIH * i, MIW, MIH),
        [{'normal': TRANSP, 'hover': ITEM['h'], 'pressed': ITEM['h'], 'disabled': TRANSP, 'reaction': 'ml_menu_pick', 'push': 0},
         {'normal': ITEM['sel'], 'hover': ITEM['selH'], 'pressed': ITEM['selH'], 'disabled': TRANSP, 'reaction': 'ml_menu_pick', 'push': 0}],
        children=['MenuIcon.(WidgetPanel).xdb', 'MenuName.(WidgetTextView).xdb', 'MenuNameDim.(WidgetTextView).xdb', 'MenuOwner.(WidgetPanel).xdb'],
        visible=False))
X.panel('Menu', PL(0, 0, MW, P(8) + MIH * MENU_ITEMS), back=MENU_FRAME, children=menu_items, pick_children=False, visible=False, priority=60)
# невидимая кнопка под списком: щелчок мимо списка закрывает его
X.button('MenuCatcher', PL(0, 0, WW, WH), [{'normal': TRANSP, 'reaction': 'ml_menu_close', 'push': 0}], visible=False, priority=50)

X.panel('MLWindow', PL(200, 70, WW, WH), back=WIN_FRAME,
        children=['Header.(WidgetPanel).xdb', 'HeaderLine.(WidgetPanel).xdb', 'VLine.(WidgetPanel).xdb', 'LeftPane.(WidgetPanel).xdb',
                  'Card.(WidgetPanel).xdb', 'MenuCatcher.(WidgetButton).xdb', 'Menu.(WidgetPanel).xdb'],
        visible=False, priority=900)

X.form('MyLabs', ['MLWindow.(WidgetPanel).xdb', 'MLHost.(WidgetPanel).xdb'])

X.text_file('AddonName', 'MyLabs')
X.text_file('AddonDescription', 'Личный лабиринт: рога изобилия, ресурсы и сундучок хранителя по всем персонажам аккаунта')

# геометрия, которая нужна скрипту (положение выпадающего списка)
geo = {
    'S': S, 'WH': WH, 'CARD_X': P(CARD_X), 'CARD_Y': P(PANE_Y), 'BOX_Y': BOX_Y, 'ROW_H': RH, 'ROW_Y0': P(3),
    'ASSIGN_X': P(C_ASSIGN), 'ASSIGN_Y': (RH - AH) // 2, 'ASSIGN_H': AH, 'CHEST_Y': CHEST_BTN_Y, 'CHEST_H': P(24),
    'MENU_W': MW, 'ITEM_H': MIH, 'MENU_PAD': P(4), 'BAR_W': BARW,
}
open(os.path.join(PREV, 'geo.txt'), 'w').write('\n'.join('%s=%s' % kv for kv in sorted(geo.items())))
print('ok', len(os.listdir(X.WID)), 'widgets', len(os.listdir(X.TEXDIR)), 'texture files, card bottom', y, 'of', P(PANE_H))
