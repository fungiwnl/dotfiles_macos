#!/usr/bin/env zsh

set -e

echo ""
echo "🍺 Starting Homebrew setup..."

if command -v brew >/dev/null 2>&1; then
  echo "✅ Homebrew is already installed — skipping installation."
else
  echo "📦 Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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

