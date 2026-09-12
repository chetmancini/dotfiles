#!/usr/bin/env bats
# tests/zsh-path.bats — shell PATH integration checks

setup() {
    load helpers.bash
    setup_temp_home
    # Do not inherit the developer's pnpm or XDG location into the fixture.
    unset PNPM_HOME XDG_DATA_HOME
}

teardown() {
    teardown_temp_home
}

assert_mise_preserves_pnpm_path() {
    local platform="$1" expected_home="$2"
    mkdir -p "$expected_home/bin"
    run env \
        DOTFILES_DIR="$DOTFILES_DIR" \
        HOME="$HOME" \
        PATH="/usr/bin:/bin" \
        zsh -dfc '
        OSTYPE="$1"
        source "$DOTFILES_DIR/zsh/path.zsh"
        [[ "$PNPM_GLOBAL_BIN" == "$2/bin" ]] || exit 1
        mise() {
            [[ "$1" == activate ]] &&
                print -r -- "export PATH=/usr/bin:/bin"
        }
        source "$DOTFILES_DIR/zsh/tools/mise.zsh"
        [[ ":$PATH:" == *":$PNPM_HOME:"* ]] || exit 1
        [[ ":$PATH:" == *":$PNPM_GLOBAL_BIN:"* ]] || exit 1
        # The prompt/directory hook must recover both paths after later resets.
        export PATH=/usr/bin:/bin
        _dotfiles_restore_pnpm_path
        _dotfiles_restore_pnpm_path
        [[ ":$PATH:" == *":$PNPM_HOME:"* ]] || exit 1
        [[ ":$PATH:" == *":$PNPM_GLOBAL_BIN:"* ]]
    ' -- "$platform" "$expected_home"
    [ "$status" -eq 0 ]
}

@test "Mise activation preserves the macOS pnpm global bin" {
    assert_mise_preserves_pnpm_path darwin "$HOME/Library/pnpm"
}

@test "Mise activation preserves the Linux pnpm global bin" {
    assert_mise_preserves_pnpm_path linux-gnu "$HOME/.local/share/pnpm"
}
