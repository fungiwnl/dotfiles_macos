#!/usr/bin/env bash

set -euo pipefail

SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
MAX_LABEL_LENGTH=20

trim_label() {
  local text="$1"
  local max_length="$2"

  if (( ${#text} <= max_length )); then
    printf '%s\n' "$text"
    return
  fi

  printf '%s...\n' "${text:0:max_length-3}"
}

spotify_info="$(osascript <<'APPLESCRIPT' 2>/dev/null || true
if application "Spotify" is not running then
  return "stopped"
end if

tell application "Spotify"
  set playback_state to player state as text
  if playback_state is not "playing" then
    return playback_state
  end if

  return playback_state & (ASCII character 9) & artist of current track & (ASCII character 9) & name of current track
end tell
APPLESCRIPT
)"

if [[ -z "$spotify_info" || "$spotify_info" != playing$'\t'* ]]; then
  "$SKETCHYBAR_BIN" --set "$NAME" drawing=off
  exit 0
fi

IFS=$'\t' read -r state artist title <<<"$spotify_info"

if [[ -z "$title" ]]; then
  "$SKETCHYBAR_BIN" --set "$NAME" drawing=off
  exit 0
fi

label="$title"

if [[ -n "$artist" ]]; then
  full_label="$artist - $title"
  if (( ${#full_label} <= MAX_LABEL_LENGTH )); then
    label="$full_label"
  fi
fi

label="$(trim_label "$label" "$MAX_LABEL_LENGTH")"

"$SKETCHYBAR_BIN" --set "$NAME" drawing=on icon=$'\uf1bc' label="$label"
