#!/usr/bin/env bash
# Corre los tests unitarios headless del núcleo de simulación.
set -u
cd "$(dirname "$0")/.."
timeout 120 godot --headless --path . --import >/dev/null 2>&1 || true
timeout 900 godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -v -e '^$' -e '^Godot Engine'
exit ${PIPESTATUS[0]}
