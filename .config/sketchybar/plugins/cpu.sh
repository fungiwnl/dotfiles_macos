#!/usr/bin/env bash

set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

source "$CONFIG_DIR/colors.sh"

cpu_line="$(top -l 1 -n 0 | awk -F': ' '/CPU usage/ {print $2; exit}')"
user_pct="$(printf '%s\n' "$cpu_line" | awk -F'%' '{gsub(/^ +| +$/, "", $1); print int($1 + 0.5)}')"
sys_pct="$(printf '%s\n' "$cpu_line" | awk -F'[, %]+' '{print int($4 + 0.5)}')"

if [[ -z "$user_pct" || -z "$sys_pct" ]]; then
  "$SKETCHYBAR_BIN" --set "$NAME" label="CPU --"
  exit 0
fi

total_pct=$((user_pct + sys_pct))
color="$TEXT"

if (( total_pct >= 85 )); then
  color="$CRITICAL"
elif (( total_pct >= 65 )); then
  color="$WARNING"
fi

"$SKETCHYBAR_BIN" --set "$NAME" label="CPU ${total_pct}%" label.color="$color"
