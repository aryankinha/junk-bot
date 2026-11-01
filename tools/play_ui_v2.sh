#!/bin/zsh
set -eu
variant="${1:-b}"
[[ "$variant" == a || "$variant" == b ]] || { echo "Use a (current) or b (new UI)"; exit 1; }
cd "$(dirname "$0")/.."
exec /Applications/Godot.app/Contents/MacOS/Godot --path . -- --ui-review="$variant"
