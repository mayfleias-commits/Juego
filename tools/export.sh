#!/usr/bin/env bash
# Exporta Windows (.exe y LICENCIAS.txt en .zip) y Android (APK firmado con la clave de release).
# La versión sale de project.godot y export_presets.cfg (se cambia con tools/set_version.sh).
# La clave y su contraseña viven en secrets/ (NO se sube al repositorio).
# Si no existe, se genera una clave nueva (ver README, sección "Clave de firma").
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/windows secrets
ES="$HOME/.config/godot/editor_settings-4.7.tres"
if [ ! -f "$ES" ]; then
  timeout 120 godot --headless --editor --quit >/dev/null 2>&1 || true
fi
JAVA_HOME_DIR="${JAVA_HOME_DIR:-/usr/lib/jvm/java-21-openjdk-amd64}"
if [ -f "$ES" ]; then
  sed -i "s#^export/android/android_sdk_path = .*#export/android/android_sdk_path = \"/usr/lib/android-sdk\"#" "$ES"
  sed -i "s#^export/android/java_sdk_path = .*#export/android/java_sdk_path = \"$JAVA_HOME_DIR\"#" "$ES"
  grep -q "^export/android/android_sdk_path" "$ES" || echo "export/android/android_sdk_path = \"/usr/lib/android-sdk\"" >> "$ES"
fi
# Keystore de depuración (Godot lo pide aunque exportemos release)
DBG="$HOME/.local/share/godot/keystores/debug.keystore"
if [ ! -f "$DBG" ]; then
  mkdir -p "$(dirname "$DBG")"
  keytool -genkeypair -v -keystore "$DBG" -storepass android -alias androiddebugkey -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
# Clave de release
KS=secrets/ultimabrasa-release.keystore
ENVF=secrets/clave_android.env
if [ ! -f "$KS" ]; then
  PASS=$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)
  keytool -genkeypair -v -keystore "$KS" -storepass "$PASS" -keypass "$PASS" -alias ultimabrasa \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Ultima Brasa,O=Ultima Brasa,C=AR" >/dev/null 2>&1
  cat > "$ENVF" <<EOT
# Clave de firma del APK de release de Última Brasa. NO SUBIR AL REPOSITORIO.
# Alias: ultimabrasa — misma contraseña para el almacén y la clave.
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(pwd)/$KS"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="ultimabrasa"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PASS"
EOT
  echo "Clave nueva generada en $KS (contraseña en $ENVF)"
fi
# shellcheck disable=SC1090
source "$ENVF"
# La ruta guardada puede ser de otra máquina: siempre se usa la de esta copia del proyecto.
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(pwd)/$KS"
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DBG" GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
timeout 300 godot --headless --path . --import >/dev/null 2>&1 || true
echo "== Windows"
timeout 900 godot --headless --path . --export-release "Windows" build/windows/UltimaBrasa.exe 2>&1 | grep -v -e '^$' | tail -5
# Avisos de licencia del motor y de sus componentes (la MIT de Godot exige que viajen con el juego).
rm -f build/windows/LICENCIAS.txt
timeout 120 godot --headless --path . --script res://tools/licencias.gd -- "$(pwd)/build/windows/LICENCIAS.txt" 2>&1 | grep -e '^LICENCIAS' -e 'ERROR' || true
[ -s build/windows/LICENCIAS.txt ] || { echo "No se pudo generar build/windows/LICENCIAS.txt" >&2; exit 1; }
(cd build/windows && rm -f ../UltimaBrasa-Windows-x64.zip && zip -q -9 ../UltimaBrasa-Windows-x64.zip UltimaBrasa.exe LICENCIAS.txt)
ls -la build/UltimaBrasa-Windows-x64.zip
echo "== Android"
timeout 900 godot --headless --path . --export-release "Android" build/UltimaBrasa.apk 2>&1 | grep -v -e '^$' | tail -8
ls -la build/UltimaBrasa.apk
apksigner verify --print-certs build/UltimaBrasa.apk | head -3 || true
