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

@test "installer refuses a symlink whose target contains trailing newlines before mutation" {
    mkdir -p "$TEST_HOME/.config"
    python3 -c "import os; os.symlink('bad_target\n', '$TEST_HOME/.config/yazi')"

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsupported characters in symlink target"* ]]

    # Existing symlink remains untouched
    [ -L "$TEST_HOME/.config/yazi" ]
    raw="$(
        readlink -n "$TEST_HOME/.config/yazi"
        printf x
    )"
    [ "${raw%x}" = $'bad_target\n' ]

    # No completed transaction created
    [ ! -f "$TEST_HOME/.dotfiles-backup/latest" ]
}

@test "installer invoked through a symlinked repo directory creates links that restore cleanly" {
    local symlinked_repo="$TEST_ROOT/symlinked-repo"
    ln -s "$DOTFILES_DIR" "$symlinked_repo"

    run env HOME="$TEST_HOME" "$symlinked_repo/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.zshrc" ]

    # Plan restore using the symlinked repo path
    run env HOME="$TEST_HOME" "$symlinked_repo/bin/restore" --plan latest
    [ "$status" -eq 0 ]
    [[ "$output" != *"conflict"* ]]

    # Apply restore using the symlinked repo path
    run env HOME="$TEST_HOME" "$symlinked_repo/bin/restore" --apply latest --yes
    [ "$status" -eq 0 ]
    [ ! -L "$TEST_HOME/.zshrc" ]
}

@test "installer refuses to install when a target ancestor directory is a symlink" {
    local external_dir="$TEST_ROOT/external_config"
    mkdir -p "$external_dir"
    ln -s "$external_dir" "$TEST_HOME/.config"

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"Target ancestor for"* && "$output" == *"is a symlink"* ]]

    # No files created in the external directory or transaction recorded
    [ ! -e "$external_dir/yazi" ]
    [ ! -f "$TEST_HOME/.dotfiles-backup/latest" ]
}

@test "installer rejects existing symlink pointing to source with trailing newline" {
    mkdir -p "$TEST_HOME/.config"
    python3 -c "import os; os.symlink('$DOTFILES_DIR/yazi\n', '$TEST_HOME/.config/yazi')"

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsupported characters in symlink target"* ]]

    # Existing symlink remains untouched and no transaction is created
    [ -L "$TEST_HOME/.config/yazi" ]
    raw="$(
        readlink -n "$TEST_HOME/.config/yazi"
        printf x
    )"
    [ "${raw%x}" = "$DOTFILES_DIR/yazi"$'\n' ]
    [ ! -f "$TEST_HOME/.dotfiles-backup/latest" ]
}

@test "installer refuses to install when backup root is a symlink" {
    local external_backup="$TEST_ROOT/external_backup"
    mkdir -p "$external_backup"
    ln -s "$external_backup" "$TEST_HOME/.dotfiles-backup"

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"backup root at"* && "$output" == *"is invalid or symlinked"* ]]

    # No files created in external backup directory or home
    [ ! -e "$external_backup/latest" ]
    [ ! -L "$TEST_HOME/.zshrc" ]
}

@test "installer revalidates target ancestors after interactive confirmation" {
    local external_dir="$TEST_ROOT/external-config"
    local input_fifo="$TEST_ROOT/install-input"
    local install_output="$TEST_ROOT/install-output"
    local install_status
    mkdir -p "$external_dir"
    mkfifo "$input_fifo"

    env HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" \
        --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear \
        <"$input_fifo" >"$install_output" 2>&1 &
    local install_pid=$!
    exec 8>"$input_fifo"
    printf 'y\n' >&8

    local attempts=0
    until grep -q "Target: $TEST_HOME/.config/yazi" "$install_output"; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 100 ]; then
            kill "$install_pid" 2>/dev/null || true
            exec 8>&-
            fail "installer did not reach the yazi confirmation"
        fi
        sleep 0.05
    done

    rmdir "$TEST_HOME/.config"
    ln -s "$external_dir" "$TEST_HOME/.config"
    [ -L "$TEST_HOME/.config" ]
    printf 'y\n' >&8
    exec 8>&-
    if wait "$install_pid"; then
        install_status=0
    else
        install_status=$?
    fi

    if [ "$install_status" -eq 0 ]; then
        cat "$install_output"
        fail "installer accepted a symlinked target ancestor after confirmation"
    fi
    grep -q "target ancestor for .config/yazi changed while awaiting confirmation" "$install_output"
    [ ! -e "$external_dir/yazi" ]
    [ ! -f "$TEST_HOME/.dotfiles-backup/latest" ]
}

