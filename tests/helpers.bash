#!/usr/bin/env bash
# helpers.bash — common setup for bats tests
# Usage: load helpers.bash in each .bats file

# Repo root (parent of tests/)
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$TESTS_DIR/.." && pwd)"

# Bats helper: fail with message
fail() {
    echo "$*" >&2
    return 1
}

# Temp HOME helper — sets HOME to a fresh mktemp dir and cleans up.
# Call in setup(): setup_temp_home
# Call in teardown(): teardown_temp_home
setup_temp_home() {
    TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bats-home.XXXXXX")"
    export HOME="$TMP_HOME"
    export ORIGINAL_HOME="$HOME"
}

teardown_temp_home() {
    if [[ -n "${TMP_HOME:-}" && -d "$TMP_HOME" ]]; then
        rm -rf "$TMP_HOME"
    fi
    unset TMP_HOME
}

# Run a bin script with DOTFILES_DIR and without touching real HOME.
# Usage: run_bin doctor --help
run_bin() {
    local bin="$1"
    shift
    run "$DOTFILES_DIR/bin/$bin" "$@"
}
