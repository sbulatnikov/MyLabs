"""Дерево виджетов собранного аддона -> таблица Lua для проверки скриптов на заглушках."""
import os, re, sys

ADDON, OUT = sys.argv[1], sys.argv[2]
WID = os.path.join(ADDON, 'Widgets')


def tag(x, t, default=None):
    m = re.search(r'<%s>([^<]*)</%s>' % (t, t), x)
    return m.group(1) if m else default


def axis(x, t):
    m = re.search(r'<%s>(.*?)</%s>' % (t, t), x, re.S)
    a = m.group(1) if m else ''
    return int(tag(a, 'Pos', 0)), int(tag(a, 'Size', 0))


def node(fn, depth=0):
    x = open(os.path.join(WID, fn), encoding='utf-8').read()
    kind = re.search(r'\((\w+)\)\.xdb$', fn).group(1)
    px, sx = axis(x, 'X')
    py, sy = axis(x, 'Y')
    ch = re.search(r'<Children>(.*?)</Children>', x, re.S)
    kids = [node(c, depth + 1) for c in re.findall(r'href="([^"]+)"', ch.group(1))] if ch else []
    variants = len(re.findall(r'<Item>', re.search(r'<Variants>(.*?)</Variants>', x, re.S).group(1))) if '<Variants>' in x else 0
    reactions = sorted(set(re.findall(r'<(?:Reaction|reactionOnPointing|forceReactionOnPointing)>(\w+)<', x)))
    pad = '\t' * depth
    return '%s{ name = "%s", kind = "%s", x = %d, y = %d, w = %d, h = %d, visible = %s, variants = %d, reactions = { %s }, children = {%s%s} }' % (
        pad, tag(x, 'Name'), kind, px, py, sx, sy, 'false' if '<Visible>false</Visible>' in x else 'true', variants,
        ', '.join('"%s"' % r for r in reactions), ('\n' + ',\n'.join(kids) + '\n' + pad) if kids else '', '')


icons = re.findall(r'<name>(\w+)</name>', open(os.path.join(WID, 'Textures', 'Icons.(UIRelatedTextures).xdb'), encoding='utf-8').read())
open(OUT, 'w', encoding='utf-8').write('return {\nicons = { %s },\nform =\n%s\n}\n' % (', '.join('"%s"' % i for i in icons), node('MainForm.(WidgetForm).xdb', 1)))
print('tree ->', OUT)
