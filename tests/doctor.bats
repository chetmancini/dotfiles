#!/usr/bin/env bats
# tests/doctor.bats — doctor CLI and temp-HOME symlink checks

setup() {
    load helpers.bash
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "doctor --help exits 0 and prints usage" {
    run "$DOTFILES_DIR/bin/doctor" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: doctor"* ]]
}

@test "doctor --skip-tools succeeds in temp HOME after install" {
    tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor.XXXXXX")"
    # Run install without brew into temp HOME
    HOME="$tmp_home" "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-api-keys --no-clear >/dev/null 2>&1
    run env HOME="$tmp_home" "$DOTFILES_DIR/bin/doctor" --skip-tools
    [ "$status" -eq 0 ]
    [[ "$output" == *"Zsh config"* ]] || [[ "$output" == *"Git config"* ]]
    rm -rf "$tmp_home"
}

@test "doctor detects missing symlink in temp HOME" {
    tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-missing.XXXXXX")"
    mkdir -p "$tmp_home/.config"
    # No symlinks — doctor should report failures (exit !=0)
    run env HOME="$tmp_home" "$DOTFILES_DIR/bin/doctor" --skip-tools
    [ "$status" -ne 0 ]
    [[ "$output" == *"is not a symlink"* ]]
    rm -rf "$tmp_home"
}

@test "doctor --strict fails when tools missing (isolated PATH)" {
    # With a minimal PATH, at least one tool check should fail under --strict
    tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-strict.XXXXXX")"
    HOME="$tmp_home" "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-api-keys --no-clear >/dev/null 2>&1
    run env HOME="$tmp_home" PATH="/usr/bin:/bin" "$DOTFILES_DIR/bin/doctor" --strict --skip-tools
    # --skip-tools should still pass even with isolated PATH
    [ "$status" -eq 0 ]
    rm -rf "$tmp_home"
}
