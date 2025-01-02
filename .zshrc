
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
    node
    npm
    macos
    pip
    python
    redis-cli
    thefuck
    tldr
    web-search
)

source $ZSH/oh-my-zsh.sh
# AWS completion
#source /usr/local/share/zsh/site-functions/_aws
#source /usr/local/share/zsh/site-functions/_awless

#export PYENV_ROOT="$HOME/.pyenv"
#command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
#eval "$(pyenv init -)"

##############################
# Variables
##########################oh-m####
# ZSH Options
DEFAULT_USER="chet"
setopt AUTO_CD
HISTFILESIZE=1000000
HISTSIZE=1000000
export HISTCONTROL=ignoreboth:erasedups
# If I type cd and then cd again, only save the last one
setopt HIST_IGNORE_DUPS
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

# Java/Ant Options
#export JAVA_OPTS="-Xmx2048m -Xms512m -XX:MaxPermSize=512m -d64"
#export ANT_ARGS="-logger org.apache.tools.ant.listener.AnsiColorLogger"
#export ANT_OPTS="-Xmx2048m -Xms512m"

##############################
# Editor Settings
##############################
setopt VI
export EDITOR="vim"
bindkey -v

# vi style incremental search
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward
bindkey '^P' history-search-backward
bindkey '^N' history-search-forward

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
source ~/dotfiles/carta_specific.sh

##############################
# Paths
##############################
export BREW_PATH=/opt/homebrew/bin
export JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
export CODE_DIR="$HOME/code"
export DEV_DIR="$HOME/Development"
export NODE_PATH="$NODE_PATH:/usr/local/lib/node_modules:/usr/local/share/npm/bin"
export NPM_PATH=/usr/local/share/npm/bin
export UV_PATH="$HOME/.local/bin"
#export N_PATH="$HOME/n/bin"
#export PYENV_PATH="$HOME/.pyenv/shims"
export BUN_INSTALL="$HOME/.bun"
export MYSQL_HOME=/usr/local/mysql/bin
export USR_LOCAL_HOME=/usr/local/bin
export USR_LOCAL_SBIN=/usr/local/sbin
#export RBENV_HOME=/usr/local/opt/rbenv/shims:/usr/local/opt/rbenv/bin
export NVM_DIR="$HOME/.nvm"
#export ANACONDA_HOME=$HOME/anaconda/bin
export PERSONAL_BIN=$HOME/dotfiles/bin
export MODULAR_HOME="$HOME/.modular"
#export PATH=/usr/local/anaconda3/bin:/opt/homebrew/anaconda3/bin:$PATH
export PATH=$HOME/bin:$JAVA_HOME/bin:$BUN_INSTALL/bin:$MYSQL_HOME:$UV_PATH:$USR_LOCAL_HOME:$USR_LOCAL_SBIN:$NPM_PATH:$PERSONAL_BIN:$BREW_PATH:$MODULAR_HOME/bin:$PATH

export CLASSPATH=$HOME/lib/jars

export RBENV_ROOT=~/.rbenv



##############################
# Launch Background Apps
##############################
#eval "$(rbenv init -)"
#  . "/usr/local/opt/nvm/nvm.sh"

##############################
# Aliases
##############################
#alias docker="docker $(docker-machine config default)"

alias -g L="|less"
alias -g TL='| tail -20'
alias -g NUL="> /dev/null 2>&1"

alias h='history | grep $1'
alias c='clear'
#alias ll='ls -la'
alias ll='eza --all --long --header --icons --git'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../../'
alias grep='grep --color=auto'
alias be='bundle exec'
alias berake='bundle exec rake'
alias trinidad='bundle exec trinidad'
alias rconsole='bundle exec rails console'
alias rdebug-ide='bundle exec rdebug-ide'
alias cuke='bundle exec cucumber -c'
alias rs='bundle exec rspec --color --format documentation'
alias vi='vim'
alias wget='wget -c'
alias x='exit'
alias biggest='find -type f -printf '\''%s %p\n'\'' | sort -nr | head -n 40 | gawk "{ print \$1/1000000 \" \" \$2 \" \" \$3 \" \" \$4 \" \" \$5 \" \" \$6 \" \" \$7 \" \" \$8 \" \" \$9 }"'
alias urldecode='python -c "import sys, urllib as ul; print ul.unquote_plus(sys.argv[1])"'

# aliases that use xtitle
alias top='xtitle Processes on $HOST && top'
alias make='xtitle Making $(basename $PWD) ; make'

