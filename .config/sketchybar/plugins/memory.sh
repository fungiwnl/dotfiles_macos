#!/usr/bin/env bash

set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

source "$CONFIG_DIR/colors.sh"

to_bytes() {
  local value="$1"
  local number unit scale

  if [[ ! "$value" =~ ^([0-9]+([.][0-9]+)?)([KMGTP])$ ]]; then
    return 1
  fi

  number="${BASH_REMATCH[1]}"
  unit="${BASH_REMATCH[3]}"

  case "$unit" in
    K) scale=1024 ;;
    M) scale=1048576 ;;
    G) scale=1073741824 ;;
    T) scale=1099511627776 ;;
    P) scale=1125899906842624 ;;
    *) return 1 ;;
  esac

  awk -v n="$number" -v s="$scale" 'BEGIN { printf "%.0f", n * s }'
}

mem_line="$(top -l 1 -n 0 | awk -F': ' '/PhysMem/ {print $2; exit}')"
used_mem="$(printf '%s\n' "$mem_line" | awk -F' used' '{print $1}')"
total_mem_bytes="$(sysctl -n hw.memsize 2>/dev/null || true)"

if [[ -z "$used_mem" || -z "$total_mem_bytes" ]]; then
  "$SKETCHYBAR_BIN" --set "$NAME" label="MEM --"
  exit 0
fi

used_mem_bytes="$(to_bytes "$used_mem")"

if [[ -z "$used_mem_bytes" ]]; then
  "$SKETCHYBAR_BIN" --set "$NAME" label="MEM --"
  exit 0
fi

usage_pct="$(awk -v used="$used_mem_bytes" -v total="$total_mem_bytes" 'BEGIN { if (total > 0) printf "%d", (used / total) * 100 + 0.5 }')"

if [[ -z "$usage_pct" ]]; then
  "$SKETCHYBAR_BIN" --set "$NAME" label="MEM --"
  exit 0
fi

color="$TEXT"

if (( usage_pct >= 90 )); then
  color="$CRITICAL"
elif (( usage_pct >= 75 )); then
  color="$WARNING"
fi

"$SKETCHYBAR_BIN" --set "$NAME" label="MEM ${usage_pct}%" label.color="$color"
