##############################
# Minimal bashrc (zsh is primary shell)
##############################

export EDITOR="nvim"

##############################
# Aliases
##############################
alias h='history | grep $1'
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
function cpbranch() {
    git rev-parse --abbrev-ref HEAD | tr -d '\n' | pbcopy
}

# fzf
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
