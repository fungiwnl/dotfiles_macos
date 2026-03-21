#!/usr/bin/env bash

set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

source "$CONFIG_DIR/colors.sh"

get_memory_usage() {
    local total_mem_bytes page_size usage_pct vm_stats
    local anonymous_pages wired_pages compressor_pages

    total_mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || return 1)
    page_size=$(sysctl -n hw.pagesize 2>/dev/null || return 1)
    vm_stats=$(vm_stat 2>/dev/null || return 1)

    read -r anonymous_pages wired_pages compressor_pages < <(
        printf '%s\n' "$vm_stats" | awk -F': *' '
            /^Anonymous pages/ {
                gsub(/\./, "", $2)
                anonymous = $2
            }
            /^Pages wired down/ {
                gsub(/\./, "", $2)
                wired = $2
            }
            /^Pages occupied by compressor/ {
                gsub(/\./, "", $2)
                compressor = $2
            }
            END {
                print anonymous, wired, compressor
            }
        '
    )

    if [[ -z "$anonymous_pages" ]] || [[ -z "$wired_pages" ]] || [[ -z "$compressor_pages" ]]; then
        return 1
    fi

    usage_pct=$(awk -v anonymous="$anonymous_pages" -v wired="$wired_pages" -v compressor="$compressor_pages" -v page_size="$page_size" -v total="$total_mem_bytes" 'BEGIN {
        used_bytes = (anonymous + wired + compressor) * page_size
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
