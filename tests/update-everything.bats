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
        'RUN_MISE_UPGRADE=false' \
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

@test "mise upgrades global requests even when invoked from a project" {
    write_disabled_config
    cat >"$FAKE_BIN/mise" <<'MISE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$MISE_CALL_LOG"
MISE
    chmod +x "$FAKE_BIN/mise"
    printf '%s\n' 'RUN_MISE_UPGRADE=true' >>"$CONFIG_DIR/config"
    mkdir -p "$TMP_HOME/project"
    printf '[tools]\nnode = "22"\n' >"$TMP_HOME/project/mise.toml"
    cd "$TMP_HOME/project"

    run env HOME="$TMP_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" \
        MISE_CALL_LOG="$TMP_HOME/mise.log" "$DOTFILES_DIR/bin/update-everything"

    [ "$status" -eq 0 ]
    [ "$(cat "$TMP_HOME/mise.log")" = "$(printf 'outdated --global\nupgrade --global')" ]
    [ "$(cat mise.toml)" = "$(printf '[tools]\nnode = "22"')" ]
}

@test "a failed mise upgrade reaches the final error report" {
    write_disabled_config
    cat >"$FAKE_BIN/mise" <<'MISE'
#!/usr/bin/env bash
if [ "$1" = upgrade ]; then exit 42; fi
MISE
    chmod +x "$FAKE_BIN/mise"
    printf '%s\n' 'RUN_MISE_UPGRADE=true' >>"$CONFIG_DIR/config"

    run env HOME="$TMP_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" "$DOTFILES_DIR/bin/update-everything"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Failed to update global mise tools"* ]]
    [[ "$output" == *"Updates completed with errors"* ]]
}