@test "installer rechecks a journaled symlink before removing it" {
    local fake_bin="$TEST_ROOT/fake-bin"
    local real_git
    mkdir -p "$fake_bin" "$TEST_HOME/.config"
    real_git="$(command -v git)"
    ln -s "prior-yazi" "$TEST_HOME/.config/yazi"

    cat <<'EOF' >"$fake_bin/git"
#!/usr/bin/env bash
/bin/rm -f "$INSTALL_RACE_TARGET"
printf 'replacement created during transaction setup\n' >"$INSTALL_RACE_TARGET"
exec "$INSTALL_REAL_GIT" "$@"
EOF
    chmod +x "$fake_bin/git"

    run env HOME="$TEST_HOME" PATH="$fake_bin:$PATH" \
        INSTALL_REAL_GIT="$real_git" \
        INSTALL_RACE_TARGET="$TEST_HOME/.config/yazi" \
        "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"target changed before installation: .config/yazi"* ]]
    [ -f "$TEST_HOME/.config/yazi" ]
    [ "$(cat "$TEST_HOME/.config/yazi")" = "replacement created during transaction setup" ]

    local tx_id
    tx_id="$(find "$TEST_HOME/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)"
    grep -q '^state=failed$' "$TEST_HOME/.dotfiles-backup/$tx_id/metadata"
}

@test "restore uses the repository path recorded before the checkout moved" {
    local original_repo="$TEST_ROOT/original-repo"
    local moved_repo="$TEST_ROOT/moved-repo"
    local recorded_root
    mkdir -p "$original_repo"
    cp -R "$DOTFILES_DIR/." "$original_repo/"
    recorded_root="$(cd -P "$original_repo" && pwd)"
    printf 'original git config\n' >"$TEST_HOME/.gitconfig"

    run env HOME="$TEST_HOME" "$original_repo/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.gitconfig" ]
    local tx_id
    tx_id="$(tr -d '[:space:]' <"$TEST_HOME/.dotfiles-backup/latest")"
    grep -Fqx "repo_root=$recorded_root" "$TEST_HOME/.dotfiles-backup/$tx_id/metadata"

    mv "$original_repo" "$moved_repo"
    [ ! -e "$original_repo/.gitconfig" ]
    run env HOME="$TEST_HOME" "$moved_repo/bin/restore" --apply latest --yes
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.gitconfig" ]
    [ ! -L "$TEST_HOME/.gitconfig" ]
    [ "$(cat "$TEST_HOME/.gitconfig")" = "original git config" ]
}

@test "failed backup copy leaves the original target restorable" {
    local fake_bin="$TEST_ROOT/fake-copy-bin"
    mkdir -p "$fake_bin"
    printf 'original git config\n' >"$TEST_HOME/.gitconfig"

    cat <<'EOF' >"$fake_bin/cp"
#!/usr/bin/env bash
destination=
for argument in "$@"; do
    case "$argument" in
        -*) ;;
        *) destination="$argument" ;;
    esac
done
printf 'partial backup' >"$destination"
exit 75
EOF
    chmod +x "$fake_bin/cp"

    run env HOME="$TEST_HOME" PATH="$fake_bin:$PATH" \
        "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"failed to stage backup for .gitconfig"* ]]
    [ -f "$TEST_HOME/.gitconfig" ]
    [ "$(cat "$TEST_HOME/.gitconfig")" = "original git config" ]

    local tx_id
    tx_id="$(find "$TEST_HOME/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)"
    grep -q '^state=failed$' "$TEST_HOME/.dotfiles-backup/$tx_id/metadata"
    [ ! -e "$TEST_HOME/.dotfiles-backup/$tx_id/backup-0008" ]

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.gitconfig" ]
    [ "$(cat "$TEST_HOME/.gitconfig")" = "original git config" ]
    grep -q '^state=restored$' "$TEST_HOME/.dotfiles-backup/$tx_id/metadata"
}

