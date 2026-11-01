#!/bin/bash
# Human A/B playtests: fresh isolated saves, same seed, manual controls, no new menu.
set -euo pipefail
cd "$(dirname "$0")/.."
variant="${1:-b}"
[[ "$variant" == a || "$variant" == b ]] || { echo 'Usage: bash tools/play_mob_stream.sh a|b'; exit 2; }
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
exec "$GODOT_BIN" --path . -- "--playtest=$variant"
