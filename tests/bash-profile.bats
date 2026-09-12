#!/usr/bin/env bats

setup() {
    load helpers.bash
    setup_temp_home
}

teardown() {
    teardown_temp_home
}

@test "Bash profile works without runtime variables and loads bashrc" {
    printf 'export BASHRC_LOADED=yes\n' >"$HOME/.bashrc"
    run bash --noprofile --norc -uc '
        unset JAVA_HOME NODE_PATH INTENT_HOME CODE_DIR DEV_DIR BASHRC_LOADED
        original_path="$PATH"
        source "$1"
        [[ "$PATH" == "$original_path" ]] || exit 1
        [[ -z "${JAVA_HOME+x}${NODE_PATH+x}${INTENT_HOME+x}" ]] || exit 1
        [[ "$CODE_DIR" == "$HOME/code" ]] || exit 1
        [[ "$DEV_DIR" == "$HOME/Development" ]] || exit 1
        [[ "$BASHRC_LOADED" == yes ]]
    ' -- "$DOTFILES_DIR/.bash_profile"
    [ "$status" -eq 0 ]
}

@test "Bash profile preserves configured paths across repeated sourcing without bashrc" {
    run bash --noprofile --norc -uc '
        export JAVA_HOME="$HOME/custom-java" NODE_PATH="$HOME/custom-node"
        export CODE_DIR="$HOME/projects" DEV_DIR="$HOME/dev"
        original_path="$PATH"
        source "$1"
        source "$1"
        [[ "$PATH" == "$original_path" ]] || exit 1
        [[ "$JAVA_HOME" == "$HOME/custom-java" ]] || exit 1
        [[ "$NODE_PATH" == "$HOME/custom-node" ]] || exit 1
        [[ "$CODE_DIR" == "$HOME/projects" ]] || exit 1
        [[ "$DEV_DIR" == "$HOME/dev" ]]
    ' -- "$DOTFILES_DIR/.bash_profile"
    [ "$status" -eq 0 ]
}
