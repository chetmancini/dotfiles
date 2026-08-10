#!/usr/bin/env bats
# tests/package-sync.bats — global npm/pnpm package-store checks and updates

setup() {
    load helpers.bash
    FAKE_BIN="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-package-sync-bin.XXXXXX")"
    PNPM_GLOBAL_BIN="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-package-sync-pnpm.XXXXXX")"
    NPM_PREFIX="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-package-sync-npm.XXXXXX")"

    cat >"$FAKE_BIN/npm" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "prefix" ] && [ "$2" = "--global" ]; then
    echo "$TEST_NPM_PREFIX"
    exit 0
fi
if [ "$1" = "update" ] && [ "$2" = "--global" ]; then
    echo "npm update called"
    exit 0
fi
exit 1
EOF
    cat >"$FAKE_BIN/pnpm" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "bin" ] && [ "$2" = "--global" ]; then
    echo "$TEST_PNPM_GLOBAL_BIN"
    exit 0
fi
if [ "$1" = "update" ] && [ "$2" = "--global" ]; then
    echo "pnpm update called"
    exit 0
fi
exit 1
EOF
    chmod +x "$FAKE_BIN/npm" "$FAKE_BIN/pnpm"
}

teardown() {
    rm -rf "$FAKE_BIN" "$PNPM_GLOBAL_BIN" "$NPM_PREFIX"
}

@test "package-sync --help prints usage" {
    run "$DOTFILES_DIR/bin/package-sync" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: package-sync"* ]]
    [[ "$output" == *"--update"* ]]
}

@test "package-sync checks portable npm and pnpm global stores" {
    run env \
        TEST_NPM_PREFIX="$NPM_PREFIX" \
        TEST_PNPM_GLOBAL_BIN="$PNPM_GLOBAL_BIN" \
        PATH="$FAKE_BIN:$PNPM_GLOBAL_BIN:/usr/bin:/bin" \
        "$DOTFILES_DIR/bin/package-sync" --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"npm: global prefix $NPM_PREFIX"* ]]
    [[ "$output" == *"pnpm: global bin $PNPM_GLOBAL_BIN"* ]]
}

@test "package-sync updates both global package managers" {
    run env \
        TEST_NPM_PREFIX="$NPM_PREFIX" \
        TEST_PNPM_GLOBAL_BIN="$PNPM_GLOBAL_BIN" \
        PATH="$FAKE_BIN:$PNPM_GLOBAL_BIN:/usr/bin:/bin" \
        "$DOTFILES_DIR/bin/package-sync" --update
    [ "$status" -eq 0 ]
    [[ "$output" == *"npm update called"* ]]
    [[ "$output" == *"pnpm update called"* ]]
}
