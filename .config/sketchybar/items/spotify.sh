#!/usr/bin/env bash

sketchybar --add item spotify right \
  --set spotify \
    drawing=off \
    icon.padding_left=12 \
    icon.padding_right=2 \
    label="Spotify -" \
    script="$PLUGIN_DIR/spotify.sh" \
    update_freq=5 \
    background.drawing=on \
    background.color="$SURFACE_0" \
    label.padding_left=6 \
    label.padding_right=14 \
    label.max_chars=20 \
    scroll_texts=off \
    click_script="open -a Spotify" \
  --subscribe spotify system_woke front_app_switched
