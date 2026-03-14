#!/usr/bin/env bash

while IFS= read -r workspace; do
  [[ -n "$workspace" ]] || continue

  sketchybar --add item "space.$workspace" left \
    --set "space.$workspace" \
      drawing=off \
      label="$workspace" \
      click_script="/opt/homebrew/bin/aerospace workspace $workspace" \
      background.drawing=on \
      background.color="$SURFACE_0" \
      label.color="$TEXT_MUTED" \
      label.padding_left=12 \
      label.padding_right=12 \
      padding_left=2 \
      padding_right=2
done < <(/opt/homebrew/bin/aerospace list-workspaces --all)

sketchybar --add item workspace_state left \
  --set workspace_state \
    drawing=off \
    label.drawing=off \
    icon.drawing=off \
    background.drawing=off \
    updates=on \
    script="$PLUGIN_DIR/aerospace_workspaces.sh" \
    update_freq=5 \
  --subscribe workspace_state aerospace_workspace_change system_woke
