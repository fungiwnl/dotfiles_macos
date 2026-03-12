typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

for FILE in ~/zshrc/*; do
    source $FILE
done

# pnpm
export PNPM_HOME="/Users/bfung/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

ff() {
  local file
  file=$(fd . --type f --extension "$1" | fzf --preview 'bat --color=always {}' 2>/dev/null)file=$(find . -type f -name "*$1" | fzf --preview 'bat --color=always {}' 2>/dev/null)
if [[ -n "$file" ]]; then
    open "$file"
  fi
}

## [Completion]
## Completion scripts setup. Remove the following line to uninstall
[[ -f /Users/bfung/.dart-cli-completion/zsh-config.zsh ]] && . /Users/bfung/.dart-cli-completion/zsh-config.zsh || true
## [/Completion]


# bun completions
[ -s "/Users/bfung/.bun/_bun" ] && source "/Users/bfung/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
