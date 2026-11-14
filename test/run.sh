#!/bin/sh
# Проверка скриптов на заглушках: сборка -> дерево виджетов -> прогон в Windows-1251 (как в игре)
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-$HERE/out}
python3 "$HERE/gen/assemble.py" "$OUT" | tail -2
python3 "$HERE/gen/tree.py" "$OUT/MyLabs" "$OUT/tree.lua" > /dev/null
iconv -f utf-8 -t cp1251 "$HERE/test/run.lua" > "$OUT/run1251.lua"
texlua "$OUT/run1251.lua" "$OUT/MyLabs/Scripts" "$OUT/tree.lua" | iconv -f cp1251 -t utf-8
