#!/usr/bin/env bash
# Rebuilds the Web export and force-pushes it as the gh-pages branch, live at
# https://aquantumarchitect.github.io/eukaryotic-eucharist-godot-spike/
# Run this whenever you want the deployed build to reflect the current source.
set -euo pipefail
SPIKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE="${PAGES_REMOTE:-https://github.com/AQuantumArchitect/eukaryotic-eucharist-godot-spike.git}"

"$SPIKE_DIR/tools/build_web.sh"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cp -r "$SPIKE_DIR"/dist_web/* "$WORKDIR"/
cd "$WORKDIR"
git init -q
git checkout -q -b gh-pages
git add -A
git -c user.name="Claude-RNA-Agent" -c user.email="noreply@anthropic.com" \
    commit -q -m "Deploy Godot web export to GitHub Pages"
git remote add origin "$REMOTE"
git push -q -f origin gh-pages

echo "Deployed. Live in ~30s at https://aquantumarchitect.github.io/eukaryotic-eucharist-godot-spike/"
