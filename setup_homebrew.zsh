#!/usr/bin/env zsh

echo "\n<<< Starting Homebrew Setup >>>\n"

if [ -x "$(command -v brew)" ]
then
  echo "\n<<< Brew exists, skipping install >>>\n"
else
  echo "\n<<< Brew doesn't exist, continuing with install >>>\n"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "\n<<< Running Brew bundle >>>\n"
brew bundle --verbose
