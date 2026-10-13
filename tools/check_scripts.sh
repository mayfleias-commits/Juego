#!/usr/bin/env bash
# Compila todos los scripts y muestra errores con archivo y línea.
cd "$(dirname "$0")/.."
timeout 180 godot --headless --path . --import 2>&1 | grep -E -A1 "SCRIPT ERROR|^ERROR" | grep -v -e "^--$" | head -${1:-40}
