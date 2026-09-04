#!/bin/sh
# Build the web app and stage it at docs/app/, which GitHub Pages serves at
# https://marcobonechi.github.io/actufree/app/
#
# The build is wasm-only in practice. blockblast_engine packs the board into a
# 64-bit bitboard, and JavaScript integers carry 53 bits, so a JS build
# computes wrong column masks — quietly, since only the one literal is caught
# at compile time. Flutter always emits a JS fallback and offers no way to
# suppress it, so this script replaces it with a stub that says the browser is
# unsupported rather than letting a broken game run.
set -e

APP_DIR="$(cd "$(dirname "$0")/../app" && pwd)"
DEST="$(cd "$(dirname "$0")/../.." && pwd)/docs/app"

cd "$APP_DIR"
flutter build web --wasm --release --base-href /actufree/app/

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R build/web/ "$DEST/"

# Debug symbol maps: only used to symbolicate stack traces, never to run.
find "$DEST" -name "*.symbols" -delete

# Replace the JS fallback (2.4 MB of subtly wrong game) with a refusal.
# Same file the Pages workflow uses, so the two cannot drift apart.
cp "$(dirname "$0")/web_js_fallback.js" "$DEST/main.dart.js"

echo "Staged $(du -sh "$DEST" | cut -f1) at docs/app/"
