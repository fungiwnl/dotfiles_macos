#!/usr/bin/env bash

sketchybar --add item media right \
  --set media \
    drawing=off \
    label="NOW -" \
    script="$PLUGIN_DIR/media.sh" \
    background.drawing=on \
    background.color="$SURFACE_0" \
    label.padding_left=14 \
    label.padding_right=14 \
    label.max_chars=48 \
    scroll_texts=on \
  --subscribe media media_change system_woke