@test "completed staged backup makes an interrupted removal resumable" {
    local fake_bin="$TEST_ROOT/fake-remove-bin"
    local real_rm
    mkdir -p "$fake_bin"
    real_rm="$(command -v rm)"
    printf 'original git config\n' >"$TEST_HOME/.gitconfig"

    cat <<'EOF' >"$fake_bin/rm"
#!/usr/bin/env bash
target=
for argument in "$@"; do
    case "$argument" in
        -*) ;;
        *) target="$argument" ;;
    esac
done
if [[ "$target" == *"$INSTALL_FAIL_TARGET"* ]]; then
    exit 75
fi
exec "$INSTALL_REAL_RM" "$@"
EOF
    chmod +x "$fake_bin/rm"

    run env HOME="$TEST_HOME" PATH="$fake_bin:$PATH" \
        INSTALL_REAL_RM="$real_rm" \
        INSTALL_FAIL_TARGET=".install.remove." \
        "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [ -f "$TEST_HOME/.gitconfig" ]
    [ "$(cat "$TEST_HOME/.gitconfig")" = "original git config" ]

    local tx_id
    tx_id="$(find "$TEST_HOME/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)"
    grep -q '^state=failed$' "$TEST_HOME/.dotfiles-backup/$tx_id/metadata"
    [ "$(cat "$TEST_HOME/.dotfiles-backup/$tx_id/payload/0008")" = "original git config" ]

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.gitconfig" ]
    [ "$(cat "$TEST_HOME/.gitconfig")" = "original git config" ]
    [ ! -e "$TEST_HOME/.dotfiles-backup/$tx_id/payload/0008" ]
    grep -q '^state=restored$' "$TEST_HOME/.dotfiles-backup/$tx_id/metadata"
}

@test "install and restore preserve an external hard link to a managed file" {
    printf 'hard-linked git config\n' >"$TEST_HOME/.gitconfig"
    ln "$TEST_HOME/.gitconfig" "$TEST_HOME/gitconfig-peer"

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.gitconfig" ]
    local tx_id
    tx_id="$(tr -d '[:space:]' <"$TEST_HOME/.dotfiles-backup/latest")"
    [ "$TEST_HOME/.dotfiles-backup/$tx_id/payload/0008" -ef "$TEST_HOME/gitconfig-peer" ]

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.gitconfig" ]
    [ ! -L "$TEST_HOME/.gitconfig" ]
    [ "$TEST_HOME/.gitconfig" -ef "$TEST_HOME/gitconfig-peer" ]
    [ "$(cat "$TEST_HOME/.gitconfig")" = "hard-linked git config" ]
}

@test "installer preserves a directory raced into an absent target" {
    local fake_bin="$TEST_ROOT/fake-link-race-bin"
    mkdir -p "$fake_bin"

    cat <<'EOF' >"$fake_bin/mv"
#!/usr/bin/env bash
destination="${@: -1}"
if [ "$destination" = "$INSTALL_RACE_TARGET" ]; then
    mkdir -p "$destination"
fi
exec "$INSTALL_REAL_MV" "$@"
EOF
    chmod +x "$fake_bin/mv"

    run env HOME="$TEST_HOME" PATH="$fake_bin:$PATH" \
        INSTALL_REAL_MV="$(command -v mv)" \
        INSTALL_RACE_TARGET="./yazi" \
        "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"target changed while creating symlink: .config/yazi"* ]]
    [ -d "$TEST_HOME/.config/yazi" ]
    [ -z "$(find "$TEST_HOME/.config/yazi" -mindepth 1 -print -quit)" ]
}

@test "installer preserves a file replaced after backup verification" {
    local fake_bin="$TEST_ROOT/fake-remove-race-bin"
    mkdir -p "$fake_bin"
    printf 'original git config\n' >"$TEST_HOME/.gitconfig"

    cat <<'EOF' >"$fake_bin/mv"
#!/usr/bin/env bash
source=
for argument in "$@"; do
    case "$argument" in
        -*) ;;
        *)
            source="$argument"
            break
            ;;
    esac
done
if [ "$source" = "$INSTALL_RACE_TARGET" ]; then
    "$INSTALL_REAL_RM" -f "$source"
    printf 'replacement created after backup\n' >"$source"
