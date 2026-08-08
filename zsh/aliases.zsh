##############################
# Aliases
##############################
alias -g L="|less"
alias -g TL='| tail -20'
alias -g NUL="> /dev/null 2>&1"

hgrep() { history | grep "$1"; }
alias c='clear'
#alias ll='ls -la'
alias ls='eza --icons=always'
alias ll='eza --all --long --header --icons --git'
alias cat='bat --paging=never'
alias catp='bat'  # With paging
alias du='dust'
alias ps='procs'
alias psa='procs --tree'  # Process tree view
alias find='fd'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../../'
alias grep='grep --color=auto'
alias vi='nvim'
alias wget='wget -c'
alias x='exit'
alias biggest='dust -r -n 40'  # Top 40 largest dirs/files
alias urldecode='python3 -c "import sys; from urllib.parse import unquote_plus; print(unquote_plus(sys.argv[1]))"'
alias urlencode='python3 -c "import sys; from urllib.parse import quote_plus; print(quote_plus(sys.argv[1]))"'

# aliases that use xtitle
alias top='xtitle Processes on $HOST && top'
alias make='xtitle Making $(basename $PWD) ; make'



# PostgreSQL aliases - auto-detect installed major version
_pg_version=$(ls /opt/homebrew/opt/ 2>/dev/null | grep -E '^postgresql@[0-9]+$' | sort -V | tail -1)
if [[ -n "$_pg_version" ]]; then
  alias start_postgres="brew services start $_pg_version"
  alias stop_postgres="brew services stop $_pg_version"
fi
unset _pg_version

alias start_memcached='/usr/local/opt/memcached/bin/memcached'
alias stop_memcached='killall memcached'

alias brewski='brew update && brew upgrade && brew cleanup; brew doctor'

# Other tools
alias fzfp='fzf --preview "bat --color=always --style=header,grid --line-range :500 {}"'
