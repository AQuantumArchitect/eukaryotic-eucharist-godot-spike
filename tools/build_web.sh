#!/usr/bin/env bash
# Exports the spike to Web and copies the REAL, unmodified game kernel alongside the output —
# no kernel edits, no build step inside the JS repo. Serve dist_web/ with any static file server.
set -euo pipefail
SPIKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/home/primearchitect/.local/bin/godot}"
GAME_SRC="$SPIKE_DIR/../eukarayotic_eucharist/eukaryotic_eucharist_mobile_v1_3_3/src"
GAME_KERNEL="$GAME_SRC/graph_kernel.mjs"
DIST="$SPIKE_DIR/dist_web"

if [ ! -f "$GAME_KERNEL" ]; then
  echo "Game kernel not found at $GAME_KERNEL" >&2
  exit 1
fi

mkdir -p "$DIST"
"$GODOT_BIN" --headless --path "$SPIKE_DIR" --export-release "Web" "$DIST/index.html"

# graph_kernel.mjs is a barrel re-export (`export * from './simCore.mjs'` etc, see its own
# header) — copy EVERY sibling .mjs module in src/, not just the entry file, so this build
# survives the kernel repo splitting itself further without needing an edit here each time.
# Filenames/extensions are preserved (no rename) since the barrel's import statements reference
# them by exact relative path, e.g. './simCore.mjs' — only the entry point itself gets renamed.
cp "$GAME_SRC"/*.mjs "$DIST/"
mv "$DIST/graph_kernel.mjs" "$DIST/graph_kernel.js"

echo "Exported to $DIST"
echo "Serve with: python3 -m http.server 8788 --directory $DIST"
