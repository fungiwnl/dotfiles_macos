#!/bin/bash

set -e

NPMRC_PATH="${HOME}/.npmrc"
SCOPE="@kmartau"
REGISTRY_URL="https://npm.pkg.github.com/"
PLACEHOLDER_TOKEN="<your_auth_token_here>"

echo "🔐 This script sets up ~/.npmrc for authenticating with GitHub's npm registry."
echo "   This is required to be able to pull internal packages."
echo ""

echo "Please choose an option:"
echo "1. Enter GitHub Personal Access Token (PAT) now"
echo "2. Set up with placeholder (edit later manually)"
echo "3. Cancel setup"
read -rp "👉 Enter choice [1/2/3]: " CHOICE

if [[ "$CHOICE" == "3" ]]; then
  echo "❌ Setup canceled."
  exit 0
elif [[ "$CHOICE" == "2" ]]; then
  PAT="$PLACEHOLDER_TOKEN"
elif [[ "$CHOICE" == "1" ]]; then
  echo ""
  echo "🔗 To generate a GitHub Personal Access Token (PAT), visit:"
  echo "    https://github.com/settings/tokens?type=beta"
  echo "👉 Required scopes: 'read:packages' (and 'write:packages' if publishing)"
  echo ""
  read -rp "🔑 Enter your GitHub Personal Access Token (PAT): " PAT
  echo ""

  if [[ -z "$PAT" ]]; then
    echo "⚠️ No token entered. Aborting."
    exit 1
  fi
else
  echo "❌ Invalid choice. Aborting."
  exit 1
fi

echo "📝 Writing ~/.npmrc file..."
cat <<EOF >"$NPMRC_PATH"
${SCOPE}:registry=${REGISTRY_URL}
//npm.pkg.github.com/:_authToken=${PAT}
EOF

chmod 600 "$NPMRC_PATH"

if [[ "$CHOICE" == "1" ]]; then
  echo ""
  echo "✅ .npmrc created at $NPMRC_PATH"
  if [[ "$PAT" == "$PLACEHOLDER_TOKEN" ]]; then
    echo "⚠️ Remember to replace '<your_auth_token_here>' with your actual GitHub token."
  else
    echo "📦 Authentication token saved. You're ready to use GitHub packages."
  fi

  echo ""
  echo "🔐 IMPORTANT: Make sure you authorize the Personal Access Token (PAT) via SSO"
  echo "   Visit https://github.com/settings/tokens and click 'Enable SSO' if needed."
  echo ""
  read -rp "✅ Press Enter once you have authorized the PAT with Kmart SSO to finish setup..."
fi
