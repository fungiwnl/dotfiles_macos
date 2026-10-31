#!/bin/bash

set -e

echo "📧 Enter your Git email address:"
read -r EMAIL

echo "🔑 Enter a name for this SSH key (e.g., github, gitlab, bitbucket):"
read -r KEYNAME

KEY_PATH="${HOME}/.ssh/id_ed25519_${KEYNAME}"
HOST_ALIAS="git-${KEYNAME}"

if [[ -f "$KEY_PATH" ]]; then
  echo "⚠️ SSH key already exists at $KEY_PATH"
  read -rp "❓ Overwrite it? [y/N]: " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "🚫 Aborting to avoid overwriting existing key."
    exit 1
  fi
  rm -f "$KEY_PATH" "$KEY_PATH.pub"
fi

echo "🔐 Generating SSH key..."
echo "🔒 Choose a passphrase (stored in the macOS keychain, so you only type it once)."
ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -q

echo "🚀 Starting ssh-agent..."
eval "$(ssh-agent -s)"

echo "➕ Adding SSH key to agent and macOS keychain..."
ssh-add --apple-use-keychain "$KEY_PATH"

pbcopy < "${KEY_PATH}.pub"
echo "📋 Public key copied to clipboard:"
cat "${KEY_PATH}.pub"

CONFIG_ENTRY="
Host ${HOST_ALIAS}
    HostName github.com
    User git
    IdentityFile ${KEY_PATH}
    UseKeychain yes
    AddKeysToAgent yes
"

if grep -q "Host ${HOST_ALIAS}" ~/.ssh/config 2>/dev/null; then
  echo "ℹ️ SSH config already contains an entry for '${HOST_ALIAS}' — skipping."
else
  echo "📝 Adding SSH config entry for '${HOST_ALIAS}'..."
  echo "$CONFIG_ENTRY" >> ~/.ssh/config
  echo "✅ Added. Use 'git@${HOST_ALIAS}:user/repo.git' as your repo URL."
fi

echo "✍️  Using this key to sign commits (machine-local ~/.gitconfig-local)..."
git config --file ~/.gitconfig-local user.signingkey "${KEY_PATH}.pub"
git config --file ~/.gitconfig-local commit.gpgSign true
git config --file ~/.gitconfig-local tag.gpgSign true
# Lets `git log --show-signature` verify our own signatures locally.
ALLOWED_SIGNERS="${HOME}/.config/git/allowed_signers"
mkdir -p "$(dirname "$ALLOWED_SIGNERS")"
echo "$(git config user.email) $(cat "${KEY_PATH}.pub")" >>"$ALLOWED_SIGNERS"
git config --file ~/.gitconfig-local gpg.ssh.allowedSignersFile "$ALLOWED_SIGNERS"

echo ""
echo "🚀 SSH key '${KEYNAME}' setup complete."
echo "📌 Your public key has been copied to the clipboard."

echo ""
echo "🔗 Please add it to your GitHub account here:"
echo "    👉 https://github.com/settings/keys"
echo ""
echo "🔒 Paste the public key into the 'SSH key' field, give it a name (e.g., ${KEYNAME}), and save."
echo "✍️  Add it a second time with Key type 'Signing Key' so signed commits show as Verified."

read -rp "✅ Press Enter after you've added the key to GitHub to continue..."
