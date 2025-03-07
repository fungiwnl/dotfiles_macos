eval "$(fnm env --use-on-cd)"
source <(fzf --zsh)
export PATH=$(go env GOPATH)/bin:$PATH

export PNPM_HOME="/Users/$USER/Library/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac

alias ls="eza -lah"
alias vi="nvim"
alias vim="nvim"
alias ta="tmux attach"
alias td="tmux detach"
alias diff="diff --color"
alias lg="lazygit"
alias bbd="brew bundle dump --describe --file=~/dotfiles_macos/Brewfile --force"
alias glog='git log --oneline | fzf --preview "git show --color=always {1}"'
alias fkill='kill -9 $(ps aux | fzf -m | awk "{print $2}")'
