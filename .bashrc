##############################
# Minimal bashrc (zsh is primary shell)
##############################

export EDITOR="nvim"

##############################
# Aliases
##############################
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias grep='grep --color=auto'
alias vi='nvim'
alias x='exit'

# Git
alias gs='git status -sb'
alias gb='git branch -vv'
alias gf='git fetch --all --prune'
alias gch='git checkout'
alias gaa='git add -A'
alias gd='git diff'
alias gpush='git push'
alias gpull='git pull --prune'

##############################
# Functions
##############################
h() {
    history | grep -- "${1:-}"
}

_clipboard_copy() {
    if [[ "$(uname)" == "Darwin" ]]; then
        pbcopy
    elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        xsel --clipboard
    else
        echo "Error: No clipboard utility found (pbcopy, xclip, or xsel)" >&2
        return 1
    fi
}

function cpbranch() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        git rev-parse --abbrev-ref HEAD | tr -d '\n' | _clipboard_copy
    else
        echo "not in a repo" >&2
        return 1
    fi
}

# fzf
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
