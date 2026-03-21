#!/usr/bin/env zsh

set -euo pipefail

INSTALL_DIR="$HOME/google-cloud-sdk"

log() {
  printf '%s\n' "$1"
}

find_supported_python() {
  local candidate
  local version

  if ! command -v python3 >/dev/null 2>&1; then
    return 1
  fi

  candidate="$(command -v python3)"
  version="$($candidate -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")' 2>/dev/null || true)"

  case "$version" in
    3.10|3.11|3.12|3.13|3.14)
      printf '%s\n' "$candidate"
      return 0
      ;;
  esac

  return 1
}

archive_name() {
  local os_name
  local arch_name

  case "$(uname -s)" in
    Darwin)
      os_name="darwin"
      ;;
    Linux)
      os_name="linux"
      ;;
    *)
      log "❌ Unsupported operating system: $(uname -s)"
      exit 1
      ;;
  esac

  case "$(uname -m)" in
    arm64|aarch64)
      arch_name="arm"
      ;;
    x86_64|amd64)
      arch_name="x86_64"
      ;;
    i386|i686)
      arch_name="x86"
      ;;
    *)
      log "❌ Unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac

  printf 'google-cloud-cli-%s-%s.tar.gz\n' "$os_name" "$arch_name"
}

echo ""
log "☁️ Starting Google Cloud CLI setup..."

INSTALL_ARGS=(
  --quiet
  --usage-reporting=false
  --path-update=false
  --bash-completion=false
  --rc-path=false
)

if [[ -x "$INSTALL_DIR/bin/gcloud" ]]; then
  log "✅ Google Cloud CLI is already installed at $INSTALL_DIR — skipping installation."
else
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  ARCHIVE_NAME="$(archive_name)"
  DOWNLOAD_URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/${ARCHIVE_NAME}"
  ARCHIVE_PATH="$TMP_DIR/$ARCHIVE_NAME"

  log "📦 Downloading Google Cloud CLI archive..."
  curl -fsSL "$DOWNLOAD_URL" -o "$ARCHIVE_PATH"

  log "📂 Extracting archive..."
  tar -xf "$ARCHIVE_PATH" -C "$TMP_DIR"

  if [[ -e "$INSTALL_DIR" ]]; then
    log "♻️ Replacing incomplete installation at $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
  fi

  mv "$TMP_DIR/google-cloud-sdk" "$INSTALL_DIR"

  PYTHON_BIN="$(find_supported_python || true)"
  if [[ -n "$PYTHON_BIN" ]]; then
    export CLOUDSDK_PYTHON="$PYTHON_BIN"
    INSTALL_ARGS+=(--install-python=false)
    log "🐍 Using Python at $PYTHON_BIN"
  fi

  log "⚙️ Finalizing Google Cloud CLI install..."
  "$INSTALL_DIR/install.sh" "${INSTALL_ARGS[@]}" >/dev/null
fi

export PATH="$INSTALL_DIR/bin:$PATH"

gcloud version >/dev/null

log "🎉 Google Cloud CLI installation complete."

echo ""
log "Next steps:"
log "  - Open a new terminal or run 'source ~/.zshrc' to load gcloud on PATH."
log "  - Run 'gcloud init' to sign in and choose a default project."
log "  - Run 'gcloud auth application-default login' if you need ADC locally."
