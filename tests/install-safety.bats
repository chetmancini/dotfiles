#!/usr/bin/env bats
# tests/install-safety.bats — interactive input and managed-source safeguards

setup() {
    load helpers.bash
    TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-safety.XXXXXX")"
    TEST_HOME="$TEST_ROOT/home"
    mkdir -p "$TEST_HOME"
    export DOTFILES_DIR TEST_HOME
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "interactive confirmations do not consume manifest records" {
    run bash -c 'yes y | env HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" --with-legacy-vim --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear'

    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.config/yazi" ]
    [ -L "$TEST_HOME/.config/ghostty" ]
    [ -L "$TEST_HOME/.config/nvim" ]
    [ -L "$TEST_HOME/.zshrc" ]
    [ -L "$TEST_HOME/.vimrc" ]
}

@test "closed confirmation input refuses to begin" {
    run bash -c 'env HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear </dev/null'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installation cancelled"* ]]
    [ ! -e "$TEST_HOME/.zshrc" ]
}

@test "installer refuses a checkout with a missing managed source" {
    copy="$TEST_ROOT/repo"
    mkdir -p "$copy"
    cp -R "$DOTFILES_DIR/." "$copy/"
    rm -rf "$copy/yazi"

    run env HOME="$TEST_HOME" "$copy/install.sh" --plan --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear

    [ "$status" -ne 0 ]
    [[ "$output" == *"Managed source is missing"* ]]
    [ ! -e "$TEST_HOME/.zshrc" ]
}

@test "doctor rejects an installed link after its managed source disappears" {
    copy="$TEST_ROOT/repo"
    mkdir -p "$copy"
    cp -R "$DOTFILES_DIR/." "$copy/"
    env HOME="$TEST_HOME" "$copy/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear >/dev/null
    rm -rf "$copy/yazi"

    run env HOME="$TEST_HOME" "$copy/bin/doctor" --skip-tools

    [ "$status" -ne 0 ]
    [[ "$output" == *"managed source is missing"* ]]
}
