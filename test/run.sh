#!/bin/sh
# Проверка скриптов на заглушках: сборка -> дерево виджетов -> прогон в Windows-1251 (как в игре)
#   sh test/run.sh [папка сборки]          обычная сборка
#   ALLODS_DEBUG=1 sh test/run.sh          отладочная сборка
# Нужны Python 3 (numpy, Pillow), rsvg-convert, iconv и texlua или luajit (LUA=<путь> — указать свой).
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-$HERE/out}
PY=${PYTHON:-}
if [ -z "$PY" ]; then
	for c in python3 python; do
		if "$c" -c "import sys; sys.exit(sys.version_info[0] != 3)" 2>/dev/null; then PY=$c; break; fi
	done
fi
[ -n "$PY" ] || { echo "не найден Python 3 (можно указать PYTHON=<путь>)"; exit 1; }
if [ -z "$LUA" ]; then
	for c in texlua luajit; do
		if command -v "$c" >/dev/null 2>&1; then LUA=$c; break; fi
	done
fi
[ -n "$LUA" ] || { echo "не найден texlua или luajit (можно указать LUA=<путь>)"; exit 1; }
"$PY" "$HERE/gen/assemble.py" "$OUT" | tail -2
"$PY" "$HERE/gen/tree.py" "$OUT/MyLabs" "$OUT/tree.lua" > /dev/null
iconv -f utf-8 -t cp1251 "$HERE/test/run.lua" > "$OUT/run1251.lua"
"$LUA" "$OUT/run1251.lua" "$OUT/MyLabs/Scripts" "$OUT/tree.lua" > "$OUT/test.log" || { iconv -f cp1251 -t utf-8 "$OUT/test.log"; exit 1; }
iconv -f cp1251 -t utf-8 "$OUT/test.log"
