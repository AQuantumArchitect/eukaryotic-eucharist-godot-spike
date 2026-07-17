#!/usr/bin/env bash
# One-command iterate loop: export -> serve -> verify the bridge is really live -> tear down.
# Run this after touching bridge/kernel_bridge.gd, view/graph_view.gd, config/sim_params.tres,
# export_presets.cfg, or the game's own graph_kernel.mjs.
#
# --json prints ONE machine-readable result line (forwarded to verify_bridge.py) so an external
# test/product bot can consume pass/fail + metrics without scraping human-readable output.
set -euo pipefail
SPIKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8788}"
PYTHON_BIN="${PYTHON_BIN:-/home/primearchitect/venvs/torch118/bin/python3}"
SPIKE_CHROME_PATH="${SPIKE_CHROME_PATH:-/home/primearchitect/.cache/ms-playwright/chromium-1217/chrome-linux64/chrome}"

"$SPIKE_DIR/tools/build_web.sh"

python3 -m http.server "$PORT" --directory "$SPIKE_DIR/dist_web" >/tmp/spike_http_"$PORT".log 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
sleep 1

SPIKE_CHROME_PATH="$SPIKE_CHROME_PATH" "$PYTHON_BIN" "$SPIKE_DIR/tools/verify_bridge.py" "http://localhost:$PORT/index.html" "$@"
