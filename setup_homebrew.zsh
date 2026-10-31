#!/usr/bin/env zsh

set -e

echo ""
echo "🍺 Starting Homebrew setup..."

if command -v brew >/dev/null 2>&1; then
  echo "✅ Homebrew is already installed — skipping installation."
else
  echo "📦 Homebrew not found. Installing..."
  # Pinned installer commit and its checksum; bump both values together.
  HOMEBREW_INSTALL_REF="09c62fc577ec170172b0a184060f141a2c622dc1"
  HOMEBREW_INSTALL_SHA256="5f333bbe53bc490e51e7ccb1df8779b3dd6ee73a1a7379efda216edb08ccb148"
  INSTALLER="$(mktemp)"
  curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALL_REF}/install.sh" -o "$INSTALLER"
  if ! echo "${HOMEBREW_INSTALL_SHA256}  ${INSTALLER}" | shasum -a 256 -c - >/dev/null; then
    echo "❌ Homebrew installer checksum mismatch. Aborting."
    rm -f "$INSTALLER"
    exit 1
  fi
  /bin/bash "$INSTALLER"
  rm -f "$INSTALLER"
  echo "🎉 Homebrew installation complete."
fi

echo ""
echo "Change default shell to zsh"
chsh -s /bin/zsh
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/zshrc/general.sh
source ~/.zshrc
echo "📚 Running 'brew bundle' to install packages from Brewfile..."
brew bundle --verbose --no-upgrade

echo ""
echo "✅ Homebrew setup complete."

