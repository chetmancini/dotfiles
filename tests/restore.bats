#!/usr/bin/env bats
# tests/restore.bats — transaction journal and restore regression test suite

setup() {
    load helpers.bash
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-home.XXXXXX")"
    TMP_BACKUP="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-backup.XXXXXX")"
    export HOME="$TMP_HOME"
    export DOTFILES_BACKUP_ROOT="$TMP_BACKUP"
}

teardown() {
    [ -d "$TMP_HOME" ] && rm -rf "$TMP_HOME"
    [ -d "$TMP_BACKUP" ] && rm -rf "$TMP_BACKUP"
}

@test "1. Installer plan mode and already-correct no-op mode create no transaction" {
    # Plan mode
    run "$DOTFILES_DIR/install.sh" --plan --yes --skip-brew --skip-api-keys --no-clear
    [ "$status" -eq 0 ]
    [ ! -f "$TMP_BACKUP/latest" ]
    tx_count="$(find "$TMP_BACKUP" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    [ "$tx_count" -eq 0 ]

    # Apply install to establish all symlinks
    run "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-tpm --skip-api-keys --no-clear
    [ "$status" -eq 0 ]
    [ -f "$TMP_BACKUP/latest" ]
    local first_tx
    first_tx="$(tr -d '[:space:]' <"$TMP_BACKUP/latest")"

    # Second install where everything is already correctly symlinked
    run "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-tpm --skip-api-keys --no-clear
    [ "$status" -eq 0 ]
    local second_tx
    second_tx="$(tr -d '[:space:]' <"$TMP_BACKUP/latest")"
    [ "$first_tx" = "$second_tx" ]
    tx_count="$(find "$TMP_BACKUP" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    [ "$tx_count" -eq 1 ]
}

@test "2. Installation over an existing regular file preserves and journals it" {
    echo "original git config content" >"$HOME/.gitconfig"

    run "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-tpm --skip-api-keys --no-clear
    [ "$status" -eq 0 ]
    [ -L "$HOME/.gitconfig" ]

    local tx_id
    tx_id="$(tr -d '[:space:]' <"$TMP_BACKUP/latest")"
    local tx_dir="$TMP_BACKUP/$tx_id"
    [ -d "$tx_dir" ]
    [ -f "$tx_dir/metadata" ]

    grep -q '^state=complete$' "$tx_dir/metadata"
    grep -E '^[0-9]+\|\.gitconfig\|file\|payload/[0-9]+\|\.gitconfig$' "$tx_dir/entries"

    # Find the payload path recorded in entries for .gitconfig
    local payload_rel
    payload_rel="$(grep '|\.gitconfig|file|' "$tx_dir/entries" | cut -d'|' -f4)"
    [ -f "$tx_dir/$payload_rel" ]
    [ "$(cat "$tx_dir/$payload_rel")" = "original git config content" ]
}

@test "3. Installation over a directory preserves the entire directory tree" {
    mkdir -p "$HOME/.config/yazi/subdir"
    echo "root file" >"$HOME/.config/yazi/file.txt"
    echo "nested file" >"$HOME/.config/yazi/subdir/nested.txt"

    run "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-tpm --skip-api-keys --no-clear
    [ "$status" -eq 0 ]
    [ -L "$HOME/.config/yazi" ]

    local tx_id
    tx_id="$(tr -d '[:space:]' <"$TMP_BACKUP/latest")"
    local tx_dir="$TMP_BACKUP/$tx_id"

    grep -E '^[0-9]+\|\.config/yazi\|directory\|payload/[0-9]+\|yazi$' "$tx_dir/entries"

    local payload_rel
    payload_rel="$(grep '|\.config/yazi|directory|' "$tx_dir/entries" | cut -d'|' -f4)"
    [ -d "$tx_dir/$payload_rel" ]
    [ -f "$tx_dir/$payload_rel/file.txt" ]
    [ -f "$tx_dir/$payload_rel/subdir/nested.txt" ]
    [ "$(cat "$tx_dir/$payload_rel/file.txt")" = "root file" ]
    [ "$(cat "$tx_dir/$payload_rel/subdir/nested.txt")" = "nested file" ]
}

@test "4. Installation over relative and absolute symlinks records raw link targets" {
    mkdir -p "$TMP_HOME/custom_dir"
    ln -s "custom_dir/relative_target" "$HOME/.zshrc"
    ln -s "/tmp/custom_absolute_target" "$HOME/.bashrc"

    run "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-tpm --skip-api-keys --no-clear
    [ "$status" -eq 0 ]

    local tx_id
    tx_id="$(tr -d '[:space:]' <"$TMP_BACKUP/latest")"
    local tx_dir="$TMP_BACKUP/$tx_id"

    grep -E '^[0-9]+\|\.zshrc\|symlink\|custom_dir/relative_target\|\.zshrc$' "$tx_dir/entries"
    grep -E '^[0-9]+\|\.bashrc\|symlink\|/tmp/custom_absolute_target\|\.bashrc$' "$tx_dir/entries"
}

