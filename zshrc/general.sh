eval "$(fnm env --use-on-cd --shell zsh)"
eval "$(pyenv init --no-rehash -)"
eval "$(direnv hook zsh)"
source "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh"

if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then
    source "$HOME/google-cloud-sdk/path.zsh.inc"
fi

if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then
    source "$HOME/google-cloud-sdk/completion.zsh.inc"
fi

export PNPM_HOME="/Users/$USER/Library/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac

export JAVA_HOME='/opt/homebrew/opt/openjdk@17'
export PATH="$JAVA_HOME/bin:$PATH"

#Android
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export PATH="$PATH:$ANDROID_HOME/emulator"
export PATH="$PATH:$ANDROID_HOME/build-tools/35.0.0"
export PATH="$PATH:/opt/homebrew/Caskroom/android-platform-tools/36.0.0/platform-tools"
export PATH="$PATH:/opt/homebrew/Caskroom/android-commandlinetools/13114758/cmdline-tools/bin"


# General aliases
alias ls="eza -lah"
alias vi="nvim"
alias vim="nvim"
alias ta="tmux attach"
alias td="tmux detach"
alias tarc="tmux attach -t rc"
alias diff="diff --color"
alias lg="lazygit"
alias ld="lazydocker"
alias bbd="brew bundle dump --file=~/dotfiles_macos/Brewfile --force"
alias glog='git log --oneline | fzf --preview "git show --color=always {1}"'
alias fkill='kill -9 $(ps aux | fzf -m | awk "{print $2}")'
alias screenrecord="osascript -e 'tell application \"QuickTime Player\" to activate' -e 'tell application \"QuickTime Player\" to start (new screen recording)'"
alias force-update="bash ~/dotfiles_macos/scripts/force-update.sh"
alias ip='curl -fsS --max-time 5 https://api.ipify.org | tee >(pbcopy) && echo'
alias weather="curl wttr.in"

# Toggle sleep entirely (incl. lid closed, on battery). caffeinate can't stop clamshell sleep.
nosleep_toggle() {
    if pmset -g | grep -q 'SleepDisabled[[:space:]]*1'; then
        sudo pmset -a disablesleep 0 && echo "😴 Sleep enabled"
    else
        sudo pmset -a disablesleep 1 && echo "☕ Sleep disabled (lid closed won't sleep)"
    fi
}

alias nosleep="nosleep_toggle"

browsh() {
    local browsh_bin
    browsh_bin="$(whence -p browsh 2>/dev/null || true)"

    if [[ -n "$browsh_bin" ]]; then
        "$browsh_bin" "$@"
        return
    fi

    docker run --rm -it browsh/browsh "$@"
}

#Share shell history across tmux sessions
setopt INC_APPEND_HISTORY  # Append commands to history file immediately
setopt SHARE_HISTORY       # Share history across all sessions
setopt HIST_IGNORE_DUPS    # Ignore duplicate commands
setopt HIST_IGNORE_SPACE   # Ignore commands starting with a space
export HISTFILE=~/.zsh_history
export HISTSIZE=10000      # Number of commands to keep in memory
export SAVEHIST=10000      # Number of commands to save in file
export HISTCONTROL=ignoredups:ignorespace
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTFILE=~/.bash_history
PROMPT_COMMAND="history -a; history -n; $PROMPT_COMMAND"

grepdocs() {
    local dir="${1:-~/docs}"  # Default to ~/docs
    local original_dir="$PWD"  # Store current directory
    if [ ! -d "$dir" ]; then
        echo "Error: Directory '$dir' does not exist."
        return 1
    fi
    cd "$dir" || return 1  # Change to the specified directory
    nvim .                 # Open nvim in the directory
    cd "$original_dir"     # Return to the original directory
}
eval "$(/opt/homebrew/bin/brew shellenv)"

rgh() {
    rg --no-heading --with-filename --line-number --column --smart-case --hidden --no-ignore-dot --glob '!.git/**' --glob '!node_modules/**' "$@"
}
eval "$(/opt/homebrew/bin/brew shellenv)"

google() {
    if [ $# -eq 0 ]; then
        open -a "Brave Browser" "https://www.google.com"
        return
    fi
    local query
    query=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote_plus(" ".join(sys.argv[1:])))' "$@")
    open -a "Brave Browser" "https://www.google.com/search?q=$query"
}

# Go
export PATH="$PATH:$HOME/go/bin"
