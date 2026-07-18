#!/usr/bin/env bash
# One-command profiling loop: export -> serve -> run the HEADED performance rig -> tear down.
# Same shape as tools/test.sh, different question: not "is it correct" but "how fast is it" —
# FPS, sim-throughput, entity-count scaling, JS heap. Run this before/after any change aimed at
# performance (entity pool sizing, cull padding, poll cadence) to see the actual before/after.
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

SPIKE_CHROME_PATH="$SPIKE_CHROME_PATH" "$PYTHON_BIN" "$SPIKE_DIR/tools/profile_headed.py" "http://localhost:$PORT/index.html" "$@"
