#!/usr/bin/env bats
# tests/update-everything.bats — updater control flow and exit status

setup() {
    load helpers.bash
    setup_temp_home
    FAKE_BIN="$TMP_HOME/bin"
    CONFIG_DIR="$TMP_HOME/.config/good-morning"
    mkdir -p "$FAKE_BIN" "$CONFIG_DIR"
}

teardown() {
    teardown_temp_home
}

write_disabled_config() {
    printf '%s\n' \
        'CHECK_MACOS_UPDATES=false' \
        'RUN_BREW_UPDATE=false' \
        'RUN_BREW_UPGRADE=false' \
        'RUN_BREW_CLEANUP=false' \
        'RUN_NPM_GLOBAL_UPDATE=false' \
        'RUN_PNPM_GLOBAL_UPDATE=false' \
        'DOCKER_PRUNE=false' \
        'UPDATE_NVIM_PLUGINS=false' \
        'PULL_REPOS=false' >"$CONFIG_DIR/config"
}

@test "disabled tasks are skipped without terminating the updater" {
    write_disabled_config

    run env HOME="$TMP_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" "$DOTFILES_DIR/bin/update-everything"

    [ "$status" -eq 0 ]
    [[ "$output" == *"All updates complete!"* ]]
}

@test "a failed task produces a non-zero final status after later skips" {
    write_disabled_config
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'if [[ "${1:-}" == "update" ]]; then exit 42; fi' \
        'exit 0' >"$FAKE_BIN/brew"
    chmod +x "$FAKE_BIN/brew"
    printf '%s\n' 'RUN_BREW_UPDATE=true' >>"$CONFIG_DIR/config"

    run env HOME="$TMP_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" "$DOTFILES_DIR/bin/update-everything"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to update Homebrew"* ]]
    [[ "$output" == *"Updates completed with errors"* ]]
}
