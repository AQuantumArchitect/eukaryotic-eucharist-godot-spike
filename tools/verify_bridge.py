#!/usr/bin/env python3
"""Regression check for the JS-kernel <-> Godot bridge. Run after ANY change to
bridge/kernel_bridge.gd, view/graph_view.gd, config/sim_params.tres, export_presets.cfg, or the
game's own graph_kernel.mjs — this is the one thing that proves the bridge (not just the
GDScript, not just the kernel) is still really wired together.

Usage: ./tools/test.sh (builds + serves + runs this + tears down) — or run directly against an
already-served dist_web/ with: python3 verify_bridge.py [url] [--json] [--boot-wait N] [--settle-wait N]

--json is the contract for external test/product bots: every human-readable line goes to
stderr, and exactly one JSON object is printed to stdout, so a bot can pipe stdout straight into
a parser instead of scraping text. Same {ok, t1, t2, ...} fields either way.
"""
import argparse
import json
import os
import sys
import time

from playwright.sync_api import sync_playwright

SCRIPT_DIR = os.path.dirname(__file__)

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
    parser.add_argument("--boot-wait", type=float, default=20.0, help="seconds to let the wasm runtime + KernelBridge boot")
    parser.add_argument("--settle-wait", type=float, default=5.0, help="seconds between the two liveness reads")
    args = parser.parse_args()

    chrome_path = os.environ.get("SPIKE_CHROME_PATH")  # optional override; None = Playwright's own default
    screenshot_path = os.path.join(SCRIPT_DIR, "..", "verify_screenshot.png")

    launch_kwargs = {"headless": True, "args": ["--no-sandbox"]}
    if chrome_path:
        launch_kwargs["executable_path"] = chrome_path

    with sync_playwright() as p:
        browser = p.chromium.launch(**launch_kwargs)
        page = browser.new_page(viewport={"width": 1024, "height": 768})
        page.on("console", lambda msg: on_console(args.json, msg))
        page.on("pageerror", lambda exc: on_pageerror(args.json, exc))
        page.goto(args.url, wait_until="load")

        log(args.json, f"Waiting {args.boot_wait:.0f}s for the wasm runtime to boot + KernelBridge to boot + a few polls...")
        time.sleep(args.boot_wait)

        # GraphEdit is drawn to <canvas>, not the DOM, so the honest liveness check is asking the
        # SAME window.EE/window.__eeWorld the game is actually driving whether sim time really
        # advances between two reads — a static/frozen bridge would show t1 == t2.
        t1 = page.evaluate("window.__eeWorld ? window.__eeWorld.t : null")
        time.sleep(args.settle_wait)
        t2 = page.evaluate("window.__eeWorld ? window.__eeWorld.t : null")

        ee_present = page.evaluate("!!window.EE")
        world_present = page.evaluate("!!window.__eeWorld")
        edges_len = page.evaluate("window.EE ? window.EE.ORGAN_GRAPH_EDGES.length : null")

        log(args.json, f"t1={t1} t2={t2} window.EE={ee_present} world={world_present} edges={edges_len}")
        page.screenshot(path=screenshot_path)
        log(args.json, f"Screenshot: {screenshot_path}")
        browser.close()

    if console_errors:
        log(args.json, "\n=== CONSOLE ERRORS ===")
        for e in console_errors:
            log(args.json, e)

    ok = (
        t1 is not None and t2 is not None and t2 > t1
        and ee_present and world_present and edges_len and edges_len > 0
    )

    if args.json:
        print(json.dumps({
            "ok": ok,
            "t1": t1,
            "t2": t2,
            "ee_present": ee_present,
            "world_present": world_present,
            "edges_len": edges_len,
            "console_errors": console_errors,
            "screenshot": os.path.abspath(screenshot_path),
        }))
    else:
        print("\nRESULT:", "PASS" if ok else "FAIL")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
