#!/usr/bin/env python3
"""Performance profiling rig for the HEADED (real rendering, not verify_bridge.py's
software-swiftshader-fallback headless mode) Godot game view — the baseline this repo needs before
any future work on tuning/optimizing it. Runs a real, visible Chromium (via Xvfb if no physical
display), drives movement to generate realistic load, and reports FPS/sim-throughput/entity-count
metrics plus a Playwright trace file for deep inspection.

Usage: ./tools/profile.sh (builds + serves + runs this + tears down) — or run directly against an
already-served dist_web/ with:
  python3 profile_headed.py [url] [--json] [--duration N] [--boot-wait N] [--trace-out PATH]

--json is the same bot-consumable contract as verify_bridge.py: human-readable lines to stderr,
one JSON object to stdout.

Open the trace file at https://trace.playwright.dev (drag-and-drop) or `npx playwright show-trace
<path>` for a full timeline (network, JS, screenshots) alongside the FPS/entity-count series this
script computes itself.
"""
import argparse
import json
import os
import sys
import time

from playwright.sync_api import sync_playwright

SCRIPT_DIR = os.path.dirname(__file__)

# Runs before any page script — installs a requestAnimationFrame counter so real frame cadence
# (not wall-clock sampling of the DOM) drives the FPS measurement.
FPS_COUNTER_INIT_SCRIPT = """
window.__profFrames = 0;
window.__profStart = null;
(function tick(ts) {
  if (window.__profStart === null) window.__profStart = ts;
  window.__profFrames++;
  requestAnimationFrame(tick);
})();
"""

console_errors = []


def log(quiet: bool, *args) -> None:
    print(*args, file=sys.stderr if quiet else sys.stdout)


def on_console(quiet, msg):
    if msg.type == "error":
        console_errors.append(msg.text)
    log(quiet, f"[console:{msg.type}] {msg.text}")


