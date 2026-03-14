#!/usr/bin/env bash

sketchybar --add item front_app center \
  --set front_app \
    label="APP Desktop" \
    script="$PLUGIN_DIR/front_app.sh" \
    background.drawing=on \
    background.color="$SURFACE_0" \
    label.padding_left=14 \
    label.padding_right=14 \
    label.max_chars=40 \
    scroll_texts=on \
  --subscribe front_app front_app_switched system_woke
