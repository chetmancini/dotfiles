
PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting

. ~/Scripts/z.sh
function precmd () {
  _z --add "$(pwd -P)"
}