def on_pageerror(quiet, exc):
    console_errors.append(str(exc))
    log(quiet, f"[pageerror] {exc}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("url", nargs="?", default="http://localhost:8788/index.html")
    parser.add_argument("--json", action="store_true", help="print one JSON result line to stdout instead of human text")
    parser.add_argument("--duration", type=float, default=30.0, help="seconds to drive gameplay + sample metrics")
    parser.add_argument("--boot-wait", type=float, default=60.0, help="max seconds to poll for the wasm runtime + KernelBridge to boot")
    parser.add_argument("--sample-interval", type=float, default=2.0, help="seconds between metric samples during the run")
    parser.add_argument("--trace-out", default=None, help="path for the Playwright trace .zip (default: tools/../profile_trace.zip)")
    args = parser.parse_args()

    chrome_path = os.environ.get("SPIKE_CHROME_PATH")
    trace_path = args.trace_out or os.path.join(SCRIPT_DIR, "..", "profile_trace.zip")
    screenshot_path = os.path.join(SCRIPT_DIR, "..", "profile_screenshot.png")

    # HEADED: a real (Xvfb-backed if no physical display) window, not Chromium's built-in headless
    # mode — verify_bridge.py already covers headless correctness; this rig exists specifically to
    # measure the frame-time/throughput profile of the ACTUAL rendering path future work will tune.
    # Headless Chromium auto-falls-back to SwiftShader software WebGL2; headed does NOT — under
    # Xvfb (no real GPU) that means WebGL2 init fails outright unless forced explicitly here.
    launch_kwargs = {"headless": False, "args": [
        "--no-sandbox",
        "--use-gl=angle",
        "--use-angle=swiftshader",
        "--enable-unsafe-swiftshader",
    ]}
    if chrome_path:
        launch_kwargs["executable_path"] = chrome_path

    with sync_playwright() as p:
        browser = p.chromium.launch(**launch_kwargs)
        context = browser.new_context(viewport={"width": 1024, "height": 768})
        context.tracing.start(screenshots=True, snapshots=True, sources=False)
        page = context.new_page()
        page.add_init_script(FPS_COUNTER_INIT_SCRIPT)
        page.on("console", lambda msg: on_console(args.json, msg))
        page.on("pageerror", lambda exc: on_pageerror(args.json, exc))
        page.goto(args.url, wait_until="load")

        # Poll instead of a blind sleep: headed boot time is noisier than headless (real
        # compositing/Xvfb overhead, plus whatever else is contending for CPU on the machine), so a
        # fixed sleep either wastes time or — worse — clicks a canvas still hidden behind the
        # loading splash, which times out (the splash intercepts pointer events).
        log(args.json, f"Waiting up to {args.boot_wait:.0f}s for the wasm runtime + KernelBridge to boot...")
        booted = False
        poll_start = time.monotonic()
        while time.monotonic() - poll_start < args.boot_wait:
            if page.evaluate("!!(window.EE && window.__eeWorld)"):
                booted = True
                break
            time.sleep(1.0)
        log(args.json, f"Booted after {time.monotonic() - poll_start:.1f}s" if booted else f"NOT booted after {args.boot_wait:.0f}s — proceeding anyway, expect failures")
        page.click("#canvas", force=True)

        t_sim_start = page.evaluate("window.__eeWorld ? window.__eeWorld.t : null")
        frames_start = page.evaluate("window.__profFrames")
        wall_start = time.monotonic()

        samples = []
        keys = ["w", "a", "s", "d"]
        elapsed = 0.0
        key_idx = 0
        log(args.json, f"Driving gameplay for {args.duration:.0f}s, sampling every {args.sample_interval:.1f}s...")
        while elapsed < args.duration:
            # Rotate through movement keys (~load like real play, not idle) rather than holding one
            # direction the whole run — keeps the player moving through varied entity density.
            key = keys[key_idx % len(keys)]
            key_idx += 1
            page.keyboard.down(key)
            time.sleep(min(args.sample_interval, args.duration - elapsed))
            page.keyboard.up(key)
            elapsed = time.monotonic() - wall_start

            sample = page.evaluate("""
                (() => {
                    const w = window.__eeWorld;
                    if (!w) return null;
                    const render = window.EE.getRenderProjection(w);
                    return {
                        wall_elapsed: performance.now(),
                        frames: window.__profFrames,
                        sim_t: w.t,
                        kernel_entities: render.entities.length,
                        kernel_fields: render.fields.length,
                        kernel_hazards: render.hazards.length,
                        kernel_particles: render.particles.length,
                        godot_entities: window.__eeGodotEntityCount ?? null,
                        js_heap_mb: (performance.memory ? performance.memory.usedJSHeapSize / 1048576 : null),
                    };
                })()
            """)
            if sample:
                samples.append(sample)
            log(args.json, f"  t+{elapsed:.1f}s  {sample}")

        frames_end = page.evaluate("window.__profFrames")
        t_sim_end = page.evaluate("window.__eeWorld ? window.__eeWorld.t : null")
        wall_elapsed = time.monotonic() - wall_start

        page.screenshot(path=screenshot_path)
        context.tracing.stop(path=trace_path)
        browser.close()

    fps_avg = (frames_end - frames_start) / wall_elapsed if wall_elapsed > 0 else None
    sim_throughput = (t_sim_end - t_sim_start) / wall_elapsed if (t_sim_start is not None and t_sim_end is not None and wall_elapsed > 0) else None
    entity_counts = [s["kernel_entities"] for s in samples if s.get("kernel_entities") is not None]
    godot_counts = [s["godot_entities"] for s in samples if s.get("godot_entities") is not None]
    heap_samples = [s["js_heap_mb"] for s in samples if s.get("js_heap_mb") is not None]

    report = {
        "ok": fps_avg is not None and fps_avg > 0 and sim_throughput is not None,
        "duration_s": wall_elapsed,
        "fps_avg": fps_avg,
        "sim_throughput": sim_throughput,  # sim-seconds advanced per real second; 1.0 = real-time
        "kernel_entities_min": min(entity_counts) if entity_counts else None,
        "kernel_entities_max": max(entity_counts) if entity_counts else None,
        "godot_entities_min": min(godot_counts) if godot_counts else None,
        "godot_entities_max": max(godot_counts) if godot_counts else None,
        "js_heap_mb_min": min(heap_samples) if heap_samples else None,
        "js_heap_mb_max": max(heap_samples) if heap_samples else None,
        "sample_count": len(samples),
        "samples": samples,
        "console_errors": console_errors,
        "trace": os.path.abspath(trace_path),
        "screenshot": os.path.abspath(screenshot_path),
    }

    if args.json:
        print(json.dumps(report))
    else:
        print(f"\nFPS avg: {fps_avg}")
        print(f"Sim throughput: {sim_throughput} sim-s/real-s (1.0 = real-time)")
        print(f"Kernel entities: {report['kernel_entities_min']}-{report['kernel_entities_max']}")
        print(f"Godot pooled entities: {report['godot_entities_min']}-{report['godot_entities_max']}")
        print(f"JS heap: {report['js_heap_mb_min']}-{report['js_heap_mb_max']} MB")
        print(f"Trace: {trace_path}")
        print("RESULT:", "OK" if report["ok"] else "FAIL")

    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