@test "5. An originally absent target is removed during restore" {
    [ ! -e "$HOME/.npmrc" ]
    [ ! -L "$HOME/.npmrc" ]

    run "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-tpm --skip-api-keys --no-clear
    [ "$status" -eq 0 ]
    [ -L "$HOME/.npmrc" ]

    local tx_id
    tx_id="$(tr -d '[:space:]' <"$TMP_BACKUP/latest")"
    local tx_dir="$TMP_BACKUP/$tx_id"

    grep -E '^[0-9]+\|\.npmrc\|absent\|\|npm/npmrc$' "$tx_dir/entries"

    run "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.npmrc" ]
    [ ! -L "$HOME/.npmrc" ]
}

@test "6. latest resolves only a validated restorable transaction ID" {
    # 1. Illegal characters in latest
    echo "../../evil" >"$TMP_BACKUP/latest"
    run "$DOTFILES_DIR/bin/restore" --plan latest
    [ "$status" -ne 0 ]

    # 2. Nonexistent transaction ID in latest
    echo "20260101T000000-111-222" >"$TMP_BACKUP/latest"
    run "$DOTFILES_DIR/bin/restore" --plan latest
    [ "$status" -ne 0 ]

    # 3. Transaction with state=failed
    local failed_id="20260101T000000-111-333"
    local failed_dir="$TMP_BACKUP/$failed_id"
    mkdir -p "$failed_dir"
    cat <<EOF >"$failed_dir/metadata"
version=1
id=$failed_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=failed
EOF
    touch "$failed_dir/entries"
    echo "$failed_id" >"$TMP_BACKUP/latest"
    run "$DOTFILES_DIR/bin/restore" --plan latest
    [ "$status" -ne 0 ]

    # 4. Transaction with state=in_progress
    local inprog_id="20260101T000000-111-444"
    local inprog_dir="$TMP_BACKUP/$inprog_id"
    mkdir -p "$inprog_dir"
    cat <<EOF >"$inprog_dir/metadata"
version=1
id=$inprog_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=in_progress
EOF
    touch "$inprog_dir/entries"
    echo "$inprog_id" >"$TMP_BACKUP/latest"
    run "$DOTFILES_DIR/bin/restore" --plan latest
    [ "$status" -ne 0 ]

    # 5. Valid complete transaction resolves
    local valid_id="20260101T000000-111-555"
    local valid_dir="$TMP_BACKUP/$valid_id"
    mkdir -p "$valid_dir"
    cat <<EOF >"$valid_dir/metadata"
version=1
id=$valid_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=0
EOF
    touch "$valid_dir/entries"
    echo "$valid_id" >"$TMP_BACKUP/latest"
    run "$DOTFILES_DIR/bin/restore" --plan latest
    [ "$status" -eq 0 ]
}

@test "7. --list omits payload contents and prior symlink targets" {
    local tx_id="20260101T000000-111-666"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=abcdef1
state=complete
entry_count=1
EOF
    echo "SECRET_PAYLOAD_TOKEN" >"$tx_dir/payload/0001"
    echo "0001|.gitconfig|symlink|/super/secret/symlink/target|.gitconfig" >"$tx_dir/entries"

    run "$DOTFILES_DIR/bin/restore" --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"$tx_id"* ]]
    [[ "$output" == *"complete"* ]]
    [[ "$output" == *"1"* ]]
    [[ "$output" != *"SECRET_PAYLOAD_TOKEN"* ]]
    [[ "$output" != *"/super/secret/symlink/target"* ]]
}

@test "8. --plan produces actions but byte-for-byte leaves HOME and metadata alone" {
    echo "important git config" >"$HOME/.gitconfig"
    run "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-tpm --skip-api-keys --no-clear
    [ "$status" -eq 0 ]

    local tx_id
    tx_id="$(tr -d '[:space:]' <"$TMP_BACKUP/latest")"
    local meta_before
    meta_before="$(cat "$TMP_BACKUP/$tx_id/metadata")"

    # Take snapshot of HOME symlinks and files
    local zshrc_target_before gitconfig_target_before
    zshrc_target_before="$(readlink "$HOME/.zshrc")"
    gitconfig_target_before="$(readlink "$HOME/.gitconfig")"

    run "$DOTFILES_DIR/bin/restore" --plan latest
    [ "$status" -eq 0 ]
    [[ "$output" == *"Plan restore for transaction"* ]]
    [[ "$output" == *"[restore] .gitconfig"* ]]

    # Assert byte-for-byte unchanged metadata
    local meta_after
    meta_after="$(cat "$TMP_BACKUP/$tx_id/metadata")"
    [ "$meta_before" = "$meta_after" ]

    # Assert unchanged HOME state
    [ "$(readlink "$HOME/.zshrc")" = "$zshrc_target_before" ]
    [ "$(readlink "$HOME/.gitconfig")" = "$gitconfig_target_before" ]
}

