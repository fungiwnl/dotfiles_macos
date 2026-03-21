#!/usr/bin/env bash

set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

"$SKETCHYBAR_BIN" --set "$NAME" icon=$'\uf017' label="$(date '+%a %d %b %H:%M')"
