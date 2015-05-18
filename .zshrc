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
plugins=(battery brew bundler emacs history-substring-search node npm osx pip python rbenv redis-cli rvm sublime web-search)

source $ZSH/oh-my-zsh.sh
archey

##############################
# Variables
##############################
# ZSH Options
DEFAULT_USER="chet"
setopt AUTO_CD
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
export JAVA_OPTS="-Xmx2048m -Xms512m -XX:MaxPermSize=512m -d64"
export ANT_ARGS="-logger org.apache.tools.ant.listener.AnsiColorLogger"
export ANT_OPTS="-Xmx2048m -Xms512m"

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
source ~/dotfiles/intent_specific.sh

##############################
# Paths
##############################
export JAVA_HOME="`/usr/libexec/java_home -v '1.7*'`"
export INTENT_HOME="$HOME/code"
export CODE_DIR="$HOME/code"
export DEV_DIR="$HOME/Development"
export NODE_PATH="$NODE_PATH:/usr/local/lib/node_modules:/usr/local/share/npm/bin"
export NPM_PATH=/usr/local/share/npm/bin
export GEMS_HOME=$INTENT_HOME/conf/vms/ruby/jruby/lib/ruby/gems/1.8/bin
export JRUBY_HOME=$INTENT_HOME/conf/vms/ruby/jruby/bin
export MYSQL_HOME=/usr/local/mysql/bin
export USR_LOCAL_HOME=/usr/local/bin
export USR_LOCAL_SBIN=/usr/local/sbin
export VERTICA_HOME=/usr/local/vertica/bin
export RBENV_HOME=/usr/local/opt/rbenv/shims:/usr/local/opt/rbenv/bin
export ANACONDA_HOME=$HOME/anaconda/bin
export EMR_HOME=$HOME/elastic-mapreduce-cli
export PATH=$HOME/bin:$JAVA_HOME/bin:$MYSQL_HOME:$VERTICA_HOME:$USR_LOCAL_HOME:$USR_LOCAL_SBIN:$RBENV_HOME:$JRUBY_HOME:$GEMS_HOME:$ANACONDA_HOME:$NPM_PATH:$EMR_HOME:$PATH
export CLASSPATH=$HOME/lib/jars

##############################
# Launch Background Apps
##############################
eval "$(rbenv init -)"

##############################
# Aliases
##############################
alias -g L="|less"
alias -g TL='| tail -20'
alias -g NUL="> /dev/null 2>&1"

alias h='history | grep $1'
alias c='clear'
alias ll='ls -la'
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
alias gri='git rebase -i'
alias grc='git rebase --continue'
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
# Random git commands for my usual branch protocol of 1234storynum_title_of_feature
#############################
function cpbranch() {
    git rev-parse --abbrev-ref HEAD | tr -d '\n' | pbcopy
}
function cpmsg() {
    echo "[#`git rev-parse --abbrev-ref HEAD | cut -d'_' -f 1`] CM: " | tr -d '\n' | pbcopy
}
function pushRemoteRun() {
    branch=$(git rev-parse --abbrev-ref HEAD | tr -d '\n')
    git push -uf origin $branch:remote-run/chet/$branch
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
function lt() { ls -ltrsa "$@" | tail; }
function psgrep() { ps axuf | grep -v grep | grep "$@" -i --color=auto; }
function fname() { find . -iname "*$@*"; }

function tlb-server() {
    . ~/tlb-server/tlb-server-0.3.2/server.sh
}

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

# Handy Extract Program.
function extract()
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
        if ask "Kill process $pid <$pname> with signal $sig?"
            then kill $sig $pid
        fi
    done
}

# Get IP adresses.
function my_ip()
{
    MY_IP=$(/sbin/ifconfig ppp0 | awk '/inet/ { print $2 } ' | \
sed -e s/addr://)
    MY_ISP=$(/sbin/ifconfig ppp0 | awk '/P-t-P/ { print $3 } ' | \
sed -e s/P-t-P://)
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
