#!/usr/bin/env bash
# Publica una Release de GitHub con el .zip de Windows y el APK de Android.
# Las herramientas de este entorno no pueden crear Releases por la API, así que:
#   1) exporta con tools/export.sh,
#   2) sube los binarios + un workflow a la rama huérfana `release-assets`,
#   3) el workflow (GitHub Actions) crea la Release apuntando al commit indicado.
# Uso: tools/publish_release.sh vX.Y.Z [commit_destino]
# Antes: tools/set_version.sh X.Y.Z, actualizar tools/release/NOTAS.md (sección «Novedades de la
# vX.Y.Z») y commit. No publica nada si:
#   - la etiqueta no coincide con la versión del proyecto (project.godot y export_presets.cfg),
#     ni en la copia de trabajo ni en el commit destino;
#   - hay cambios sin commitear en archivos versionados, o HEAD no es el commit destino
#     (los binarios salen de la copia de trabajo, que tiene que ser exactamente ese commit);
#   - NOTAS.md no tiene la sección «Novedades de la vX.Y.Z»;
#   - el APK exportado no declara la versión pedida o el .zip no trae LICENCIAS.txt.
# Con SKIP_EXPORT=1 reutiliza build/ en lugar de exportar, pero exige que el .zip y el .apk sean
# más nuevos que el último commit que toca game/, sim/, data/, project.godot o export_presets.cfg.
set -euo pipefail
cd "$(dirname "$0")/.."
TAG="${1:?versión, p.ej. v1.1.0}"
TARGET="${2:-$(git rev-parse HEAD)}"
if ! [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "La etiqueta tiene que tener la forma vX.Y.Z (por ejemplo v1.1.0)." >&2
  exit 1
fi
V="${TAG#v}"
# Lee la versión de project.godot y de los presets (del archivo o, con un commit, de ese commit).
versions() {
  local pg ep
  if [ -n "${1:-}" ]; then
    pg=$(git show "$1:project.godot") ep=$(git show "$1:export_presets.cfg")
  else
    pg=$(cat project.godot) ep=$(cat export_presets.cfg)
  fi
  echo "proyecto=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' <<<"$pg" | head -1)" \
    "android=$(sed -n 's/^version\/name="\(.*\)"$/\1/p' <<<"$ep" | head -1)" \
    "windows=$(sed -n 's/^application\/file_version="\(.*\)"$/\1/p' <<<"$ep" | head -1)"
}
WANT="proyecto=$V android=$V windows=$V.0"
for where in "" "$TARGET"; do
  GOT=$(versions "$where")
  if [ "$GOT" != "$WANT" ]; then
    echo "La versión ${where:+del commit $where }no coincide con $TAG:" >&2
    echo "  tiene:   $GOT" >&2
    echo "  debería: $WANT" >&2
    echo "Corré tools/set_version.sh $V, hacé commit y volvé a intentar." >&2
    exit 1
  fi
done

# La copia de trabajo tiene que ser exactamente el commit destino: de ahí salen los binarios.
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "Hay cambios sin commitear en archivos versionados; los binarios no saldrían del commit $TARGET:" >&2
  git status --short --untracked-files=no >&2
  echo "Hacé commit (o descartá los cambios) y volvé a intentar." >&2
  exit 1
fi
HEAD_SHA=$(git rev-parse HEAD)
TARGET_SHA=$(git rev-parse --verify "$TARGET^{commit}")
if [ "$HEAD_SHA" != "$TARGET_SHA" ]; then
  echo "HEAD ($HEAD_SHA) no es el commit destino ($TARGET_SHA)." >&2
  echo "Los binarios se exportan de la copia de trabajo; pasate a ese commit o publicá sin segundo argumento." >&2
  exit 1
fi
TARGET="$TARGET_SHA"
# Las notas de la Release se copian tal cual: tienen que ser las de esta versión.
if ! grep -q "Novedades de la v$V" tools/release/NOTAS.md; then
  echo "tools/release/NOTAS.md no tiene la sección «Novedades de la v$V»." >&2
  echo "Actualizá las notas (novedades, tamaños, requisitos) para esta versión y hacé commit." >&2
  exit 1
fi

ZIP=build/UltimaBrasa-Windows-x64.zip
APK=build/UltimaBrasa.apk
if [ "${SKIP_EXPORT:-0}" = "1" ]; then
  # Los binarios de build/ tienen que ser posteriores al último cambio del juego exportado.
  LAST=$(git log -1 --format=%ct -- game sim data project.godot export_presets.cfg)
  for f in "$ZIP" "$APK"; do
    if [ ! -f "$f" ]; then
      echo "SKIP_EXPORT=1 pero falta $f. Quitá SKIP_EXPORT para exportar." >&2
      exit 1
    fi
    if [ "$(stat -c %Y "$f")" -le "${LAST:-0}" ]; then
      echo "$f es más viejo que el último commit que toca game/, sim/, data/ o la configuración del proyecto." >&2
      echo "Quitá SKIP_EXPORT para exportar de nuevo." >&2
      exit 1
    fi
  done
else
  tools/export.sh
fi

# Verifica lo que realmente se va a subir.
for f in "$ZIP" "$APK"; do
  [ -f "$f" ] || { echo "Falta $f después de exportar." >&2; exit 1; }
done
ZIP_LIST=$(unzip -Z1 "$ZIP")
if ! grep -qx "LICENCIAS.txt" <<<"$ZIP_LIST"; then
  echo "$ZIP no contiene LICENCIAS.txt; no se publica." >&2
  exit 1
fi
AAPT=$(command -v aapt || ls /usr/lib/android-sdk/build-tools/*/aapt 2>/dev/null | tail -1 || true)
if [ -z "$AAPT" ]; then
  echo "No encuentro aapt para verificar la versión del APK (tools/setup_env.sh instala el SDK de Android)." >&2
  exit 1
fi
CODE=$(sed -n 's/^version\/code=\([0-9]*\)$/\1/p' export_presets.cfg | head -1)
BADGING=$("$AAPT" dump badging "$APK")
if ! grep -q "versionCode='$CODE' versionName='$V'" <<<"$BADGING"; then
  echo "El APK no declara la versión $V (versionCode $CODE):" >&2
  grep -m1 "^package:" <<<"$BADGING" >&2 || true
  echo "Quitá SKIP_EXPORT o exportá de nuevo." >&2
  exit 1
fi
WORK=$(mktemp -d)
git clone -q --branch release-assets --single-branch "$(git remote get-url origin)" "$WORK" 2>/dev/null || {
  git init -q "$WORK"; (cd "$WORK" && git checkout -q --orphan release-assets && git remote add origin "$(git -C "$OLDPWD" remote get-url origin)"); }
cp "$ZIP" "$WORK/UltimaBrasa-Windows-x64.zip"
cp "$APK" "$WORK/UltimaBrasa-Android.apk"
echo "$TAG" > "$WORK/VERSION"
echo "$TARGET" > "$WORK/TARGET"
cp tools/release/NOTAS.md "$WORK/NOTAS.md"
mkdir -p "$WORK/.github/workflows"
cp tools/release/publicar.yml "$WORK/.github/workflows/publicar.yml"
cat > "$WORK/README.md" <<EOT
# Binarios de Última Brasa
Rama usada solo para publicar Releases (no contiene código). El código está en la rama principal.
EOT
cd "$WORK"
git add -A
git -c user.email=noreply@anthropic.com -c user.name="Claude" commit -qm "Release $TAG ($TARGET)"
git push -q -u origin release-assets
echo "Subido. El workflow 'Publicar release' crea la Release $TAG en unos minutos."
