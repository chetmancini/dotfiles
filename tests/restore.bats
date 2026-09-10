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

@test "6. latest resolves only a validated complete transaction ID" {
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
