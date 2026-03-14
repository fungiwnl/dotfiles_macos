#!/usr/bin/env bash

set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

volume="${INFO:-}"

if [[ -z "$volume" ]]; then
  volume="$(osascript -e 'output volume of (get volume settings)' 2>/dev/null || true)"
fi

if [[ -z "$volume" ]]; then
  volume="--"
fi

if [[ "$volume" == "--" ]]; then
  label="VOL --"
else
  label="VOL $volume%"
fi

"$SKETCHYBAR_BIN" --set "$NAME" label="$label"
