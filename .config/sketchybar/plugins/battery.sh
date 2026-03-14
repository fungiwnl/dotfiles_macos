#!/usr/bin/env bash

set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

source "$CONFIG_DIR/colors.sh"

battery_info="$(pmset -g batt 2>/dev/null || true)"
percentage="$(printf '%s\n' "$battery_info" | grep -Eo '[0-9]+%' | tr -d '%' | head -n 1)"

if [[ -z "$percentage" ]]; then
  percentage="--"
fi

prefix="BAT"

if printf '%s' "$battery_info" | grep -qi 'AC Power\|charging\|charged'; then
  prefix="AC"
fi

color="$TEXT"

if [[ "$percentage" != "--" ]]; then
  if (( percentage <= 20 )); then
    color="$CRITICAL"
  elif (( percentage <= 40 )); then
    color="$WARNING"
  fi
  label="$prefix $percentage%"
else
  label="$prefix --"
fi

"$SKETCHYBAR_BIN" --set "$NAME" label="$label" label.color="$color"
