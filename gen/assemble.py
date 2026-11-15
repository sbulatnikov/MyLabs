"""Собирает папку аддона MyLabs: ресурсы (build.py), скрипты в cp1251, AddonDesc, проверка ссылок.

  python3 gen/assemble.py <папка-результат> [папка с картинками игры]
Результат: <папка>/MyLabs (аддон) и <папка>/preview (PNG текстур для предпросмотра).
"""
import os, re, subprocess, sys, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)
DEST = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(SRC, 'out')
ASSETS = sys.argv[2] if len(sys.argv) > 2 else os.path.join(SRC, 'assets')
OUT = os.path.join(DEST, 'MyLabs')
PREV = os.path.join(DEST, 'preview')
VERSION = re.search(r'ML\.VERSION = "([^"]+)"', open(os.path.join(SRC, 'lua', 'Util.lua'), encoding='utf-8').read()).group(1)
SCRIPTS = ['LibDnD', 'Util', 'Core', 'UI', 'Main']
sys.path.insert(0, os.path.join(SRC, 'tools'))  # своя копия: репозиторий собирается сам по себе
import strip_debug  # noqa: E402  — отладка только в сборке с ALLODS_DEBUG=1

shutil.rmtree(OUT, ignore_errors=True)
os.makedirs(OUT)
subprocess.check_call([sys.executable, os.path.join(HERE, 'build.py'), OUT, PREV, ASSETS])

sd = os.path.join(OUT, 'Scripts')
os.makedirs(sd, exist_ok=True)
for s in SCRIPTS:
    raw = open(os.path.join(SRC, 'lua', s + '.lua'), 'rb').read()
    if s == 'LibDnD':
        data = raw                                   # чужая библиотека, уже в cp1251
    else:
        text = strip_debug.strip(raw.decode('utf-8').replace('\r\n', '\n'), where=s + '.lua')
        data = text.replace('\n', '\r\n').encode('cp1251')
    open(os.path.join(sd, s + '.lua'), 'wb').write(data)

desc = '''<?xml version="1.0" encoding="UTF-8" ?>
<UIAddon>
	<Name>MyLabs</Name>
	<AutoStart>true</AutoStart>
	<userAddonInfo>
		<name href="Texts/AddonName.txt" />
		<description href="Texts/AddonDescription.txt" />
		<author>NoMercy</author>
		<version>%s</version>
	</userAddonInfo>
	<ScriptFileRefs>
%s	</ScriptFileRefs>
	<Form href="Widgets/MainForm.(WidgetForm).xdb" />
	<texturesGroups>
		<Item>
			<groupName>Icons</groupName>
			<textures href="Widgets/Textures/Icons.(UIRelatedTextures).xdb" />
		</Item>
	</texturesGroups>
</UIAddon>
''' % (VERSION, ''.join('\t\t<Item href="Scripts/%s.lua" />\n' % s for s in SCRIPTS))
open(os.path.join(OUT, 'AddonDesc.(UIAddon).xdb'), 'w', encoding='utf-8').write(desc)
# имя аддона в игре — всегда с версией: «MyLabs v<версия>»
open(os.path.join(OUT, 'Texts', 'AddonName.txt'), 'wb').write(b'\xff\xfe' + ('MyLabs v' + VERSION).encode('utf-16-le'))

# проверка ссылок
bad = 0
for root, _, files in os.walk(OUT):
    for f in files:
        if not f.endswith('.xdb'):
            continue
        p = os.path.join(root, f)
        for href in re.findall(r'href="([^"#]+)', open(p, encoding='utf-8').read()):
            if href and not os.path.exists(os.path.normpath(os.path.join(root, href))):
                print('BROKEN', os.path.relpath(p, OUT), '->', href)
                bad += 1
# все виджеты достижимы из описания аддона
seen = set()


def walk(path):
    if path in seen:
        return
    seen.add(path)
    for href in re.findall(r'href="([^"#]+\.xdb)"', open(path, encoding='utf-8').read()):
        q = os.path.normpath(os.path.join(os.path.dirname(path), href))
        if os.path.exists(q):
            walk(q)


walk(os.path.join(OUT, 'AddonDesc.(UIAddon).xdb'))
orphans = [f for f in os.listdir(os.path.join(OUT, 'Widgets')) if f.endswith('.xdb') and os.path.join(OUT, 'Widgets', f) not in seen]
# имена виджетов, которые ищет скрипт, должны существовать
names = set(re.findall(r'<Name>([^<]+)</Name>', ''.join(open(os.path.join(OUT, 'Widgets', f), encoding='utf-8').read()
                                                         for f in os.listdir(os.path.join(OUT, 'Widgets')) if f.endswith('.xdb'))))
ui = open(os.path.join(SRC, 'lua', 'UI.lua'), encoding='utf-8').read() + open(os.path.join(SRC, 'lua', 'Main.lua'), encoding='utf-8').read()
missing = sorted(set(n for n in re.findall(r'(?:W|Child)\(\s*(?:[\w.\[\] ]+,\s*)?"(\w+)"(?!\s*\.\.)', ui) if n not in names))
missing += sorted(set(n + '*' for n in re.findall(r'(?:W|Child)\(\s*(?:[\w.\[\] ]+,\s*)?"(\w+)"\s*\.\.', ui)
                      if not any(x.startswith(n) and x != n for x in names)))
print('version', VERSION, '| broken refs:', bad, '| orphan widgets:', orphans, '| widgets missing for script:', missing)
print('files:', sum(len(fs) for _, _, fs in os.walk(OUT)))
if bad or orphans or missing:
    sys.exit(1)
