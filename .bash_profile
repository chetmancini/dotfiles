##############################
# Paths
##############################
export PATH="$JAVA_HOME/bin:/usr/local/mysql/bin:/Users/chet.mancini/code/conf/vms/ruby/jruby/bin:/Users/chet.mancini/conf/vms/ruby/jruby/lib/ruby/gems/1.8/bin:$PATH"
export JAVA_HOME="/Library/Java/Home"
export INTENT_HOME="/Users/chet.mancini/code"
export CODE_DIR="/Users/chet.mancini/code"
export NODE_PATH="$NODE_PATH:/usr/local/lib/node_modules"

# RVM
PATH=$PATH:$HOME/.rvm/bin

if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
