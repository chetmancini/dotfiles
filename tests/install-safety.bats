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
