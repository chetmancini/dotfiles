
#Path to your oh-my-zsh configuration.
export ZSH=$HOME/dotfiles/oh-my-zsh

######################
# oh-my-zsh
######################
ZSH_THEME="chetmancini"

alias zshconfig="vim ~/dotfiles/.zshrc"
alias ohmyzsh="vim ~/dotfiles/oh-my-zsh"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
COMPLETION_WAITING_DOTS="true"

zstyle ':completion:*' hosts off

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# removed: emacs rbenv sublime rvm
plugins=(
    1password
    battery
    brew
    bundler
    bun
    command-not-found
    dbt
    docker-compose
    encode64
    eza
    history
    history-substring-search
    gh
    git-commit
    gitfast
    macos
    pip
    python
    redis-cli
    thefuck
    tldr
    web-search
)

source $ZSH/oh-my-zsh.sh

##############################
# Variables
##############################
# ZSH Options
DEFAULT_USER="chet"
setopt AUTO_CD
HISTFILESIZE=1000000
HISTSIZE=1000000
SAVEHIST=1000000
# If I type cd and then cd again, only save the last one
setopt HIST_IGNORE_DUPS
setopt INC_APPEND_HISTORY    # Write history immediately, not on shell exit
setopt HIST_IGNORE_SPACE     # Commands starting with space won't be saved
setopt HIST_SAVE_NO_DUPS
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
# reduce blanks
setopt HIST_REDUCE_BLANKS
# Save the time and how long a command ran
setopt EXTENDED_HISTORY
# Spell check commands!  (Sometimes annoying)
setopt CORRECT
# beeps are annoying
setopt NO_BEEP



##############################
# Editor Settings
##############################
setopt VI
export EDITOR="nvim"
bindkey -v

# vi style incremental search
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey '^P' history-search-backward
bindkey '^N' history-search-forward

# Edit command line in $EDITOR (Ctrl-X Ctrl-E)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Vi mode cursor shape: block for NORMAL, beam for INSERT
function zle-keymap-select {
  if [[ $KEYMAP == vicmd ]] || [[ $1 == 'block' ]]; then
    echo -ne '\e[1 q'  # Block cursor
  elif [[ $KEYMAP == main ]] || [[ $KEYMAP == viins ]] || [[ $1 == 'beam' ]]; then
    echo -ne '\e[5 q'  # Beam cursor
  fi
}
zle -N zle-keymap-select

# Start with beam cursor
function zle-line-init { echo -ne '\e[5 q' }
zle -N zle-line-init

# Reset cursor on command execution
preexec() { echo -ne '\e[5 q' }

##############################
# Source other files based on platform/organization
##############################
platform='unknown'
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
  source ~/dotfiles/linux_specific.sh
elif [[ "$unamestr" == 'Darwin' ]]; then
  source ~/dotfiles/mac_specific.sh
fi

##############################
# Paths
##############################
export BREW_PATH=/opt/homebrew/bin
export JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
export CODE_DIR="$HOME/code"
export DEV_DIR="$HOME/Development"
# NODE_PATH removed - deprecated in modern Node.js/npm
export NPM_PATH=/usr/local/share/npm/bin
export NPM_GLOBAL_BIN="$HOME/.npm-global/bin"
export PNPM_HOME="$HOME/Library/pnpm"
export UV_PATH="$HOME/.local/bin"
export BUN_INSTALL="$HOME/.bun"
export MYSQL_HOME=/usr/local/mysql/bin
export USR_LOCAL_HOME=/usr/local/bin
export USR_LOCAL_SBIN=/usr/local/sbin
export PERSONAL_BIN=$HOME/dotfiles/bin
export MODULAR_HOME="$HOME/.modular"
export LMSTUDIO_PATH="$HOME/.lmstudio/bin"
export ZEROBREW_PATH="/opt/zerobrew/prefix/bin"
export OPENCODE_PATH="$HOME/.opencode/bin"
export LMSTUDIO_CACHE_PATH="$HOME/.cache/lm-studio/bin"
export ANTIGRAVITY_PATH="$HOME/.antigravity/antigravity/bin"
#export PATH=/usr/local/anaconda3/bin:/opt/homebrew/anaconda3/bin:$PATH
# Build PATH dynamically, only adding directories that exist
path_add() {
    for dir in "$@"; do
        if [[ -d "$dir" ]]; then
            PATH="$dir:$PATH"
        fi
    done
}

# Add paths in order (later entries have higher priority)
path_add \
    "$LMSTUDIO_PATH" \
    "$LMSTUDIO_CACHE_PATH" \
    "$MODULAR_HOME/bin" \
    "$BREW_PATH" \
    "$PERSONAL_BIN" \
    "$NPM_PATH" \
    "$USR_LOCAL_SBIN" \
    "$USR_LOCAL_HOME" \
    "$ZEROBREW_PATH" \
    "$UV_PATH" \
    "$MYSQL_HOME" \
    "$NPM_GLOBAL_BIN" \
    "$PNPM_HOME" \
    "$BUN_INSTALL/bin" \
    "$JAVA_HOME/bin" \
    "$OPENCODE_PATH" \
    "$ANTIGRAVITY_PATH" \
    "$HOME/bin"

