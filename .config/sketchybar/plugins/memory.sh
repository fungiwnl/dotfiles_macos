#!/usr/bin/env bash

set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

source "$CONFIG_DIR/colors.sh"

get_memory_usage() {
    local total_mem_bytes used_kb usage_pct

    total_mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || return 1)
    used_kb=$(ps -eo rss= 2>/dev/null | awk '{sum+=$1} END {print sum}')

    if [[ -z "$used_kb" ]] || [[ "$used_kb" -eq 0 ]]; then
        return 1
    fi

    usage_pct=$(awk -v used="$used_kb" -v total="$total_mem_bytes" 'BEGIN {
        used_bytes = used * 1024
        printf "%d", (used_bytes / total) * 100 + 0.5
    }')

    echo "$usage_pct"
}

usage_pct=$(get_memory_usage)

if [[ -z "$usage_pct" ]]; then
    "$SKETCHYBAR_BIN" --set "$NAME" icon=$'\uf1c0' label="--" label.color="$TEXT"
    exit 0
fi

color="$TEXT"

if (( usage_pct >= 95 )); then
    color="$CRITICAL"
elif (( usage_pct >= 80 )); then
    color="$WARNING"
fi

"$SKETCHYBAR_BIN" --set "$NAME" icon=$'\uf1c0' label="${usage_pct}%" label.color="$color"
