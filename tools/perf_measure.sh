#!/usr/bin/env bash
# Mide cada preset con la build exportada para Linux (mismo .pck que Windows/Android):
# draw calls, triángulos, memoria de Godot y RSS máximo del proceso. Render por software (Xvfb + llvmpipe).
set -u
cd "$(dirname "$0")/.."
BIN=build/linux/UltimaBrasa.x86_64
OUT=bench_out/perf
mkdir -p "$OUT"
timeout 600 godot --headless --path . --export-release "LinuxPrueba" "$BIN" >/dev/null 2>&1
for preset in muy_bajo bajo medio alto; do
  for res in 1280x720 1920x1080; do
    rm -rf "$HOME/.local/share/godot/app_userdata/Última Brasa/ajustes.cfg"
    mkdir -p "$HOME/.local/share/godot/app_userdata/Última Brasa"
    printf '[graficos]\npreset="%s"\n' "$preset" > "$HOME/.local/share/godot/app_userdata/Última Brasa/ajustes.cfg"
    W=${res%x*}; H=${res#*x}
    xvfb-run -a -s "-screen 0 ${res}x24" "$BIN" --rendering-driver opengl3 --resolution "$res" -- --benchmark > "$OUT/$preset-$res.log" 2>&1 &
    PID=$!
    sleep 3
    GP=$(pgrep -x "UltimaBrasa.x86" | head -1)
    PEAK=0
    while kill -0 $PID 2>/dev/null; do
      if [ -n "$GP" ] && [ -f /proc/$GP/status ]; then
        R=$(grep VmHWM /proc/$GP/status | awk '{print $2}')
        [ -n "$R" ] && [ "$R" -gt "$PEAK" ] && PEAK=$R
      fi
      sleep 1
    done
    LINE=$(grep '^{' "$OUT/$preset-$res.log" | tail -1)
    echo "$preset $res rss_pico_mb=$((PEAK/1024)) $LINE" | cut -c1-900
  done
done
