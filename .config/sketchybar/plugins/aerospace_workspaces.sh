#!/usr/bin/env bash

set -euo pipefail

AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"

source "$CONFIG_DIR/colors.sh"

contains_workspace() {
  local list="$1"
  local workspace="$2"

  case " $list " in
    *" $workspace "*) return 0 ;;
    *) return 1 ;;
  esac
}

focused_workspace="${AEROSPACE_FOCUSED_WORKSPACE:-}"

if [[ -z "$focused_workspace" ]]; then
  focused_workspace="$($AEROSPACE_BIN list-workspaces --focused 2>/dev/null | tr -d '\n')"
fi

all_workspaces="$($AEROSPACE_BIN list-workspaces --all 2>/dev/null | tr '\n' ' ')"
occupied_workspaces="$($AEROSPACE_BIN list-windows --all --format '%{workspace}' 2>/dev/null | tr '\n' ' ')"
visible_workspaces="$($AEROSPACE_BIN list-workspaces --all --format '%{workspace}|%{workspace-is-visible}|%{workspace-is-focused}' 2>/dev/null | while IFS='|' read -r workspace is_visible is_focused; do
  if [[ "$is_visible" == "true" || "$is_focused" == "true" ]]; then
    printf '%s ' "$workspace"
  fi
done)"

for workspace in $all_workspaces; do
  drawing=off
  background_color="$SURFACE_0"
  label_color="$TEXT_MUTED"

  if contains_workspace "$occupied_workspaces $visible_workspaces $focused_workspace" "$workspace"; then
    drawing=on
  fi

  if [[ "$workspace" == "$focused_workspace" ]]; then
    background_color="$ACCENT"
    label_color="$BASE"
  fi

  "$SKETCHYBAR_BIN" --set "space.$workspace" \
    drawing="$drawing" \
    background.color="$background_color" \
    label.color="$label_color"
done
