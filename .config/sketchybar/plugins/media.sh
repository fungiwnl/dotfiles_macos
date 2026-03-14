#!/usr/bin/env bash

set -euo pipefail

JQ_BIN="${JQ_BIN:-/opt/homebrew/bin/jq}"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

if [[ -z "${INFO:-}" ]]; then
  "$SKETCHYBAR_BIN" --set "$NAME" drawing=off
  exit 0
fi

state="$(printf '%s' "$INFO" | "$JQ_BIN" -r '.state // .player_state // .playbackRate // empty' 2>/dev/null || true)"
title="$(printf '%s' "$INFO" | "$JQ_BIN" -r '.title // .name // empty' 2>/dev/null || true)"
artist="$(printf '%s' "$INFO" | "$JQ_BIN" -r '.artist // .albumArtist // .author // empty' 2>/dev/null || true)"

case "$state" in
  paused|stopped|0)
    "$SKETCHYBAR_BIN" --set "$NAME" drawing=off
    exit 0
    ;;
esac

if [[ -z "$title" ]]; then
  "$SKETCHYBAR_BIN" --set "$NAME" drawing=off
  exit 0
fi

label="NOW $title"

if [[ -n "$artist" ]]; then
  label="NOW $artist - $title"
fi

"$SKETCHYBAR_BIN" --set "$NAME" drawing=on label="$label"
