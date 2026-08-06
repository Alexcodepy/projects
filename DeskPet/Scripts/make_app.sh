#!/bin/bash
# Compila DeskPet y monta el bundle DeskPet.app (necesario para LSUIElement,
# para SMAppService y para que la app no aparezca en el Dock).
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/DeskPet.app"

cd "$ROOT"

echo "==> Compilando ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/DeskPet"
if [ ! -f "$BIN" ]; then
    echo "No se encontró el ejecutable en $BIN" >&2
    exit 1
fi

echo "==> Montando $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/DeskPet"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Sprite sheet opcional incluido en el bundle (si existe).
if [ -f "$ROOT/Resources/pet_sheet.png" ]; then
    cp "$ROOT/Resources/pet_sheet.png" "$APP/Contents/Resources/pet_sheet.png"
    echo "    · pet_sheet.png incluido"
else
    echo "    · sin pet_sheet.png: se usarán los sprites generados por código"
fi

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Firma ad-hoc: suficiente para ejecutar en local.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 \
    && echo "    · firmada (ad-hoc)" \
    || echo "    · aviso: no se pudo firmar (la app funciona igual en local)"

echo "==> Listo: $APP"
echo "    Ejecutar:  open $APP"
