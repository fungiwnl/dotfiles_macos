#!/usr/bin/env bash

set -euo pipefail

TMUX_CONF="${HOME}/.tmux.conf"
TMUX_PLUGIN_DIR="${HOME}/.tmux/plugins"
TPM_DIR="${TMUX_PLUGIN_DIR}/tpm"

# Pinned commits (TPM itself clones plugins at HEAD); bump deliberately.
pinned_commit() {
  case "$1" in
    tpm) echo 99469c4a9b1ccf77fade25842dc7bafbc8ce9946 ;;
    tmux-yank) echo acfd36e4fcba99f8310a7dfb432111c242fe7392 ;;
    tmux-resurrect) echo cff343cf9e81983d3da0c8562b01616f12e8d548 ;;
    tmux-continuum) echo 0698e8f4b17d6454c71bf5212895ec055c578da0 ;;
  esac
}

pin_plugin() {
  local name="$1"
  git -C "${TMUX_PLUGIN_DIR}/${name}" -c advice.detachedHead=false checkout --quiet "$(pinned_commit "$name")" ||
    fail "Could not check out pinned commit for ${name}"
}

log() {
  printf '[tmux-plugins] %s\n' "$1"
}

fail() {
  printf '[tmux-plugins] %s\n' "$1" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Missing required command: $1"
  fi
}

require_command git
require_command tmux

if [[ ! -f "$TMUX_CONF" ]]; then
  fail "Missing ${TMUX_CONF}. Link your tmux config before installing plugins."
fi

mkdir -p "$TMUX_PLUGIN_DIR"

if [[ ! -d "$TPM_DIR" ]]; then
  log "Cloning TPM into ${TPM_DIR}"
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
  pin_plugin tpm
else
  log "TPM already installed at ${TPM_DIR}"
fi

if [[ ! -x "$TPM_DIR/bin/install_plugins" ]]; then
  fail "TPM install script not found at ${TPM_DIR}/bin/install_plugins"
fi

log "Installing tmux plugins from ${TMUX_CONF}"
tmux start-server
tmux source-file "$TMUX_CONF"
"$TPM_DIR/bin/install_plugins"

missing_plugins=()
for plugin_dir in tmux-yank tmux-resurrect tmux-continuum; do
  if [[ ! -d "${TMUX_PLUGIN_DIR}/${plugin_dir}" ]]; then
    missing_plugins+=("$plugin_dir")
  else
    pin_plugin "$plugin_dir"
  fi
done

if (( ${#missing_plugins[@]} > 0 )); then
  fail "Missing plugin directories after install: ${missing_plugins[*]}"
fi

log "Tmux plugins installed successfully"
