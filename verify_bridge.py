#!/usr/bin/env python3
"""Regression check for the JS-kernel <-> Godot bridge. Run after ANY change to kernel_bridge.gd,
graph_view.gd, export_presets.cfg, or the game's own graph_kernel.mjs — this is the one thing that
proves the bridge (not just the GDScript, not just the kernel) is still really wired together.

Usage: ./test.sh (builds + serves + runs this + tears down) — or run directly against an
already-served dist_web/ with: python3 verify_bridge.py [url]
"""
import os
import sys
import time

from playwright.sync_api import sync_playwright

URL = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8788/index.html"
CHROME_PATH = os.environ.get("SPIKE_CHROME_PATH")  # optional override; None = Playwright's own default
SCREENSHOT_PATH = os.path.join(os.path.dirname(__file__), "verify_screenshot.png")

console_errors = []


def on_console(msg):
    if msg.type == "error":
        console_errors.append(msg.text)
    print(f"[console:{msg.type}] {msg.text}")


def on_pageerror(exc):
    console_errors.append(str(exc))
    print(f"[pageerror] {exc}")


def main() -> int:
    launch_kwargs = {"headless": True, "args": ["--no-sandbox"]}
    if CHROME_PATH:
        launch_kwargs["executable_path"] = CHROME_PATH

    with sync_playwright() as p:
        browser = p.chromium.launch(**launch_kwargs)
        page = browser.new_page(viewport={"width": 1024, "height": 768})
        page.on("console", on_console)
        page.on("pageerror", on_pageerror)
        page.goto(URL, wait_until="load")

        print("Waiting 20s for the wasm runtime to boot + KernelBridge to boot + a few polls...")
        time.sleep(20)

        # GraphEdit is drawn to <canvas>, not the DOM, so the honest liveness check is asking the
        # SAME window.EE/window.__eeWorld the game is actually driving whether sim time really
        # advances between two reads — a static/frozen bridge would show t1 == t2.
        t1 = page.evaluate("window.__eeWorld ? window.__eeWorld.t : null")
        time.sleep(5)
        t2 = page.evaluate("window.__eeWorld ? window.__eeWorld.t : null")

        ee_present = page.evaluate("!!window.EE")
        world_present = page.evaluate("!!window.__eeWorld")
        edges_len = page.evaluate("window.EE ? window.EE.ORGAN_GRAPH_EDGES.length : null")

        print(f"t1={t1} t2={t2} window.EE={ee_present} world={world_present} edges={edges_len}")
        page.screenshot(path=SCREENSHOT_PATH)
        print(f"Screenshot: {SCREENSHOT_PATH}")
        browser.close()

    if console_errors:
        print("\n=== CONSOLE ERRORS ===")
        for e in console_errors:
            print(e)

    ok = (
        t1 is not None and t2 is not None and t2 > t1
        and ee_present and world_present and edges_len and edges_len > 0
    )
    print("\nRESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
