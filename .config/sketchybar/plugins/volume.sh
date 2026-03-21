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
  icon=$'\uf6a9'
  label="--"
else
  icon=$'\uf028'
  label="$volume%"
fi

"$SKETCHYBAR_BIN" --set "$NAME" icon="$icon" label="$label"