export PATH
export CLASSPATH=$HOME/lib/jars




##############################
# Aliases
##############################
#alias docker="docker $(docker-machine config default)"

alias -g L="|less"
alias -g TL='| tail -20'
alias -g NUL="> /dev/null 2>&1"

hgrep() { history | grep "$1"; }
alias c='clear'
#alias ll='ls -la'
alias ls='eza --icons '
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
# Rails aliases removed - Ruby/Rails tooling not installed
alias vi='nvim'
alias wget='wget -c'
alias x='exit'
alias biggest='dust -r -n 40'  # Top 40 largest dirs/files
alias urldecode='python3 -c "import sys; from urllib.parse import unquote_plus; print(unquote_plus(sys.argv[1]))"'
alias urlencode='python3 -c "import sys; from urllib.parse import quote_plus; print(quote_plus(sys.argv[1]))"'

# aliases that use xtitle
alias top='xtitle Processes on $HOST && top'
alias make='xtitle Making $(basename $PWD) ; make'



# PostgreSQL aliases - use Homebrew service commands instead
alias start_postgres='brew services start postgresql@16'
alias stop_postgres='brew services stop postgresql@16'

alias start_memcached='/usr/local/opt/memcached/bin/memcached'
alias stop_memcached='killall memcached'

alias brewski='brew update && brew upgrade && brew cleanup; brew doctor'

# Other tools
alias fzfp='fzf --preview "bat --color=always --style=header,grid --line-range :500 {}"'

#######################
# Git Aliases to make it all shorter
########################
unalias gs 2>/dev/null  # Ensure ghostscript doesn't override
alias gs='git status -sb'
alias gd='git diff'
alias gb='git branch -vv'
alias gf='git fetch --all --prune'
alias gch='git checkout'
alias gadd='git add'
alias gaa='git add -A'
alias gco='git commit -m'
alias gca='git commit -am'
alias grom='git rebase origin/main'
alias grod='git rebase origin/develop'
alias gri='git rebase -i'
alias grc='git rebase --continue'
alias glog='git log'
alias ghist='git hist'
alias gpush='git push'
alias gpushod='git push origin develop'
alias gpushom='git push origin master'
alias gdiff='git diff --color'
alias gmerge='git merge'
alias gff='git merge --ff-only'
alias gpull='git pull --prune'
alias grm="git status | grep deleted | awk '{print \$3}' | xargs git rm"
alias gamend="git commit --amend -C HEAD"
alias gclean="git checkout . && git clean -f"

__git_files () {
    _wanted files expl 'local files' _files
}

#############################
# Random git commands for my usual branch protocol of 1234storynum_title_of_feature
#############################
# Cross-platform clipboard copy
_clipboard_copy() {
    if [[ "$(uname)" == "Darwin" ]]; then
        pbcopy
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
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
    fi
}
function cpmsg() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "[#`git rev-parse --abbrev-ref HEAD | cut -d'_' -f 1`] CM: " | tr -d '\n' | _clipboard_copy
    else
        echo "not in a repo" >&2
    fi
}

##############################
# Execute on launch
##############################
# Source API keys if file exists (gitignored, see api_keys.sh.template)
[ -f ~/dotfiles/api_keys.sh ] && source ~/dotfiles/api_keys.sh

# Source 1Password-backed API keys (can override above, see api_keys_1password.sh.template)
[ -f ~/dotfiles/api_keys_1password.sh ] && source ~/dotfiles/api_keys_1password.sh

# SSH keys are managed by macOS Keychain automatically
# No need to call ssh-add on every shell startup


##############################
# Generic Tools
##############################
function lt() { eza -la --sort=modified "$@" | tail; }
function psgrep() { ps axuf | grep -v grep | grep "$@" -i --color=auto; }
function fname() { fd --ignore-case "$@"; }  # Uses fd for fast searching

function strip_quotes() { sed 's/\"//g' $@; }

# These commands are now in bin/ with better error handling:
#   server, killbyname, dtgz


function removeFromPath() {
    export PATH=$(echo $PATH | sed -E -e "s;:$1;;" -e "s;$1:?;;")
}

function setjdk() {
  if [ $# -ne 0 ]; then
   removeFromPath '/System/Library/Frameworks/JavaVM.framework/Home/bin'
   if [ -n "${JAVA_HOME+x}" ]; then
    removeFromPath $JAVA_HOME
   fi
   export JAVA_HOME=`/usr/libexec/java_home -v $@`
   export PATH=$JAVA_HOME/bin:$PATH
  fi
}

##############################
# fun
##############################
function xtitle()      # Adds some text in the terminal frame.
{
    case "$TERM" in
        *term | rxvt)
            echo -n -e "\033]0;$*\007" ;;
        *)
            ;;
    esac
}

##############################
# Stupid shortcuts
##############################
function svim {
    sudo vim $@
}

# Find a file with a pattern in name:
function ff() { find . -type f -iname '*'$*'*' -ls ; }

