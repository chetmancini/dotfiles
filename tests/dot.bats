#!/usr/bin/env bats
# tests/dot.bats — bin/dot dispatcher

setup() {
    load helpers.bash
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "dot help lists primary commands" {
    run "$DOTFILES_DIR/bin/dot" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"doctor"* ]]
    [[ "$output" == *"brew-sync"* ]]
    [[ "$output" == *"install"* ]]
}

@test "dot rejects path traversal" {
    run "$DOTFILES_DIR/bin/dot" "../install.sh"
    [ "$status" -ne 0 ]
}

@test "dot install --help proxies to install.sh" {
    run "$DOTFILES_DIR/bin/dot" install --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"install.sh"* ]] || [[ "$output" == *"Usage:"* ]]
}

@test "dot doctor --help works" {
    run "$DOTFILES_DIR/bin/dot" doctor --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: doctor"* ]]
}
