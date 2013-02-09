#Path to your oh-my-zsh configuration.
ZSH=$HOME/dotfiles/.oh-my-zsh

######################
# oh-my-zsh
######################
ZSH_THEME="chetmancini"

alias zshconfig="sublime ~/dotfiles/.zshrc"
alias ohmyzsh="sublime ~/dotfiles/.oh-my-zsh"

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
plugins=(battery brew history-substring-search node osx pip python rbenv redis-cli rvm sublime)

source $ZSH/oh-my-zsh.sh

##############################
# Variables
##############################
DEFAULT_USER="chet.mancini"
setopt AUTO_CD
export JAVA_OPTS="-Xmx2048m -Xms512m -XX:MaxPermSize=512m -d64"
#CODE=/Users/$DEFAULT_USER/code
#EXTRANET=/Users/$DEFAULT_USER/code/extranet

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

##############################
# Vim
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
# Conditional
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
export JAVA_HOME="/Library/Java/Home"
export INTENT_HOME="$HOME/code"
export CODE_DIR="$HOME/code"
export DEV_DIR="$HOME/Development"
export NODE_PATH="$NODE_PATH:/usr/local/lib/node_modules"
export NPM_PATH=/usr/local/share/npm/bin
export GEMS_HOME=$INTENT_HOME/conf/vms/ruby/jruby/lib/ruby/gems/1.8/bin
export JRUBY_HOME=$INTENT_HOME/conf/vms/ruby/jruby/bin
export MYSQL_HOME=/usr/local/mysql/bin
export USR_LOCAL_HOME=/usr/local/bin
export VERTICA_HOME=/usr/local/vertica/bin
export RBENV_HOME=/usr/local/opt/rbenv/shims:/usr/local/opt/rbenv/bin
export ANACONDA_HOME=/Users/chet.mancini/anaconda/bin
export PATH=$HOME/local/bin:$JAVA_HOME/bin:$MYSQL_HOME:$VERTICA_HOME:$USR_LOCAL_HOME:$RBENV_HOME:$JRUBY_HOME:$GEMS_HOME:$ANACONDA_HOME:$NPM_PATH:$PATH

eval "$(rbenv init -)"

##############################
# Aliases
##############################
alias -g L="|less"
alias -g TL='| tail -20'
alias -g NUL="> /dev/null 2>&1"

alias h='history | grep $1'
alias c='clear'
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
alias rs='bundle exec rspec'
alias vi='vim'
alias x='exit'
alias biggest='find -type f -printf '\''%s %p\n'\'' | sort -nr | head -n 40 | gawk "{ print \$1/1000000 \" \" \$2 \" \" \$3 \" \" \$4 \" \" \$5 \" \" \$6 \" \" \$7 \" \" \$8 \" \" \$9 }"'

# aliases that use xtitle
alias top='xtitle Processes on $HOST && top'
alias make='xtitle Making $(basename $PWD) ; make'

# Intent aliases
alias code='cd ~/code'
alias extranet='cd ~/code/extranet'

#######################
# Git Aliases to make it all shorter
########################
alias gs='git status -sb'
alias gd='git diff'
alias gb='git branch'
alias gf='git fetch --all --prune'
alias gch='git checkout'
alias gaa='git add -A'
alias gco='git commit -m'
alias gca='git commit -am'
alias grom='git rebase origin/master'
alias gri='git rebase -i'
alias glog='git log'
alias ghist='git hist'
alias gpush='git push origin'
alias gdiff='git diff'
alias gmerge='git merge'
alias gff='git merge --ff-only'
alias gpush='git push'
alias gpull='git pull --prune'
alias grm="git status | grep deleted | awk '{print \$3}' | xargs git rm"
alias gamend="git commit --amend"

__git_files () { 
    _wanted files expl 'local files' _files 
}

#############################
# Random git commands for Intent Media protocol of 1234storynum_title_of_feature
#############################
function cpbranch() {
    git rev-parse --abbrev-ref HEAD | tr -d '\n' | pbcopy
}
function cpmsg() {
    echo "[#`git rev-parse --abbrev-ref HEAD | cut -d'_' -f 1`] CM: " | tr -d '\n' | pbcopy
}
function pushRemoteRun() {
    branch=$(git rev-parse --abbrev-ref HEAD | tr -d '\n')
    git push -uf origin $branch:remote-run/chet.mancini/$branch
}

##############################
# Execute on launch
##############################
. ~/dotfiles/z.sh

##############################
# SSH
##############################

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

function killByName() {
  ps aux | egrep -i "(tokill)" | grep -v egrep | awk '{ print $2 }' | xargs sudo kill -STOP
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

function most_useless_use_of_zsh {
   local lines columns colour a b p q i pnew
   ((columns=COLUMNS-1, lines=LINES-1, colour=0))
   for ((b=-1.5; b<=1.5; b+=3.0/lines)) do
       for ((a=-2.0; a<=1; a+=3.0/columns)) do
           for ((p=0.0, q=0.0, i=0; p*p+q*q < 4 && i < 32; i++)) do
               ((pnew=p*p-q*q+a, q=2*p*q+b, p=pnew))
           done
           ((colour=(i/4)%8))
            echo -n "\\e[4${colour}m "
        done
        echo
    done
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
