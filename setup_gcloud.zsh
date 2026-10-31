#!/usr/bin/env zsh

set -euo pipefail

INSTALL_DIR="$HOME/google-cloud-sdk"
# Pinned release; bump together with the checksums in archive_sha256.
# `gcloud components update` keeps an existing install current.
GCLOUD_VERSION="591.0.0"

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
    *)
      log "❌ Unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac

  printf 'google-cloud-cli-%s-%s-%s.tar.gz\n' "$GCLOUD_VERSION" "$os_name" "$arch_name"
}

# Checksums from the Homebrew gcloud-cli cask for the same version.
archive_sha256() {
  case "$1" in
    *-darwin-arm.tar.gz)    printf '%s\n' "85cb726919838faff48bfba7cf676b691b0202bec7c25aabdc116649c6843242" ;;
    *-darwin-x86_64.tar.gz) printf '%s\n' "89c3ca942eb609293dff5b549ec6bae5d9ec41633a132aeb8dd8087a915ab3a0" ;;
    *-linux-arm.tar.gz)     printf '%s\n' "f5e5df0433f77c0e7f5df9fd4bce2e46c7b7967e79cf66e31b1164d3d4c86546" ;;
    *-linux-x86_64.tar.gz)  printf '%s\n' "78c570f5fcfe58a9311bd98c06b75530595e3cae6277aad75a676a39e6ee7b63" ;;
  esac
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

  log "🔏 Verifying checksum..."
  if ! echo "$(archive_sha256 "$ARCHIVE_NAME")  $ARCHIVE_PATH" | shasum -a 256 -c - >/dev/null; then
    log "❌ Checksum mismatch for $ARCHIVE_NAME. Aborting."
    exit 1
  fi

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