@test "9. --apply --yes restores all prior kinds in reverse order and marks restored" {
    echo "my-original-git" >"$HOME/.gitconfig"
    mkdir -p "$HOME/.config/yazi/inner"
    echo "yazi-original" >"$HOME/.config/yazi/inner/file.txt"
    ln -s "prior/relative/link" "$HOME/.zshrc"
    ln -s "/prior/abs/link" "$HOME/.bashrc"
    [ ! -e "$HOME/.npmrc" ]

    run "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-tpm --skip-api-keys --no-clear
    [ "$status" -eq 0 ]

    # Verify everything was symlinked
    [ -L "$HOME/.gitconfig" ]
    [ -L "$HOME/.config/yazi" ]
    [ -L "$HOME/.zshrc" ]
    [ -L "$HOME/.bashrc" ]
    [ -L "$HOME/.npmrc" ]

    local tx_id
    tx_id="$(tr -d '[:space:]' <"$TMP_BACKUP/latest")"

    run "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -eq 0 ]

    # 1. file restored
    [ -f "$HOME/.gitconfig" ]
    [ ! -L "$HOME/.gitconfig" ]
    [ "$(cat "$HOME/.gitconfig")" = "my-original-git" ]

    # 2. directory tree restored
    [ -d "$HOME/.config/yazi" ]
    [ ! -L "$HOME/.config/yazi" ]
    [ -f "$HOME/.config/yazi/inner/file.txt" ]
    [ "$(cat "$HOME/.config/yazi/inner/file.txt")" = "yazi-original" ]

    # 3. relative symlink restored
    [ -L "$HOME/.zshrc" ]
    [ "$(readlink "$HOME/.zshrc")" = "prior/relative/link" ]

    # 4. absolute symlink restored
    [ -L "$HOME/.bashrc" ]
    [ "$(readlink "$HOME/.bashrc")" = "/prior/abs/link" ]

    # 5. absent target removed
    [ ! -e "$HOME/.npmrc" ]
    [ ! -L "$HOME/.npmrc" ]

    # Metadata marked state=restored
    grep -q '^state=restored$' "$TMP_BACKUP/$tx_id/metadata"
}

@test "10. A target modified after installation causes full preflight failure with no partial changes" {
    echo "git original" >"$HOME/.gitconfig"
    run "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-tpm --skip-api-keys --no-clear
    [ "$status" -eq 0 ]

    local tx_id
    tx_id="$(tr -d '[:space:]' <"$TMP_BACKUP/latest")"

    # Modify .zshrc after install by replacing symlink with a regular file
    rm -f "$HOME/.zshrc"
    echo "tampered zshrc" >"$HOME/.zshrc"

    run "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* ]]

    # Assert no partial changes: .gitconfig must STILL be the managed symlink
    [ -L "$HOME/.gitconfig" ]
    [ "$(readlink "$HOME/.gitconfig")" = "$DOTFILES_DIR/.gitconfig" ]

    # .zshrc must still have the tampered content
    [ -f "$HOME/.zshrc" ]
    [ "$(cat "$HOME/.zshrc")" = "tampered zshrc" ]

    # Transaction state remains complete, not restored
    grep -q '^state=complete$' "$TMP_BACKUP/$tx_id/metadata"
}

@test "11. Invalid IDs, traversal fields, pipes/newlines, unsupported versions, and malformed metadata are rejected" {
    # 1. Invalid ID traversal
    run "$DOTFILES_DIR/bin/restore" --plan "../bad-id"
    [ "$status" -ne 0 ]

    # 2. Traversal in journal target
    local tx1="20260101T000000-111-701"
    mkdir -p "$TMP_BACKUP/$tx1"
    cat <<EOF >"$TMP_BACKUP/$tx1/metadata"
version=1
id=$tx1
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    echo "0001|../etc/passwd|absent||passwd" >"$TMP_BACKUP/$tx1/entries"
    run "$DOTFILES_DIR/bin/restore" --plan "$tx1"
    [ "$status" -ne 0 ]

    # 3. Traversal in journal installed source
    local tx2="20260101T000000-111-702"
    mkdir -p "$TMP_BACKUP/$tx2"
    cat <<EOF >"$TMP_BACKUP/$tx2/metadata"
version=1
id=$tx2
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    echo "0001|.gitconfig|absent||../evil" >"$TMP_BACKUP/$tx2/entries"
    run "$DOTFILES_DIR/bin/restore" --plan "$tx2"
    [ "$status" -ne 0 ]

    # 4. Unsupported version
    local tx3="20260101T000000-111-703"
    mkdir -p "$TMP_BACKUP/$tx3"
    cat <<EOF >"$TMP_BACKUP/$tx3/metadata"
version=2
id=$tx3
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=0
EOF
    touch "$TMP_BACKUP/$tx3/entries"
    run "$DOTFILES_DIR/bin/restore" --plan "$tx3"
    [ "$status" -ne 0 ]

    # 5. Malformed metadata (missing id)
    local tx4="20260101T000000-111-704"
    mkdir -p "$TMP_BACKUP/$tx4"
    cat <<EOF >"$TMP_BACKUP/$tx4/metadata"
version=1
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=0
EOF
    touch "$TMP_BACKUP/$tx4/entries"
    run "$DOTFILES_DIR/bin/restore" --plan "$tx4"
    [ "$status" -ne 0 ]
}

