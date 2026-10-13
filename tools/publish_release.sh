#!/usr/bin/env bash
# Publica una Release de GitHub con el .zip de Windows y el APK de Android.
# Las herramientas de este entorno no pueden crear Releases por la API, así que:
#   1) exporta con tools/export.sh,
#   2) sube los binarios + un workflow a la rama huérfana `release-assets`,
#   3) el workflow (GitHub Actions) crea la Release apuntando al commit indicado.
# Uso: tools/publish_release.sh v1.0.0 [commit_destino]
set -euo pipefail
cd "$(dirname "$0")/.."
TAG="${1:?versión, p.ej. v1.0.0}"
TARGET="${2:-$(git rev-parse HEAD)}"
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
