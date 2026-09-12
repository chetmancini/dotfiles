##############################
# Aliases
##############################
alias -g L="|less"
alias -g TL='| tail -20'
alias -g NUL="> /dev/null 2>&1"

hgrep() { history | grep "$1"; }
alias c='clear'
#alias ll='ls -la'
if command -v eza >/dev/null 2>&1; then
alias ls='eza --icons=always'
alias ll='eza --all --long --header --icons --git'
else
  alias ll='ls -al'
fi
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never'
command -v bat >/dev/null 2>&1 && alias catp='bat'  # With paging
command -v dust >/dev/null 2>&1 && alias du='dust'
command -v procs >/dev/null 2>&1 && alias ps='procs'
command -v procs >/dev/null 2>&1 && alias psa='procs --tree'  # Process tree view
command -v fd >/dev/null 2>&1 && alias find='fd'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../../'
alias grep='grep --color=auto'
command -v nvim >/dev/null 2>&1 && alias vi='nvim'
alias wget='wget -c'
alias x='exit'
alias biggest='dust -r -n 40'  # Top 40 largest dirs/files
alias urldecode='python3 -c "import sys; from urllib.parse import unquote_plus; print(unquote_plus(sys.argv[1]))"'
alias urlencode='python3 -c "import sys; from urllib.parse import quote_plus; print(quote_plus(sys.argv[1]))"'

# aliases that use xtitle
command -v xtitle >/dev/null 2>&1 && alias top='xtitle Processes on $HOST && top'
command -v xtitle >/dev/null 2>&1 && alias make='xtitle Making $(basename $PWD) ; make'



# PostgreSQL aliases - auto-detect installed major version
_pg_version=""
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
_pg_version=$(command ls "$HOMEBREW_PREFIX/opt/" 2>/dev/null | grep -E '^postgresql@[0-9]+$' | sort -V | tail -1)
fi
if [[ -n "$_pg_version" ]]; then
  alias start_postgres="brew services start $_pg_version"
  alias stop_postgres="brew services stop $_pg_version"
fi
unset _pg_version

alias brewski='brew update && brew upgrade && brew cleanup; brew doctor'

# Other tools
alias fzfp='fzf --preview "bat --color=always --style=header,grid --line-range :500 {}"'