@test "12. A synthetic failed/partial transaction is safely previewed and restored only when its current-state preconditions match" {
    local tx_id="20260101T000000-111-801"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=failed
EOF
    echo "original git content" >"$tx_dir/payload/0001"
    echo "0001|.gitconfig|file|payload/0001|.gitconfig" >"$tx_dir/entries"

    # Match state 1 precondition: target is managed symlink
    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    # Preview succeeds on failed transaction with matching preconditions
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Plan restore for transaction ${tx_id} (state: failed):"* ]]

    # Apply succeeds
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -eq 0 ]
    [ -f "$HOME/.gitconfig" ]
    [ ! -L "$HOME/.gitconfig" ]
    [ "$(cat "$HOME/.gitconfig")" = "original git content" ]
    grep -q '^state=restored$' "$tx_dir/metadata"
}

@test "13. A second apply refuses and preserves the already-restored state" {
    echo "git file" >"$HOME/.gitconfig"
    run "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-tpm --skip-api-keys --no-clear
    [ "$status" -eq 0 ]

    local tx_id
    tx_id="$(tr -d '[:space:]' <"$TMP_BACKUP/latest")"

    # First apply succeeds
    run "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -eq 0 ]
    grep -q '^state=restored$' "$TMP_BACKUP/$tx_id/metadata"

    # Second apply refuses
    run "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"already restored"* ]]

    # Preserves restored state in metadata
    grep -q '^state=restored$' "$TMP_BACKUP/$tx_id/metadata"
}

@test "14. An unsupported FIFO/socket-like target stops installation before mutation" {
    mkdir -p "$HOME/.config"
    mkfifo "$HOME/.config/yazi"

    run "$DOTFILES_DIR/install.sh" --yes --skip-brew --skip-tpm --skip-api-keys --no-clear
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsupported filesystem object at"* ]]
    [[ "$output" == *"$HOME/.config/yazi"* ]]

    # Target must remain a FIFO untouched
    [ -p "$HOME/.config/yazi" ]

    # No completed transaction created
    [ ! -f "$TMP_BACKUP/latest" ]
}

@test "15. Preflight rejects payload kind mismatch before modifying any target" {
    local tx_id="20260101T000000-111-802"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    # prior_kind says file, but payload is corrupted to be a directory
    mkdir -p "$tx_dir/payload/0001"
    echo "0001|.gitconfig|file|payload/0001|.gitconfig" >"$tx_dir/entries"

    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    # Plan detects conflict
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]

    # Apply aborts before removing symlink
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* ]]

    # Target remains the untouched managed symlink
    [ -L "$HOME/.gitconfig" ]
    [ "$(readlink "$HOME/.gitconfig")" = "$DOTFILES_DIR/.gitconfig" ]
    grep -q '^state=complete$' "$tx_dir/metadata"
}

@test "16. Preflight rejects target kind mismatch in no-op state" {
    local tx_id="20260101T000000-111-803"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=failed
EOF
    # Journal says prior target was a file, and payload was never moved
    echo "0001|.gitconfig|file|payload/0001|.gitconfig" >"$tx_dir/entries"

    # But current target is unexpectedly a directory instead of a regular file
    mkdir -p "$HOME/.gitconfig"

    # Plan reports conflict
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]

    # Apply aborts and preserves directory
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* ]]
    [ -d "$HOME/.gitconfig" ]
    [ ! -L "$HOME/.gitconfig" ]
    grep -q '^state=failed$' "$tx_dir/metadata"
}

@test "17. Preflight rejects absent parent directory when restoring an absent target" {
    local tx_id="20260101T000000-111-804"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=failed
EOF
    # Journal says target file payload exists, target is currently absent
    echo "test content" >"$tx_dir/payload/0001"
    echo "0001|.config/yazi/yazi.toml|file|payload/0001|.config/yazi/yazi.toml" >"$tx_dir/entries"

    # Destination parent directory does NOT exist
    rm -rf "$HOME/.config/yazi"

    # Plan reports conflict
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]

    # Apply aborts before modifying anything
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* ]]
    [ ! -e "$HOME/.config/yazi/yazi.toml" ]
    grep -q '^state=failed$' "$tx_dir/metadata"

    # If parent directory is created, restore succeeds
    mkdir -p "$HOME/.config/yazi"
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/yazi/yazi.toml" ]
    [ "$(cat "$HOME/.config/yazi/yazi.toml")" = "test content" ]
    grep -q '^state=restored$' "$tx_dir/metadata"
}

