# shellcheck shell=bash
# Leave runtime paths to the environment and installed version managers.
export CODE_DIR="${CODE_DIR:-$HOME/code}"
export DEV_DIR="${DEV_DIR:-$HOME/Development}"

if [ -f "$HOME/.bashrc" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc"
fi
