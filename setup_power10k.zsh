#!/usr/bin/env zsh

set -e

echo ""
echo "🍺 Starting Powerlevel10k set up..."

P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

if [ -d "$P10K_DIR" ]; then
  echo ""
  echo "⚠️  Powerlevel10k already exists at $P10K_DIR. Skipping clone."
else
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  echo ""
  echo "✅ Power10k setup complete."
fi