@test "18. Preflight rejects symlinked ancestor directory when restoring a target" {
    local tx_id="20260101T000000-111-805"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=failed
EOF
    echo "herdr content" >"$tx_dir/payload/0001"
    echo "0001|.config/herdr/config.toml|file|payload/0001|.config/herdr/config.toml" >"$tx_dir/entries"

    # Ancestor .config/herdr is replaced with a symlink pointing to another directory
    local redirect_dir="$TMP_BACKUP/redirected_herdr"
    mkdir -p "$redirect_dir" "$HOME/.config"
    ln -s "$redirect_dir" "$HOME/.config/herdr"

    # Plan reports conflict because ancestor is a symlink
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]

    # Apply aborts without writing to the redirected target
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* ]]
    [ ! -e "$redirect_dir/config.toml" ]
    grep -q '^state=failed$' "$tx_dir/metadata"
}

@test "19. Restore safely recreates symlink destinations starting with a hyphen" {
    local tx_id="20260101T000000-111-806"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    echo "0001|.gitconfig|symlink|-hyphen-target|.gitconfig" >"$tx_dir/entries"

    # Target is managed symlink
    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    # Apply recreates symlink without option parsing error
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -eq 0 ]
    [ -L "$HOME/.gitconfig" ]
    [ "$(readlink "$HOME/.gitconfig")" = "-hyphen-target" ]
    grep -q '^state=restored$' "$tx_dir/metadata"
}

@test "20. Preflight rejects duplicate sequence numbers in transaction journal" {
    local tx_id="20260101T000000-111-807"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=2
EOF
    echo "content" >"$tx_dir/payload/0001"
    # Duplicate sequence number 0001
    cat <<EOF >"$tx_dir/entries"
0001|.gitconfig|file|payload/0001|.gitconfig
0001|.zshrc|file|payload/0001|.zshrc
EOF

    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
    ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

    # Plan reports duplicate sequence error
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"duplicate sequence number"* ]]

    # Apply aborts before modifying any symlinks
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"duplicate sequence number"* ]]
    [ -L "$HOME/.gitconfig" ]
    [ -L "$HOME/.zshrc" ]
    grep -q '^state=complete$' "$tx_dir/metadata"
}

@test "21. Preflight rejects symlinked payload directory" {
    local tx_id="20260101T000000-111-808"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    echo "0001|.gitconfig|file|payload/0001|.gitconfig" >"$tx_dir/entries"

    # External payload directory outside backup root
    local external_dir="$TMP_HOME/external_payload"
    mkdir -p "$external_dir"
    echo "external payload content" >"$external_dir/0001"

    # Symlink payload/ to external directory
    ln -s "$external_dir" "$tx_dir/payload"

    # Managed symlink exists
    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    # Plan reports conflict
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]

    # Apply aborts before modifying any files
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* ]]

    # External file and target are untouched
    [ -f "$external_dir/0001" ]
    [ -L "$HOME/.gitconfig" ]
    grep -q '^state=complete$' "$tx_dir/metadata"
}

@test "22. Restore recognizes managed symlink installed via symlinked repository path" {
    local tx_id="20260101T000000-111-809"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    echo "original content" >"$tx_dir/payload/0001"
    echo "0001|.gitconfig|file|payload/0001|.gitconfig" >"$tx_dir/entries"

    # Create symlink to repo directory
    local symlink_repo="$TMP_HOME/repo-symlink"
    ln -s "$DOTFILES_DIR" "$symlink_repo"

    # Target points to symlink_repo path rather than physical DOTFILES_DIR
    ln -sf "$symlink_repo/.gitconfig" "$HOME/.gitconfig"

    # Plan recognizes it as managed symlink and plans restore
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[restore] .gitconfig: replace managed symlink"* ]]

    # Apply restores original file
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -eq 0 ]
    [ -f "$HOME/.gitconfig" ]
    [ ! -L "$HOME/.gitconfig" ]
    [ "$(cat "$HOME/.gitconfig")" = "original content" ]
    grep -q '^state=restored$' "$tx_dir/metadata"
}

