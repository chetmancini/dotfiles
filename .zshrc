#Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="robbyrussell"

# Example aliases
alias zshconfig="sublime ~/dotfiles/.zshrc"
alias ohmyzsh="sublime ~/.oh-my-zsh"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(battery brew history-substring-search node osx pip python rbenv redis-cli rvm sublime)

source $ZSH/oh-my-zsh.sh

##############################
# Variables
##############################
EDITOR="sublime"
DEFAULT_USER="chet.mancini"
##############################
# Paths
##############################
export PATH="$JAVA_HOME/bin:/usr/local/mysql/bin:/Users/chet.mancini/code/conf/vms/ruby/jruby/bin:/Users/chet.mancini/conf/vms/ruby/jruby/lib/ruby/gems/1.8/bin:$PATH"
export JAVA_HOME="/Library/Java/Home"
export INTENT_HOME="~/code"
export CODE_DIR="~/code"
export DEV_DIR="~/Development"
export NODE_PATH="$NODE_PATH:/usr/local/lib/node_modules"
##############################
# Aliases
##############################
alias h='history | grep $1'
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../../'
alias la='ls -a'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias be='bundle exec'
#alias ss='bundle exec trinidad'
#alias sc='bundle exec rails console'
alias cuke='bundle exec cucumber -c'
alias code='cd $CODE_DIR'
alias extranet='cd $CODE_DIR/extranet'
alias adserver='cd $CODE_DIR/adServer'
alias rs='bundle exec rspec'
alias vi='vim'
alias x='exit'

#######################
# Git Aliases to make it all shorter
########################
alias gs='git status'
alias gb='git branch'
alias gf='git fetch'
alias gch='git checkout'
alias gaa='git add -A'
alias gcom='git commit -m'
alias grom='git rebase origin/master'
alias gri='git rebase -i'
alias glog='git log'
alias ghist='git hist'
alias gpush='git push origin'
alias gdiff='git diff'
alias gpush='git push'
alias gpull='git pull'

#############################
# Random git commands for Intent Media protocol
#############################
function cpbranch() {
    git rev-parse --abbrev-ref HEAD | tr -d '\n' | pbcopy
}

function cpmsg() {
    echo [#`git rev-parse --abbrev-ref HEAD | cut -d'_' -f 1`] CM: | tr -d '\n' | pbcopy
}

##############################
# Execute on launch
##############################
. ~/Scripts/z.sh

##############################
# Ad Tools Specific to Intent Media
##############################
function jstest() {
    ant -Dargs="$1" -f $INTENT_HOME/tags/build/build.xml start-and-run-all
}

function spoof_ads() {
    sudo $INTENT_HOME/conf/scripts/spoof_ads/spoof_ads $@
}

function spoof_ads_alpha() {
    sudo $INTENT_HOME/conf/scripts/spoof_ads/spoof_ads_alpha $@
}

function respoof() {
    ant -f $INTENT_HOME/adServer/build/build.xml concatenate && spoof_ads on
}

##############################
# Generic Tools
##############################
function tlb-server() {
    . ~/tlb-server/tlb-server-0.3.2/server.sh
}

function server() {
    local port="${1:-8000}"
    open "http://localhost:${port}/"
    python -m SimpleHTTPServer "$port"
}


#-------------------------------------------------------------
# fun
#-------------------------------------------------------------
function xtitle()      # Adds some text in the terminal frame.
{
    case "$TERM" in
        *term | rxvt)
            echo -n -e "\033]0;$*\007" ;;
        *)  
            ;;
    esac
}

# aliases that use xtitle
alias top='xtitle Processes on $HOST && top'
alias make='xtitle Making $(basename $PWD) ; make'

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

function extract()      # Handy Extract Program.
{
     if [ -f $1 ] ; then
         case $1 in
             *.tar.bz2)   tar xvjf $1     ;;
             *.tar.gz)    tar xvzf $1     ;;
             *.bz2)       bunzip2 $1      ;;
             *.rar)       unrar x $1      ;;
             *.gz)        gunzip $1       ;;
             *.tar)       tar xvf $1      ;;
             *.tbz2)      tar xvjf $1     ;;
             *.tgz)       tar xvzf $1     ;;
             *.zip)       unzip $1        ;;
             *.Z)         uncompress $1   ;;
             *.7z)        7z x $1         ;;
             *)           echo "'$1' cannot be extracted via >extract<" ;;
         esac
     else
         echo "'$1' is not a valid file"
     fi
}


function my_ps() { ps $@ -u $USER -o pid,%cpu,%mem,bsdtime,command ; }
function pp() { my_ps f | awk '!/awk/ && $0~var' var=${1:-".*"} ; }


function killps()                 # Kill by process name.
{
    local pid pname sig="-TERM"   # Default signal.
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "Usage: killps [-SIGNAL] pattern"
        return;
    fi
    if [ $# = 2 ]; then sig=$1 ; fi
    for pid in $(my_ps| awk '!/awk/ && $0~pat { print $1 }' pat=${!#} ) ; do
        pname=$(my_ps | awk '$1~var { print $5 }' var=$pid )
        if ask "Kill process $pid <$pname> with signal $sig?"
            then kill $sig $pid
        fi
    done
}

function my_ip() # Get IP adresses.
{
    MY_IP=$(/sbin/ifconfig ppp0 | awk '/inet/ { print $2 } ' | \
sed -e s/addr://)
    MY_ISP=$(/sbin/ifconfig ppp0 | awk '/P-t-P/ { print $3 } ' | \
sed -e s/P-t-P://)
}

function sysinfo()   # Get current host related info.
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


GREEN='0;32m'
YELLOW='1;33m'
#PS1='[\u@\h \[\033[$GREEN\]\W\[\033[0m\]\[\033[$YELLOW\]$(__git_ps1 " (%s)")\[\033[0m\]]\$ '

#####################################
# Database Migrations Specif to Intent Media
#####################################

function dbMigrateAndPrepAll() {
  dbMigrateBase
  dbTestPrepareBase
  dbMigrateExtranet
  dbTestPrepareExtranet
}

function dbMigrateAndPrepXnet() {
  dbMigrateExtranet
  dbTestPrepareExtranet
}

function dbMigrateBase() {
  currentDir=`pwd`
  cd $INTENT_HOME/dataMigrations
  rake db:migrate
  cd $currentDir
}

function dbTestPrepareBase() {
  currentDir=`pwd`
  cd $INTENT_HOME/dataMigrations
  rake db:test:prepare
  cd $currentDir
}

function dbMigrateExtranet() {
  currentDir=`pwd`
  cd $INTENT_HOME/extranet/db
  rake db:migrate
  cd $currentDir
}

function dbTestPrepareExtranet() {
  currentDir=`pwd`
  cd $INTENT_HOME/extranet/db
  rake db:test:prepare
  cd $currentDir
}

##################
# Convert ERB to HAML
##################
function haml_move() {
  [[ $1 =~ (.+)\.erb ]]
  erb_name="${BASH_REMATCH[1]}"
  git mv "${erb_name}.erb" "${erb_name}.haml" &&  git add "${erb_name}.haml"
}

function haml_convert() {
  cat "$1" | bundle exec html2haml -s -e "$1" && git add "$1"
}
