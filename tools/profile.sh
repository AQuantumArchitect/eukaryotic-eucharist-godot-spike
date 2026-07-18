#!/usr/bin/env bash
# One-command profiling loop: export -> serve -> run the HEADED performance rig -> tear down.
# Same shape as tools/test.sh, different question: not "is it correct" but "how fast is it" —
# FPS, sim-throughput, entity-count scaling, JS heap. Run this before/after any change aimed at
# performance (entity pool sizing, cull padding, poll cadence) to see the actual before/after.
#
# CPU_CORES pins the whole profiler (and the Chromium it launches, which inherits affinity) to N
# cores via taskset. Default is 2, not `nproc` — this machine is shared/busy, and the target
# device for this game is not a dedicated 8-core box either, so profiling under a deliberately
# starved core budget is closer to the real constraint than profiling with free run of the host.
# Set CPU_CORES=0 to disable pinning and use every core.
set -euo pipefail
SPIKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8788}"
PYTHON_BIN="${PYTHON_BIN:-/home/primearchitect/venvs/torch118/bin/python3}"
SPIKE_CHROME_PATH="${SPIKE_CHROME_PATH:-/home/primearchitect/.cache/ms-playwright/chromium-1217/chrome-linux64/chrome}"
CPU_CORES="${CPU_CORES:-2}"

"$SPIKE_DIR/tools/build_web.sh"

python3 -m http.server "$PORT" --directory "$SPIKE_DIR/dist_web" >/tmp/spike_http_"$PORT".log 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
sleep 1

RUNNER=("$PYTHON_BIN")
if [ "$CPU_CORES" != "0" ] && command -v taskset >/dev/null 2>&1; then
	RUNNER=(taskset -c "0-$((CPU_CORES - 1))" "$PYTHON_BIN")
	echo "Pinned to CPU cores 0-$((CPU_CORES - 1)) (CPU_CORES=$CPU_CORES) — set CPU_CORES=0 to disable." >&2
fi

SPIKE_CHROME_PATH="$SPIKE_CHROME_PATH" "${RUNNER[@]}" "$SPIKE_DIR/tools/profile_headed.py" "http://localhost:$PORT/index.html" "$@"
