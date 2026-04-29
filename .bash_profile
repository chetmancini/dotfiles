# shellcheck shell=bash
##############################
# Paths
##############################
export PATH="$JAVA_HOME/bin:/usr/local/mysql/bin:$HOME/code/conf/vms/ruby/jruby/bin:$HOME/conf/vms/ruby/jruby/lib/ruby/gems/1.8/bin:$PATH"
export JAVA_HOME="/Library/Java/Home"
export INTENT_HOME="$HOME/code"
export CODE_DIR="$HOME/code"
export DEV_DIR="$HOME/Development"
export NODE_PATH="$NODE_PATH:/usr/local/lib/node_modules"

# RVM
PATH=$PATH:$HOME/.rvm/bin

if [ -f ~/.bashrc ]; then
    # shellcheck source=/dev/null
    source ~/.bashrc
fi
