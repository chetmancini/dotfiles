#!/usr/bin/env bats
# tests/zsh-path.bats — shell PATH integration checks

setup() {
    load helpers.bash
    setup_temp_home
    mkdir -p "$HOME/Library/pnpm/bin"
}

teardown() {
    teardown_temp_home
}

@test "Mise activation preserves the module-owned pnpm global bin" {
    run env \
        DOTFILES_DIR="$DOTFILES_DIR" \
        HOME="$HOME" \
        PATH="/usr/bin:/bin" \
        zsh -dfc '
        source "$DOTFILES_DIR/zsh/path.zsh"
        mise() {
            [[ "$1" == activate ]] &&
                print -r -- "export PATH=/usr/bin:/bin"
        }
        source "$DOTFILES_DIR/zsh/tools/mise.zsh"
        [[ ":$PATH:" == *":$PNPM_GLOBAL_BIN:"* ]]
    '
    [ "$status" -eq 0 ]
}