# Amazon Elastic Map Reduce (EMR) ssh tunnel, use like # ssh-emr
# hadoop@ec2-blah.blah.blah.amazonaws.com
# # This creates
alias ssh-emr='ssh -L 9100:localhost:9100 -L 9101:localhost:9101 -L 9102:localhost:9102 -L 9200:localhost:80 -L 9026:localhost:9026 -L 4040:localhost:4040 -i ~/.ssh/hadoop.pem'
alias ssh-emr-tools='ssh -L 25000:localhost:25000 -L 25010:localhost:25010 -L 25020:localhost:25020 -L 8888:localhost:8888 -i ~/.ssh/hadoop.pem'
alias ssh-emr-spark='ssh -L 18080:localhost:18080 -L 4040:localhost:4040 -L 9200:localhost:80 -L 8080:localhost:8080 -i ~/.ssh/hadoop.pem'

alias start_mysql='mysql.server start'
alias start_postgres='postgres -D /usr/local/var/postgres'
alias start_memcached='/usr/local/opt/memcached/bin/memcached'

alias brewski='brew update && brew upgrade && brew cleanup; brew doctor'

# Other tools

#######################
# Git Aliases to make it all shorter
########################
alias gs='git status -sb'
alias gd='git diff'
alias gb='git branch -vv'
alias gf='git fetch --all --prune'
alias gch='git checkout'
alias gadd 'git add'
alias gaa='git add -A'
alias gco='git commit -m'
alias gca='git commit -am'
alias grom='git rebase origin/master'
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
alias gpush='git push'
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
function cpbranch() {
    git rev-parse --abbrev-ref HEAD | tr -d '\n' | pbcopy
}
function cpmsg() {
    echo "[#`git rev-parse --abbrev-ref HEAD | cut -d'_' -f 1`] CM: " | tr -d '\n' | pbcopy
}

##############################
# Execute on launch
##############################
#. ~/dotfiles/z.sh


#export GPG_AGENT_INFO_FILE=$HOME/.gpg-agent-info
#gpg-agent --daemon --enable-ssh-support --write-env-file "${GPG_AGENT_INFO_FILE}"
#if [ -f "${GPG_AGENT_INFO_FILE}" ]; then
#  . "${GPG_AGENT_INFO_FILE}"
#  export GPG_AGENT_INFO
#  export SSH_AUTH_SOCK
#  export SSH_AGENT_PID
#fi
#export GPG_TTY=$(tty)

##############################
# SSH
##############################

##############################
# Generic Tools
##############################
function lt() { ls -ltrsa "$@" | tail; }
function psgrep() { ps axuf | grep -v grep | grep "$@" -i --color=auto; }
function fname() { find . -iname "*$@*"; }

function strip_quotes() { sed 's/\"//g' $@; }

# Launch a server in the current dir with an optional port defaulting to 8000
function server() {
    local port="${1:-8000}"
    open "http://localhost:${port}/"
    python -m SimpleHTTPServer "$port"
}

# Kill a process with a name.
function killByName() {
  ps aux | egrep -i "(tokill)" | grep -v egrep | awk '{ print $2 }' | xargs sudo kill -STOP
}


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
function dtgz {
    if [ $# -gt 0 ]; then
        for l in $@; do
            curl $l | tar -xz
        done
    else
        echo "Usage: dtgz url [url2, url3, ...]" 1>&2
    fi
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


# Get current host related info.
function sysinfo()
{
    echo -e "\nYou are logged on ${RED}$HOST"
    echo -e "\nAdditionnal information:$NC " ; uname -a
    echo -e "\n${RED}Users logged on:$NC " ; w -h
    echo -e "\n${RED}Current date :$NC " ; date
    echo -e "\n${RED}Machine stats :$NC " ; uptime
    echo -e "\n${RED}Memory stats :$NC " ; free
    my_ip 2>&- ;
    echo -e "\n${RED}Local IP Address :$NC" ; echo ${MY_IP:-"Not connected"}
    echo -e "\n${RED}ISP Address :$NC" ; echo ${MY_ISP:-"Not connected"}
    echo -e "\n${RED}Open connections :$NC "; netstat -pan --inet;
    echo
}

eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"
#stats on startup
fastfetch

eval $(thefuck --alias)

eval "$(magic completion --shell zsh)"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
#export SDKMAN_DIR="$HOME/.sdkman"
#[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"


# bun completions
[ -s "/Users/chet/.bun/_bun" ] && source "/Users/chet/.bun/_bun"