function my_ps() { ps $@ -u $USER -o pid,%cpu,%mem,bsdtime,command ; }
function pp() { my_ps f | awk '!/awk/ && $0~var' var=${1:-".*"} ; }

# Kill by process name.
function killps()
{
    local pid pname sig="-TERM"   # Default signal.
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "Usage: killps [-SIGNAL] pattern"
        return;
    fi
    if [ $# = 2 ]; then sig=$1 ; fi
    for pid in $(my_ps| awk '!/awk/ && $0~pat { print $1 }' pat=${!#} ) ; do
        pname=$(my_ps | awk '$1~var { print $5 }' var=$pid )
        read -p "Kill process $pid <$pname> with signal $sig?" RESP
        if [ "$RESP" = "y" ]; then
            kill $sig $pid
        fi
    done
}


# Get current host related info (macOS compatible).
function sysinfo()
{
    local RED='\033[0;31m'
    local NC='\033[0m'
    echo -e "\nYou are logged on ${RED}$HOST${NC}"
    echo -e "\n${RED}Additional information:${NC}" ; uname -a
    echo -e "\n${RED}Users logged on:${NC}" ; w -h
    echo -e "\n${RED}Current date:${NC}" ; date
    echo -e "\n${RED}Machine stats:${NC}" ; uptime
    echo -e "\n${RED}Memory stats:${NC}"
    if [[ "$(uname)" == "Darwin" ]]; then
        vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf "%-16s %8.2f MB\n", "$1:", $2 * $size / 1048576'
    else
        free -h
    fi
    echo -e "\n${RED}Local IP Address:${NC}"
    if [[ "$(uname)" == "Darwin" ]]; then
        ipconfig getifaddr en0 2>/dev/null || echo "Not connected"
    else
        ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1 | head -1 || echo "Not connected"
    fi
    echo -e "\n${RED}Public IP Address:${NC}" ; curl -s ifconfig.me 2>/dev/null || echo "Not connected"
    echo
}

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

if command -v fzf &> /dev/null; then
  eval "$(fzf --zsh)"

  # Fuzzy cd into directory
  fcd() { cd "$(find . -type d 2>/dev/null | fzf --preview 'ls -la {}')" }

  # Fuzzy kill process
  fkill() {
    local pid
    pid=$(ps aux | sed 1d | fzf --multi --preview 'echo {}' | awk '{print $2}')
    [ -n "$pid" ] && echo "$pid" | xargs kill -${1:-9}
  }

  # Fuzzy git checkout branch (local + remote)
  fbr() {
    local branch
    branch=$(git branch -a --color=always | grep -v HEAD | fzf --ansi --preview 'git log --oneline --graph --color=always {1}' | sed 's/^[* ]*//' | sed 's/remotes\/origin\///')
    [ -n "$branch" ] && git checkout "$branch"
  }

  # Fuzzy git log browser
  flog() {
    git log --oneline --color=always | fzf --ansi --preview 'git show --color=always {1}' | awk '{print $1}' | xargs -I {} git show {}
  }

  # Fuzzy search file contents and open in editor
  fsearch() {
    local file line
    read -r file line <<< $(rg --line-number --no-heading . 2>/dev/null | fzf --delimiter ':' --preview 'bat --color=always --highlight-line {2} {1}' | awk -F: '{print $1, $2}')
    [ -n "$file" ] && $EDITOR "$file" +$line
  }
fi
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
  # Use zoxide for cd with fallback to builtin cd if zoxide fails
  cd() { z "$@" 2>/dev/null || builtin cd "$@"; }
fi
# System info on login shells only (not every new terminal tab)
# Run 'fastfetch' manually to see system info
if [[ -o login ]] && command -v fastfetch &> /dev/null; then
  fastfetch
fi

# Lazy-load thefuck (saves ~100ms on shell startup)
if command -v thefuck &> /dev/null; then
  fuck() {
    unset -f fuck
    eval $(thefuck --alias)
    fuck "$@"
  }
fi

# if command -v magic &> /dev/null; then
  # eval "$(magic completion --shell zsh)"
# fi
# Cached compinit - only regenerate once per day
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi


# Lazy-load pyenv (saves ~100ms on shell startup)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
pyenv() {
  unset -f pyenv
  eval "$(command pyenv init -)"
  pyenv "$@"
}

# Lazy-load nvm (saves ~200ms on shell startup)
export NVM_DIR="$HOME/.nvm"
if [ -d "$NVM_DIR" ]; then
  nvm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    nvm "$@"
  }
  node() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    node "$@"
  }
  npm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    npm "$@"
  }
  npx() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    npx "$@"
  }
fi

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
# Docker CLI completions (compinit called once above)
fpath=($HOME/.docker/completions $fpath)

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

##############################
# Terminal Screensaver
##############################
# cmatrix after 15 min of idle (900 seconds)
if command -v cmatrix &> /dev/null; then
  TMOUT=900
  TRAPALRM() {
    # Only run if terminal is idle (no background jobs, no text in prompt)
    if [[ -z "$(jobs)" ]] && [[ -z "$BUFFER" ]]; then
      cmatrix -s  # -s exits on any keypress
      zle reset-prompt 2>/dev/null
    fi
  }
fi
