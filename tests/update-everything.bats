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

@test "brew upgrade report counts updated packages" {
    write_disabled_config
    cat >"$FAKE_BIN/brew" <<'BREW'
#!/usr/bin/env bash
if [ "$1" = outdated ] && [ "${2:-}" = --formula ] && [ "${3:-}" = --verbose ]; then
    printf '%s\n' 'wget (1.0) < 2.0'
fi
exit 0
BREW
    chmod +x "$FAKE_BIN/brew"
    printf '%s\n' 'RUN_BREW_UPGRADE=true' >>"$CONFIG_DIR/config"

    run env HOME="$TMP_HOME" PATH="$FAKE_BIN:/usr/bin:/bin" "$DOTFILES_DIR/bin/update-everything"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Packages updated: 1"* ]]
    [[ "$output" == *"wget 2.0"* ]]
}

@test "REPOS_DIR replaces the default repository directories" {
    write_disabled_config
    local only="$TMP_HOME/only-repos"
    mkdir -p "$only"
    printf '%s\n' "REPOS_DIR=\"$only\"" 'PULL_REPOS=true' >>"$CONFIG_DIR/config"

    run env HOME="$TMP_HOME" "$DOTFILES_DIR/bin/update-everything" --dry-run

    [ "$status" -eq 0 ]
    [[ "$output" == *"REPOS_DIRS=$only"* ]]
    [[ "$output" != *"$TMP_HOME/code"* ]]
    [[ "$output" != *"$TMP_HOME/norm"* ]]
}

setup_git_repo() {
    local origin="$1"
    local work="$2"
    git init --bare "$origin"
    git -C "$origin" symbolic-ref HEAD refs/heads/main
    git init "$work"
    git -C "$work" checkout -B main
    git -C "$work" remote add origin "$origin"
    printf 'base\n' >"$work/tracked"
    git -C "$work" add tracked
    git -C "$work" -c user.email=test@example.com -c user.name=Test commit -m base
    git -C "$work" push -u origin main
}

@test "untracked files do not pop an older stash" {
    write_disabled_config
    local origin="$TMP_HOME/origin.git"
    local repos="$TMP_HOME/repos"
    local work="$repos/demo"
    mkdir -p "$repos"
    setup_git_repo "$origin" "$work"
    printf 'stashed\n' >>"$work/tracked"
    git -C "$work" stash push -m older
    printf 'keep-me\n' >"$work/extra.txt"
    printf '%s\n' "REPOS_DIRS=(\"$repos\")" 'PULL_REPOS=true' 'PARALLEL=false' >>"$CONFIG_DIR/config"

    run env HOME="$TMP_HOME" "$DOTFILES_DIR/bin/update-everything"

    [ "$status" -eq 0 ]
    [ "$(cat "$work/extra.txt")" = "keep-me" ]
    [ "$(cat "$work/tracked")" = "base" ]
    [ "$(git -C "$work" stash list | wc -l | tr -d ' ')" = "1" ]
    [[ "$(git -C "$work" stash list)" == *"older"* ]]
}

@test "tracked edits are restored without popping an older stash" {
    write_disabled_config
    local origin="$TMP_HOME/origin.git"
    local repos="$TMP_HOME/repos"
    local work="$repos/demo"
    local other="$TMP_HOME/other"
    mkdir -p "$repos"
    setup_git_repo "$origin" "$work"
    printf 'old\n' >>"$work/tracked"
    git -C "$work" stash push -m older
    printf 'local-edit\n' >>"$work/tracked"
    git clone "$origin" "$other"
    printf 'remote\n' >"$other/remote.txt"
    git -C "$other" add remote.txt
    git -C "$other" -c user.email=test@example.com -c user.name=Test commit -m remote
    git -C "$other" push origin main
    printf '%s\n' "REPOS_DIRS=(\"$repos\")" 'PULL_REPOS=true' 'PARALLEL=false' >>"$CONFIG_DIR/config"

    run env HOME="$TMP_HOME" "$DOTFILES_DIR/bin/update-everything"

    [ "$status" -eq 0 ]
    [[ "$(cat "$work/tracked")" == *"local-edit"* ]]
    [ "$(cat "$work/remote.txt")" = "remote" ]
    [ "$(git -C "$work" stash list | wc -l | tr -d ' ')" = "1" ]
    [[ "$(git -C "$work" stash list)" == *"older"* ]]
}
