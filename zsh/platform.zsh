##############################
# Source other files based on platform/organization
##############################
platform='unknown'
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
  source "$DOTFILES_DIR/linux_specific.sh"
elif [[ "$unamestr" == 'Darwin' ]]; then
  source "$DOTFILES_DIR/mac_specific.sh"
fi