@test "23. Apply fails closed if target state changes unexpectedly at apply time" {
    local tx_id="20260101T000000-111-810"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    echo "original content" >"$tx_dir/payload/0001"
    echo "0001|.gitconfig|file|payload/0001|.gitconfig" >"$tx_dir/entries"

    # Target is neither managed symlink nor original file (e.g. symlink to foreign location)
    ln -sf "/dev/null" "$HOME/.gitconfig"

    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* || "$output" == *"target state changed"* ]]
    # Metadata is not marked restored
    grep -q '^state=complete$' "$tx_dir/metadata"
    # Target still points to foreign location
    [ -L "$HOME/.gitconfig" ]
    [ "$(readlink "$HOME/.gitconfig")" = "/dev/null" ]
}

@test "24. Reject multiple transaction selectors in --apply" {
    # Two explicit selectors
    run "$DOTFILES_DIR/bin/restore" --apply OLD_ID latest --yes
    [ "$status" -eq 64 ]
    [[ "$output" == *"multiple transaction selectors"* ]]

    run "$DOTFILES_DIR/bin/restore" --apply latest OLD_ID --yes
    [ "$status" -eq 64 ]
    [[ "$output" == *"multiple transaction selectors"* ]]

    run "$DOTFILES_DIR/bin/restore" --apply id1 id2
    [ "$status" -eq 64 ]
    [[ "$output" == *"multiple transaction selectors"* ]]
}

@test "25. Preflight rejects symlinked transaction directory during resolution" {
    local tx_id="20260101T000000-111-811"
    local external_tx="$TMP_HOME/external_tx"
    mkdir -p "$external_tx"
    cat <<EOF >"$external_tx/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    echo "0001|.gitconfig|absent|-|.gitconfig" >"$external_tx/entries"

    # Symlink tx_dir into backup root
    ln -s "$external_tx" "$TMP_BACKUP/$tx_id"

    # Managed symlink exists in HOME
    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    # Plan refuses symlinked transaction directory
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]

    # Apply refuses symlinked transaction directory
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]

    # Symlink in HOME is untouched
    [ -L "$HOME/.gitconfig" ]
    grep -q '^state=complete$' "$external_tx/metadata"

    # If latest points to symlinked transaction, latest also refuses
    echo "$tx_id" >"$TMP_BACKUP/latest"
    run "$DOTFILES_DIR/bin/restore" --plan latest
    [ "$status" -ne 0 ]
    run "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -ne 0 ]
    [ -L "$HOME/.gitconfig" ]
}

@test "26. Preflight rejects duplicate target paths in transaction journal" {
    local tx_id="20260101T000000-111-812"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=2
EOF
    echo "payload 1" >"$tx_dir/payload/0001"
    echo "payload 2" >"$tx_dir/payload/0002"
    # Distinct sequences (0001 and 0002) but duplicate target path (.gitconfig and ./.gitconfig)
    cat <<EOF >"$tx_dir/entries"
0001|.gitconfig|file|payload/0001|.gitconfig
0002|./.gitconfig|file|payload/0002|.gitconfig
EOF

    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    # Plan reports duplicate target path error
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"duplicate target path"* ]]

    # Apply aborts before modifying any symlinks
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"duplicate target path"* ]]
    [ -L "$HOME/.gitconfig" ]
    grep -q '^state=complete$' "$tx_dir/metadata"
    [ -f "$tx_dir/payload/0001" ]
    [ -f "$tx_dir/payload/0002" ]
}

@test "27. Symlink target with trailing newlines is not treated as managed symlink" {
    local tx_id="20260101T000000-111-813"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    echo "original content" >"$tx_dir/payload/0001"
    echo "0001|.gitconfig|file|payload/0001|.gitconfig" >"$tx_dir/entries"

    # Symlink target has trailing newline pointing to expected source + \n
    python3 -c "import os; os.symlink('$DOTFILES_DIR/.gitconfig\n', '$HOME/.gitconfig')"

    # Plan reports conflict because link is not identified as managed
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]

    # Apply aborts before modifying the user-modified symlink
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* ]]

    # Symlink remains with its trailing newline
    [ -L "$HOME/.gitconfig" ]
    raw="$(
        readlink -n "$HOME/.gitconfig"
        printf x
    )"
    [ "${raw%x}" = "$DOTFILES_DIR/.gitconfig"$'\n' ]
    grep -q '^state=complete$' "$tx_dir/metadata"
}

@test "28. Symlinked entries journal is rejected before restore" {
    local tx_id="20260101T000000-111-814"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF

    # External entries file outside the transaction directory
    local external_entries="$TMP_HOME/external_entries"
    echo "0001|.gitconfig|absent|-|.gitconfig" >"$external_entries"

    # Symlink entries into transaction directory
    ln -s "$external_entries" "$tx_dir/entries"

    # Target is managed symlink
    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    # Plan rejects symlinked entries
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"symlink"* ]]

    # Apply rejects symlinked entries before touching any file
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"symlink"* ]]

    # Symlink in HOME is untouched
    [ -L "$HOME/.gitconfig" ]
    grep -q '^state=complete$' "$tx_dir/metadata"
}

