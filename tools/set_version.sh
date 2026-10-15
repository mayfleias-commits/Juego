#!/usr/bin/env bash
# Cambia la versión del juego en todos los lugares donde está escrita.
# Uso: tools/set_version.sh X.Y.Z
#  - project.godot: application/config/version="X.Y.Z" (de ahí la lee el juego: menú y
#    cabecera de los guardados; SAVE_VERSION es otra cosa y solo cambia con el formato).
#  - export_presets.cfg, Android: version/name="X.Y.Z" y version/code +1 (entero que Android
#    exige que crezca para instalar encima de la versión anterior).
#  - export_presets.cfg, Windows: application/file_version y product_version "X.Y.Z.0".
# Si la versión ya es X.Y.Z no cambia nada (version/code no se incrementa dos veces).
# Después: commit y tools/publish_release.sh vX.Y.Z (que verifica que coincida).
set -euo pipefail
cd "$(dirname "$0")/.."
V="${1:-}"
V="${V#v}"
if ! [[ "$V" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Uso: tools/set_version.sh X.Y.Z   (por ejemplo 1.2.0)" >&2
  exit 1
fi
PG=project.godot
EP=export_presets.cfg

OLD_NAME=$(sed -n 's/^version\/name="\(.*\)"$/\1/p' "$EP" | head -1)
OLD_CODE=$(sed -n 's/^version\/code=\([0-9]*\)$/\1/p' "$EP" | head -1)
OLD_PG=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$PG" | head -1)
if [ -z "$OLD_CODE" ] || [ -z "$OLD_NAME" ]; then
  echo "No encuentro version/code o version/name en $EP" >&2
  exit 1
fi

# project.godot (sección [application])
if [ -n "$OLD_PG" ]; then
  sed -i "s/^config\/version=\".*\"$/config\/version=\"$V\"/" "$PG"
else
  sed -i "/^config\/name=/a config\/version=\"$V\"" "$PG"
fi

# export_presets.cfg
if [ "$OLD_NAME" != "$V" ]; then
  NEW_CODE=$((OLD_CODE + 1))
else
  NEW_CODE=$OLD_CODE
fi
sed -i \
  -e "s/^version\/code=[0-9]*$/version\/code=$NEW_CODE/" \
  -e "s/^version\/name=\".*\"$/version\/name=\"$V\"/" \
  -e "s/^application\/file_version=\".*\"$/application\/file_version=\"$V.0\"/" \
  -e "s/^application\/product_version=\".*\"$/application\/product_version=\"$V.0\"/" \
  "$EP"

echo "project.godot:      config/version ${OLD_PG:-(no estaba)} -> $V"
echo "Android:            version/name $OLD_NAME -> $V, version/code $OLD_CODE -> $NEW_CODE"
echo "Windows:            file_version y product_version -> $V.0"
grep -n -e '^config/version=' "$PG"
grep -n -e '^version/code=' -e '^version/name=' -e '^application/file_version=' -e '^application/product_version=' "$EP"
