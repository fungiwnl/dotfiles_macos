#!/usr/bin/env bash

set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

source "$CONFIG_DIR/colors.sh"

battery_info="$(pmset -g batt 2>/dev/null || true)"
percentage="$(printf '%s\n' "$battery_info" | grep -Eo '[0-9]+%' | tr -d '%' | head -n 1)"

if [[ -z "$percentage" ]]; then
  percentage="--"
fi

on_ac=false
if printf '%s\n' "$battery_info" | grep -qi "drawing from 'AC Power'"; then
  on_ac=true
fi

if [[ "$on_ac" == "true" ]]; then
  icon=$'\uf0e7'
else
  icon=$'\uf240'
fi

color="$TEXT"

if [[ "$percentage" != "--" ]]; then
  if (( percentage <= 20 )); then
    color="$CRITICAL"
  elif (( percentage <= 40 )); then
    color="$WARNING"
  fi
  label="$percentage%"
else
  label="--"
fi

"$SKETCHYBAR_BIN" --set "$NAME" icon="$icon" label="$label" label.color="$color"
