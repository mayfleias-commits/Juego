#!/usr/bin/env bash
# Publica una Release de GitHub con el .zip de Windows y el APK de Android.
# Las herramientas de este entorno no pueden crear Releases por la API, así que:
#   1) exporta con tools/export.sh,
#   2) sube los binarios + un workflow a la rama huérfana `release-assets`,
#   3) el workflow (GitHub Actions) crea la Release apuntando al commit indicado.
# Uso: tools/publish_release.sh vX.Y.Z [commit_destino]
# Antes: tools/set_version.sh X.Y.Z y commit. La etiqueta tiene que coincidir con la versión
# del proyecto (project.godot y export_presets.cfg), tanto en la copia de trabajo (que es la
# que se exporta) como en el commit destino; si no, no publica nada.
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
[ "${SKIP_EXPORT:-0}" = "1" ] || tools/export.sh
WORK=$(mktemp -d)
git clone -q --branch release-assets --single-branch "$(git remote get-url origin)" "$WORK" 2>/dev/null || {
  git init -q "$WORK"; (cd "$WORK" && git checkout -q --orphan release-assets && git remote add origin "$(git -C "$OLDPWD" remote get-url origin)"); }
cp build/UltimaBrasa-Windows-x64.zip "$WORK/UltimaBrasa-Windows-x64.zip"
cp build/UltimaBrasa.apk "$WORK/UltimaBrasa-Android.apk"
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
