#!/usr/bin/env bash

set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

app_name="${INFO:-}"

if [[ -z "$app_name" ]]; then
  app_name="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true)"
fi

if [[ -z "$app_name" ]]; then
  app_name="Desktop"
fi

"$SKETCHYBAR_BIN" --set "$NAME" label="APP $app_name"