fi
exec "$INSTALL_REAL_MV" "$@"
EOF
    chmod +x "$fake_bin/mv"

    run env HOME="$TEST_HOME" PATH="$fake_bin:$PATH" \
        INSTALL_REAL_MV="$(command -v mv)" \
        INSTALL_REAL_RM="$(command -v rm)" \
        INSTALL_RACE_TARGET="./.gitconfig" \
        "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"target changed while creating symlink: .gitconfig"* ]]
    [ "$(cat "$TEST_HOME/.gitconfig")" = "replacement created after backup" ]

    local tx_id
    tx_id="$(find "$TEST_HOME/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)"
    [ "$(cat "$TEST_HOME/.dotfiles-backup/$tx_id/payload/0008")" = "original git config" ]
    grep -q '^state=failed$' "$TEST_HOME/.dotfiles-backup/$tx_id/metadata"
}

@test "installer placement stays anchored when its parent path is replaced" {
    local fake_bin="$TEST_ROOT/fake-parent-placement-bin"
    local saved_parent="$TEST_HOME/.config-original"
    local external="$TEST_ROOT/external-parent"
    mkdir -p "$fake_bin" "$external"

    cat <<'EOF' >"$fake_bin/ln"
#!/usr/bin/env bash
destination="${@: -1}"
case "$destination" in
    ./.install.stage.*)
        if [ ! -e "$INSTALL_RACE_DONE" ]; then
            : >"$INSTALL_RACE_DONE"
            "$INSTALL_REAL_MV" "$INSTALL_PARENT" "$INSTALL_SAVED_PARENT"
            "$INSTALL_REAL_LN" -s "$INSTALL_EXTERNAL" "$INSTALL_PARENT"
        fi
        ;;
esac
exec "$INSTALL_REAL_LN" "$@"
EOF
    chmod +x "$fake_bin/ln"

    run env HOME="$TEST_HOME" PATH="$fake_bin:$PATH" \
        INSTALL_REAL_LN="$(command -v ln)" \
        INSTALL_REAL_MV="$(command -v mv)" \
        INSTALL_PARENT="$TEST_HOME/.config" \
        INSTALL_SAVED_PARENT="$saved_parent" \
        INSTALL_EXTERNAL="$external" \
        INSTALL_RACE_DONE="$TEST_ROOT/parent-placement-raced" \
        "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"target changed while creating symlink: .config/yazi"* ]]
    [ -L "$TEST_HOME/.config" ]
    [ -z "$(find "$external" -mindepth 1 -print -quit)" ]
    [ -L "$saved_parent/yazi" ]
}

@test "installer stops before mutation when journal sync fails" {
    local fake_bin="$TEST_ROOT/fake-journal-sync-bin"
    mkdir -p "$fake_bin"
    cat <<'EOF' >"$fake_bin/python3"
#!/usr/bin/env bash
if [ "${1:-}" = - ]; then
    exit 75
fi
exec "$INSTALL_REAL_PYTHON" "$@"
EOF
    chmod +x "$fake_bin/python3"

    run env HOME="$TEST_HOME" PATH="$fake_bin:$PATH" \
        INSTALL_REAL_PYTHON="$(command -v python3)" \
        "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"failed to append journal entry for .config/yazi"* ]]
    [ ! -e "$TEST_HOME/.config/yazi" ]
    [ ! -L "$TEST_HOME/.config/yazi" ]
}

@test "installer preserves the original when payload sync fails" {
    local fake_bin="$TEST_ROOT/fake-payload-sync-bin"
    mkdir -p "$fake_bin"
    printf 'original git config\n' >"$TEST_HOME/.gitconfig"
    cat <<'EOF' >"$fake_bin/python3"
#!/usr/bin/env bash
if [ "${1:-}" = - ] && [[ "${2:-}" == */payload/0008 ]]; then
    exit 75
fi
exec "$INSTALL_REAL_PYTHON" "$@"
EOF
    chmod +x "$fake_bin/python3"

    run env HOME="$TEST_HOME" PATH="$fake_bin:$PATH" \
        INSTALL_REAL_PYTHON="$(command -v python3)" \
        "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"failed to sync backup for .gitconfig"* ]]
    [ -f "$TEST_HOME/.gitconfig" ]
    [ ! -L "$TEST_HOME/.gitconfig" ]
    [ "$(cat "$TEST_HOME/.gitconfig")" = "original git config" ]
}

