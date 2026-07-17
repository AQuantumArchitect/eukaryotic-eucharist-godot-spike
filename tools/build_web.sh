#!/usr/bin/env bash
# Exports the spike to Web and copies the REAL, unmodified game kernel alongside the output —
# no kernel edits, no build step inside the JS repo. Serve dist_web/ with any static file server.
set -euo pipefail
SPIKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/home/primearchitect/.local/bin/godot}"
GAME_KERNEL="$SPIKE_DIR/../eukarayotic_eucharist/eukaryotic_eucharist_mobile_v1_3_3/src/graph_kernel.mjs"
DIST="$SPIKE_DIR/dist_web"

if [ ! -f "$GAME_KERNEL" ]; then
  echo "Game kernel not found at $GAME_KERNEL" >&2
  exit 1
fi

mkdir -p "$DIST"
"$GODOT_BIN" --headless --path "$SPIKE_DIR" --export-release "Web" "$DIST/index.html"

# Renamed .js (not .mjs) purely so static file servers serve a correct JS MIME type for the
# `<script type="module">` import — content is byte-identical, nothing is transformed.
cp "$GAME_KERNEL" "$DIST/graph_kernel.js"

echo "Exported to $DIST"
echo "Serve with: python3 -m http.server 8788 --directory $DIST"