@test "29. Completed transaction rejects missing payload as conflict instead of treating as untouched" {
    local tx_id="20260101T000000-111-815"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    # Payload 0001 is missing, but target in HOME is an unrelated regular file
    echo "0001|.gitconfig|file|payload/0001|.gitconfig" >"$tx_dir/entries"
    echo "unrelated file content" >"$HOME/.gitconfig"

    # Plan reports conflict, does not accept as no-op
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]

    # Apply aborts before touching the file
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* ]]

    [ -f "$HOME/.gitconfig" ]
    [ ! -L "$HOME/.gitconfig" ]
    [ "$(cat "$HOME/.gitconfig")" = "unrelated file content" ]
    grep -q '^state=complete$' "$tx_dir/metadata"
}

@test "30. Non-contiguous sequence numbers in journal are rejected before restore" {
    local tx_id="20260101T000000-111-816"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=2
EOF
    echo "content 1" >"$tx_dir/payload/0001"
    echo "content 3" >"$tx_dir/payload/0003"
    cat <<EOF >"$tx_dir/entries"
0001|.gitconfig|file|payload/0001|.gitconfig
0003|.zshrc|file|payload/0003|.zshrc
EOF

    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
    ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

    # Plan reports non-contiguous sequence error
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"non-contiguous sequence number"* ]]

    # Apply aborts without touching symlinks
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"non-contiguous sequence number"* ]]

    [ -L "$HOME/.gitconfig" ]
    [ -L "$HOME/.zshrc" ]
    grep -q '^state=complete$' "$tx_dir/metadata"
}

@test "31. Truncated journal with missing final entries is rejected before restore" {
    local tx_id="20260101T000000-111-817"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=2
EOF
    echo "content 1" >"$tx_dir/payload/0001"
    # Entry 0002 is omitted/truncated, leaving only 0001
    cat <<EOF >"$tx_dir/entries"
0001|.gitconfig|file|payload/0001|.gitconfig
EOF

    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    # Plan reports entry count mismatch
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"entry count mismatch"* ]]

    # Apply aborts without touching symlinks
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"entry count mismatch"* ]]

    [ -L "$HOME/.gitconfig" ]
    grep -q '^state=complete$' "$tx_dir/metadata"
}

@test "32. Non-writable payload directory causes preflight rejection and preserves target" {
    local tx_id="20260101T000000-111-818"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    echo "original content" >"$tx_dir/payload/0001"
    echo "0001|.gitconfig|file|payload/0001|.gitconfig" >"$tx_dir/entries"

    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    # Make payload directory read-only
    chmod a-w "$tx_dir/payload"

    # Plan reports conflict due to non-writable payload directory
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]

    # Apply aborts before removing managed link
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* ]]

    # Managed symlink in HOME remains intact
    [ -L "$HOME/.gitconfig" ]
    [ "$(readlink "$HOME/.gitconfig")" = "$DOTFILES_DIR/.gitconfig" ]
    grep -q '^state=complete$' "$tx_dir/metadata"

    # Clean up permissions so teardown succeeds
    chmod u+w "$tx_dir/payload"
}

@test "33. Non-writable transaction directory rejects payload-free restore before removing targets" {
    local tx_id="20260101T000000-111-819"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=2
EOF
    cat <<EOF >"$tx_dir/entries"
0001|.zshrc|absent||.zshrc
0002|.gitconfig|symlink|old_gitconfig|.gitconfig
EOF

    ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    # Make transaction directory read-only
    chmod a-w "$tx_dir"

    # Plan reports conflict due to non-writable transaction directory
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]

    # Apply aborts before removing or modifying managed links
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* ]]

    # Managed symlinks in HOME remain intact
    [ -L "$HOME/.zshrc" ]
    [ "$(readlink "$HOME/.zshrc")" = "$DOTFILES_DIR/.zshrc" ]
    [ -L "$HOME/.gitconfig" ]
    [ "$(readlink "$HOME/.gitconfig")" = "$DOTFILES_DIR/.gitconfig" ]

    # Clean up permissions so teardown succeeds
    chmod u+w "$tx_dir"
    grep -q '^state=complete$' "$tx_dir/metadata"
}

@test "34. Read-only target destination parent causes preflight rejection and preserves targets" {
    local tx_id="20260101T000000-111-820"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=1
EOF
    echo "original content" >"$tx_dir/payload/0001"
    mkdir -p "$HOME/.config/testpkg"
    echo "0001|.config/testpkg/config|file|payload/0001|.config/testpkg/config" >"$tx_dir/entries"

    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.config/testpkg/config"

    # Make destination parent directory read-only
    chmod a-w "$HOME/.config/testpkg"

    # Plan reports conflict due to unwritable destination parent
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict"* ]]

    # Apply aborts before removing or modifying managed link
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"Conflict detected"* ]]

    # Target remains intact
    [ -L "$HOME/.config/testpkg/config" ]
    [ "$(readlink "$HOME/.config/testpkg/config")" = "$DOTFILES_DIR/.gitconfig" ]
    grep -q '^state=complete$' "$tx_dir/metadata"

    chmod u+w "$HOME/.config/testpkg"
}

