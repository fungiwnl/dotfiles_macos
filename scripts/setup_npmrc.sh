#!/bin/bash

set -e

NPMRC_PATH="${HOME}/.npmrc"
SCOPE="${NPM_SCOPE:-}"
REGISTRY_URL="https://npm.pkg.github.com/"
PLACEHOLDER_TOKEN="<your_auth_token_here>"

# Replace any existing "key=" line in ~/.npmrc so reruns don't clobber
# unrelated settings or duplicate keys.
set_npmrc() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  awk -v k="${key}=" 'index($0, k) != 1' "$NPMRC_PATH" >"$tmp"
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv "$tmp" "$NPMRC_PATH"
}

touch "$NPMRC_PATH"
chmod 600 "$NPMRC_PATH"

# Supply-chain hardening (npm 11+; npm 10 ignores these with a warning).
# Skip releases younger than 7 days and fail installs whose deps run
# unreviewed install scripts (approve via "allowScripts" in package.json).
echo "🛡️  Applying npm supply-chain hardening to ~/.npmrc..."
set_npmrc "min-release-age" "7"
set_npmrc "strict-allow-scripts" "true"

echo "🔐 This script sets up ~/.npmrc for authenticating with GitHub's npm registry."
echo "   This is required to be able to pull internal packages."
echo ""

if [[ -z "$SCOPE" ]]; then
  read -rp "📦 npm scope for GitHub Packages (e.g. @my-org, blank to skip): " SCOPE
  if [[ -z "$SCOPE" ]]; then
    echo "⏭️  No scope entered. Skipping registry auth setup."
    exit 0
  fi
fi

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
  read -rsp "🔑 Enter your GitHub Personal Access Token (PAT): " PAT
  echo ""

  if [[ -z "$PAT" ]]; then
    echo "⚠️ No token entered. Aborting."
    exit 1
  fi
else
  echo "❌ Invalid choice. Aborting."
  exit 1
fi

echo "📝 Updating ~/.npmrc..."
set_npmrc "${SCOPE}:registry" "$REGISTRY_URL"
set_npmrc "//npm.pkg.github.com/:_authToken" "$PAT"
# Internal packages come from our own registry, so let them update immediately.
set_npmrc "min-release-age-exclude[]" "${SCOPE}/*"

if [[ "$CHOICE" == "1" ]]; then
  echo ""
  echo "✅ .npmrc updated at $NPMRC_PATH"
  echo "📦 Authentication token saved. You're ready to use GitHub packages."

  echo ""
  echo "🔐 IMPORTANT: Make sure you authorize the Personal Access Token (PAT) via SSO"
  echo "   Visit https://github.com/settings/tokens and click 'Enable SSO' if needed."
  echo ""
  read -rp "✅ Press Enter once you have authorized the PAT with your org's SSO to finish setup..."
else
  echo "⚠️ Remember to replace '${PLACEHOLDER_TOKEN}' in ~/.npmrc with your actual GitHub token."
fi
