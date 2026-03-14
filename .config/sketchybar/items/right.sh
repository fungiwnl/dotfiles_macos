#!/usr/bin/env bash

sketchybar --add item clock right \
  --set clock \
    label="--" \
    script="$PLUGIN_DIR/clock.sh" \
    update_freq=10 \
    background.drawing=on \
    background.color="$SURFACE_0" \
    label.padding_left=14 \
    label.padding_right=14

sketchybar --add item battery right \
  --set battery \
    label="BAT --" \
    script="$PLUGIN_DIR/battery.sh" \
    update_freq=120 \
    background.drawing=on \
    background.color="$SURFACE_0" \
    label.padding_left=14 \
    label.padding_right=14 \
  --subscribe battery system_woke power_source_change

sketchybar --add item memory right \
  --set memory \
    label="MEM --" \
    script="$PLUGIN_DIR/memory.sh" \
    update_freq=15 \
    background.drawing=on \
    background.color="$SURFACE_0" \
    label.padding_left=14 \
    label.padding_right=14 \
  --subscribe memory system_woke

sketchybar --add item cpu right \
  --set cpu \
    label="CPU --" \
    script="$PLUGIN_DIR/cpu.sh" \
    update_freq=5 \
    background.drawing=on \
    background.color="$SURFACE_0" \
    label.padding_left=14 \
    label.padding_right=14 \
  --subscribe cpu system_woke

sketchybar --add item volume right \
  --set volume \
    label="VOL --" \
    script="$PLUGIN_DIR/volume.sh" \
    background.drawing=on \
    background.color="$SURFACE_0" \
    label.padding_left=14 \
    label.padding_right=14 \
    click_script="open 'x-apple.systempreferences:com.apple.preference.sound'" \
  --subscribe volume volume_change system_woke