@test "35. Completed transaction missing entry_count in metadata is rejected before restore" {
    local tx_id="20260101T000000-111-821"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir/payload"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
EOF
    echo "original content" >"$tx_dir/payload/0001"
    echo "0001|.gitconfig|file|payload/0001|.gitconfig" >"$tx_dir/entries"

    ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    # Plan reports missing entry_count
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing entry_count in metadata"* ]]

    # Apply aborts without touching symlinks
    run "$DOTFILES_DIR/bin/restore" --apply "$tx_id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing entry_count in metadata"* ]]

    [ -L "$HOME/.gitconfig" ]
    grep -q '^state=complete$' "$tx_dir/metadata"
}

@test "36. Metadata with duplicate key having empty initial value is rejected" {
    local tx_id="20260101T000000-111-822"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=
state=complete
entry_count=0
EOF
    touch "$tx_dir/entries"

    # read_transaction_metadata returns 1 directly on duplicate key
    run bash -c "source '$DOTFILES_DIR/bin/lib/transactions.sh' && read_transaction_metadata '$tx_dir/metadata'"
    [ "$status" -ne 0 ]

    # bin/restore --plan fails to resolve transaction due to invalid metadata
    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not resolve transaction"* ]]
}

@test "37. Metadata ID must match its transaction directory" {
    local tx_id="20260101T000000-111-823"
    local other_id="20260101T000000-111-824"
    local tx_dir="$TMP_BACKUP/$tx_id"
    mkdir -p "$tx_dir"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$other_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=0
EOF
    touch "$tx_dir/entries"

    run "$DOTFILES_DIR/bin/restore" --plan "$tx_id"
    [ "$status" -ne 0 ]
    [[ "$output" == *"directory and metadata IDs do not match"* ]]
}

@test "38. Plan rejects option-like transaction selectors as usage errors" {
    run "$DOTFILES_DIR/bin/restore" --plan --yes
    [ "$status" -eq 64 ]

    run "$DOTFILES_DIR/bin/restore" --plan -y
    [ "$status" -eq 64 ]
}

@test "39. Interrupted restore resumes completed entries and finishes remaining work" {
    local tx_id="20260101T000000-111-825"
    local tx_dir="$TMP_BACKUP/$tx_id"
    local fake_bin="$TMP_HOME/fake-bin"
    mkdir -p "$tx_dir/payload" "$fake_bin"
    cat <<EOF >"$tx_dir/metadata"
version=1
id=$tx_id
created_at=2026-01-01T00:00:00Z
repo_revision=dummy
state=complete
entry_count=2
EOF
    printf 'original gitconfig\n' >"$tx_dir/payload/0001"
    printf 'original zshrc\n' >"$tx_dir/payload/0002"
    cat <<EOF >"$tx_dir/entries"
0001|.gitconfig|file|payload/0001|.gitconfig
0002|.zshrc|file|payload/0002|.zshrc
EOF
    printf '%s\n' "$tx_id" >"$TMP_BACKUP/latest"
    ln -s "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
    ln -s "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

    cat <<'EOF' >"$fake_bin/mv"
#!/usr/bin/env bash
"$RESTORE_REAL_MV" "$@"
status=$?
destination=
for argument in "$@"; do
    destination="$argument"
done
if [ "$status" -eq 0 ] && [ "$destination" = "$RESTORE_COMPLETED_TARGET" ]; then
    rm -f -- "$RESTORE_RACE_TARGET"
    ln -s /dev/null "$RESTORE_RACE_TARGET"
fi
exit "$status"
EOF
    chmod +x "$fake_bin/mv"

    run env PATH="$fake_bin:$PATH" \
        RESTORE_REAL_MV="$(command -v mv)" \
        RESTORE_COMPLETED_TARGET="$HOME/.zshrc" \
        RESTORE_RACE_TARGET="$HOME/.gitconfig" \
        "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"target state changed at apply time: .gitconfig"* ]]
    grep -q '^state=restoring$' "$tx_dir/metadata"
    [ -f "$HOME/.zshrc" ]
    [ "$(cat "$HOME/.zshrc")" = "original zshrc" ]
    [ ! -e "$tx_dir/payload/0002" ]
    [ -f "$tx_dir/payload/0001" ]

    rm -f "$HOME/.gitconfig"
    ln -s "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

    run "$DOTFILES_DIR/bin/restore" --apply latest --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.gitconfig")" = "original gitconfig" ]
    [ "$(cat "$HOME/.zshrc")" = "original zshrc" ]
    grep -q '^state=restored$' "$tx_dir/metadata"
}