@test "install and restore preserve regular-file extended attributes" {
    printf 'attributed git config\n' >"$TEST_HOME/.gitconfig"
    if command -v xattr >/dev/null 2>&1; then
        xattr -w user.dotfiles preserved "$TEST_HOME/.gitconfig"
    elif command -v setfattr >/dev/null 2>&1 && command -v getfattr >/dev/null 2>&1; then
        setfattr -n user.dotfiles -v preserved "$TEST_HOME/.gitconfig"
    else
        skip "no extended-attribute tools available"
    fi

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -eq 0 ]
    run env HOME="$TEST_HOME" "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -eq 0 ]

    if command -v xattr >/dev/null 2>&1; then
        [ "$(xattr -p user.dotfiles "$TEST_HOME/.gitconfig")" = preserved ]
    else
        [ "$(getfattr --only-values -n user.dotfiles "$TEST_HOME/.gitconfig")" = preserved ]
    fi
}

@test "install and restore preserve directory-entry extended attributes" {
    mkdir -p "$TEST_HOME/.config/yazi"
    printf 'attributed directory content\n' >"$TEST_HOME/.config/yazi/config"
    if command -v xattr >/dev/null 2>&1; then
        xattr -w user.dotfiles preserved "$TEST_HOME/.config/yazi/config"
    elif command -v setfattr >/dev/null 2>&1 && command -v getfattr >/dev/null 2>&1; then
        setfattr -n user.dotfiles -v preserved "$TEST_HOME/.config/yazi/config"
    else
        skip "no extended-attribute tools available"
    fi

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -eq 0 ]
    run env HOME="$TEST_HOME" "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -eq 0 ]

    if command -v xattr >/dev/null 2>&1; then
        [ "$(xattr -p user.dotfiles "$TEST_HOME/.config/yazi/config")" = preserved ]
    else
        [ "$(getfattr --only-values -n user.dotfiles "$TEST_HOME/.config/yazi/config")" = preserved ]
    fi
}

@test "failed quarantined directory cleanup remains restorable" {
    local fake_bin="$TEST_ROOT/fake-directory-cleanup-bin"
    mkdir -p "$fake_bin" "$TEST_HOME/.config/yazi"
    printf 'first original\n' >"$TEST_HOME/.config/yazi/first"
    printf 'second original\n' >"$TEST_HOME/.config/yazi/second"

    cat <<'EOF' >"$fake_bin/rm"
#!/usr/bin/env bash
target="${@: -1}"
if [[ "$target" == *".install.remove."* ]] && [ -d "$target" ]; then
    "$INSTALL_REAL_RM" -f "$target/first"
    exit 75
fi
exec "$INSTALL_REAL_RM" "$@"
EOF
    chmod +x "$fake_bin/rm"

    run env HOME="$TEST_HOME" PATH="$fake_bin:$PATH" \
        INSTALL_REAL_RM="$(command -v rm)" \
        "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -ne 0 ]
    [ ! -e "$TEST_HOME/.config/yazi" ]

    local tx_id
    tx_id="$(find "$TEST_HOME/.dotfiles-backup" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)"
    [ "$(cat "$TEST_HOME/.dotfiles-backup/$tx_id/payload/0001/first")" = "first original" ]
    [ "$(cat "$TEST_HOME/.dotfiles-backup/$tx_id/payload/0001/second")" = "second original" ]

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_HOME/.config/yazi/first")" = "first original" ]
    [ "$(cat "$TEST_HOME/.config/yazi/second")" = "second original" ]
    grep -q '^state=restored$' "$TEST_HOME/.dotfiles-backup/$tx_id/metadata"
}

@test "install and restore preserve directory-entry POSIX ACLs" {
    command -v setfacl >/dev/null 2>&1 && command -v getfacl >/dev/null 2>&1 || skip "no POSIX ACL tools available"
    mkdir -p "$TEST_HOME/.config/yazi"
    printf 'ACL-protected content\n' >"$TEST_HOME/.config/yazi/config"
    setfacl -m u:nobody:r "$TEST_HOME/.config/yazi/config"
    local expected_acl
    expected_acl="$(getfacl -cp "$TEST_HOME/.config/yazi/config")"

    run env HOME="$TEST_HOME" "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear
    [ "$status" -eq 0 ]
    run env HOME="$TEST_HOME" "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -eq 0 ]
    [ "$(getfacl -cp "$TEST_HOME/.config/yazi/config")" = "$expected_acl" ]
}
