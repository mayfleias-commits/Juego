#!/usr/bin/env bash
# Instala el entorno de construcción en un contenedor Linux limpio (Ubuntu 24.04).
# - Godot 4.7.2 estable (editor, headless) + export templates
# - SDK de Android mínimo (build-tools/platform-tools desde apt) + JDK
# - Xvfb + Mesa (render por software para capturas y benchmarks en CI)
set -euo pipefail
GODOT_VER="${GODOT_VER:-4.7.2-stable}"
GODOT_DIR=/opt/godot
TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VER/-/.}"

if ! command -v godot >/dev/null 2>&1; then
  mkdir -p "$GODOT_DIR"
  curl -sSL -o "$GODOT_DIR/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_linux.x86_64.zip"
  unzip -o -q "$GODOT_DIR/godot.zip" -d "$GODOT_DIR"
  rm -f "$GODOT_DIR/godot.zip"
  ln -sf "$GODOT_DIR/Godot_v${GODOT_VER}_linux.x86_64" /usr/local/bin/godot
fi
godot --headless --version

if [ "${SKIP_TEMPLATES:-0}" != "1" ] && [ ! -f "$TPL_DIR/version.txt" ]; then
  mkdir -p "$TPL_DIR"
  tmp=$(mktemp -d)
  curl -sSL -o "$tmp/t.tpz" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_export_templates.tpz"
  unzip -q -o "$tmp/t.tpz" -d "$tmp"
  mv "$tmp"/templates/* "$TPL_DIR/"
  rm -rf "$tmp"
  # Solo necesitamos Windows x86_64 y Android.
  rm -rf "$TPL_DIR"/{ios.zip,macos.zip,web_*,linux_*arm*,linux_*x86_32,windows_*arm64*,windows_*x86_32*}
fi

if [ "${SKIP_APT:-0}" != "1" ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q >/dev/null
  apt-get install -y -q android-sdk apksigner zipalign android-sdk-platform-tools \
    xvfb mesa-utils libgl1-mesa-dri libglx-mesa0 >/dev/null
fi
echo "Entorno listo."
