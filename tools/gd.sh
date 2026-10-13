#!/usr/bin/env bash
# Ejecuta un script GDScript headless con límite de tiempo y la caché de clases al día.
# Uso: tools/gd.sh <segundos> res://ruta/script.gd [-- args...]
set -u
cd "$(dirname "$0")/.."
T="$1"; shift
SCRIPT="$1"; shift
timeout 120 godot --headless --path . --import >/dev/null 2>&1 || true
timeout "$T" godot --headless --path . --script "$SCRIPT" --quit-after 5 "$@" 2>&1 | grep -v -e '^$' -e '^Godot Engine'
exit ${PIPESTATUS[0]}
