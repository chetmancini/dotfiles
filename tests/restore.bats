#!/usr/bin/env bats
# tests/restore.bats — transactional install and conflict-safe restore

setup() {
    load helpers.bash
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-restore.XXXXXX")"
    export HOME="$TEST_ROOT/home"
    export DOTFILES_BACKUP_ROOT="$TEST_ROOT/backups"
    mkdir -p "$HOME"
    INSTALL_ARGS=(--yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear)
}

teardown() {
    rm -rf "$TEST_ROOT"
}

install_dotfiles() {
    HOME="$HOME" DOTFILES_BACKUP_ROOT="$DOTFILES_BACKUP_ROOT" \
        "$DOTFILES_DIR/install.sh" "${INSTALL_ARGS[@]}" "$@"
}

latest_id() {
    tr -d '\n' <"$DOTFILES_BACKUP_ROOT/latest"
}

write_metadata() {
    local id="$1"
    local state="$2"
    local version="${3:-1}"
    mkdir -p "$DOTFILES_BACKUP_ROOT/$id/payload"
    cat >"$DOTFILES_BACKUP_ROOT/$id/metadata" <<EOF
version=$version
id=$id
created_at=2026-09-10T12:00:00Z
repo_revision=fixture
state=$state
EOF
    : >"$DOTFILES_BACKUP_ROOT/$id/entries"
}

@test "plan mode and an already-correct install create no transaction" {
    echo original >"$HOME/.gitconfig"
    run install_dotfiles --plan
    [ "$status" -eq 0 ]
    [ ! -e "$DOTFILES_BACKUP_ROOT" ]
    [ "$(cat "$HOME/.gitconfig")" = original ]

    run install_dotfiles
    [ "$status" -eq 0 ]
    first_id="$(latest_id)"
    first_count="$(find "$DOTFILES_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"

    run install_dotfiles
    [ "$status" -eq 0 ]
    [ "$(latest_id)" = "$first_id" ]
    second_count="$(find "$DOTFILES_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
    [ "$second_count" = "$first_count" ]
}

@test "install journals files directories raw symlinks and absent targets" {
    mkdir -p "$HOME/.config/yazi/nested"
    echo directory-content >"$HOME/.config/yazi/nested/value"
    echo file-content >"$HOME/.gitconfig"
    ln -s previous-zsh "$HOME/.zshrc"
    ln -s "$TEST_ROOT/absolute-target" "$HOME/.bashrc"

    run install_dotfiles
    [ "$status" -eq 0 ]
    id="$(latest_id)"
    metadata="$DOTFILES_BACKUP_ROOT/$id/metadata"
    entries="$DOTFILES_BACKUP_ROOT/$id/entries"
    grep -q '^version=1$' "$metadata"
    grep -q '^state=complete$' "$metadata"
    grep -q '|.config/yazi|directory|payload/' "$entries"
    grep -q '|.gitconfig|file|payload/' "$entries"
    grep -q '|.zshrc|symlink|previous-zsh|.zshrc$' "$entries"
    grep -Fq "|.bashrc|symlink|$TEST_ROOT/absolute-target|.bashrc" "$entries"
    grep -q '|.tmux.conf|absent||.tmux.conf$' "$entries"

    run "$DOTFILES_DIR/bin/restore" --apply "$id" --yes
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.gitconfig")" = file-content ]
    [ "$(cat "$HOME/.config/yazi/nested/value")" = directory-content ]
    [ "$(readlink "$HOME/.zshrc")" = previous-zsh ]
    [ "$(readlink "$HOME/.bashrc")" = "$TEST_ROOT/absolute-target" ]
    [ ! -e "$HOME/.tmux.conf" ]
    grep -q '^state=restored$' "$metadata"
}

@test "latest accepts only a validated transaction ID and regular file" {
    run install_dotfiles
    [ "$status" -eq 0 ]
    id="$(latest_id)"

    printf '../escape\n' >"$DOTFILES_BACKUP_ROOT/latest"
    run "$DOTFILES_DIR/bin/restore" --plan latest
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid transaction ID"* ]]

    printf '%s\n\n' "$id" >"$DOTFILES_BACKUP_ROOT/latest"
    run "$DOTFILES_DIR/bin/restore" --plan latest
    [ "$status" -ne 0 ]
    [[ "$output" == *"exactly one complete ID"* ]]

    rm "$DOTFILES_BACKUP_ROOT/latest"
    ln -s "$id" "$DOTFILES_BACKUP_ROOT/latest"
    run "$DOTFILES_DIR/bin/restore" --plan latest
    [ "$status" -ne 0 ]
    [[ "$output" == *"latest transaction is not available"* ]]
}

@test "list reports safe metadata without payload or symlink contents" {
    id=20260910T120000-111-222
    write_metadata "$id" complete
    echo 'TOP SECRET PAYLOAD' >"$DOTFILES_BACKUP_ROOT/$id/payload/0001"
    cat >"$DOTFILES_BACKUP_ROOT/$id/entries" <<'EOF'
0001|.gitconfig|file|payload/0001|.gitconfig
0002|.zshrc|symlink|SECRET-SYMLINK-TARGET|.zshrc
EOF

    run "$DOTFILES_DIR/bin/restore" --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"$id"* ]]
    [[ "$output" == *"complete"* ]]
    [[ "$output" != *"TOP SECRET"* ]]
    [[ "$output" != *"SECRET-SYMLINK"* ]]
}

@test "plan is byte-for-byte non-mutating" {
    echo original >"$HOME/.gitconfig"
    run install_dotfiles
    [ "$status" -eq 0 ]
    id="$(latest_id)"
    metadata="$DOTFILES_BACKUP_ROOT/$id/metadata"
    entries="$DOTFILES_BACKUP_ROOT/$id/entries"
    before_metadata="$(cksum "$metadata")"
    before_entries="$(cksum "$entries")"
    before_link="$(readlink "$HOME/.gitconfig")"

    run "$DOTFILES_DIR/bin/restore" --plan "$id"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESTORE .gitconfig (file)"* ]]
    [ "$(cksum "$metadata")" = "$before_metadata" ]
    [ "$(cksum "$entries")" = "$before_entries" ]
    [ "$(readlink "$HOME/.gitconfig")" = "$before_link" ]
}

@test "a conflict aborts the entire apply before changing any target" {
    echo original-git >"$HOME/.gitconfig"
    echo original-zsh >"$HOME/.zshrc"
    run install_dotfiles
    [ "$status" -eq 0 ]
    id="$(latest_id)"
    expected_zsh="$(readlink "$HOME/.zshrc")"
    rm "$HOME/.gitconfig"
    echo user-change >"$HOME/.gitconfig"

    run "$DOTFILES_DIR/bin/restore" --apply "$id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"conflict at .gitconfig"* ]]
    [[ "$output" == *"no targets changed"* ]]
    [ "$(cat "$HOME/.gitconfig")" = user-change ]
    [ "$(readlink "$HOME/.zshrc")" = "$expected_zsh" ]
    grep -q '^state=complete$' "$DOTFILES_BACKUP_ROOT/$id/metadata"
}

@test "malformed metadata IDs and journal fields are rejected" {
    bad_version=20260910T120001-111-222
    write_metadata "$bad_version" complete 2
    run "$DOTFILES_DIR/bin/restore" --plan "$bad_version"
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsupported transaction version"* ]]

    traversal=20260910T120002-111-222
    write_metadata "$traversal" complete
    echo '0001|../outside|absent||.zshrc' >"$DOTFILES_BACKUP_ROOT/$traversal/entries"
    run "$DOTFILES_DIR/bin/restore" --plan "$traversal"
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid journal record"* ]]

    pipe_field=20260910T120003-111-222
    write_metadata "$pipe_field" complete
    echo '0001|.zshrc|symlink|bad|pipe|.zshrc' >"$DOTFILES_BACKUP_ROOT/$pipe_field/entries"
    run "$DOTFILES_DIR/bin/restore" --plan "$pipe_field"
    [ "$status" -ne 0 ]
    [[ "$output" == *"malformed journal record"* ]]

    newline=20260910T120004-111-222
    write_metadata "$newline" complete
    printf 'created_at=bad\nline=value\n' >>"$DOTFILES_BACKUP_ROOT/$newline/metadata"
    run "$DOTFILES_DIR/bin/restore" --plan "$newline"
    [ "$status" -ne 0 ]

    run "$DOTFILES_DIR/bin/restore" --plan '../../escape'
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid transaction ID"* ]]
}

@test "a failed partial transaction previews and restores recognized state" {
    id=20260910T120005-111-222
    write_metadata "$id" failed
    echo '0001|.zshrc|symlink|previous-zsh|.zshrc' >"$DOTFILES_BACKUP_ROOT/$id/entries"

    run "$DOTFILES_DIR/bin/restore" --plan "$id"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESTORE .zshrc (symlink)"* ]]

    run "$DOTFILES_DIR/bin/restore" --apply "$id" --yes
    [ "$status" -eq 0 ]
    [ -L "$HOME/.zshrc" ]
    [ "$(readlink "$HOME/.zshrc")" = previous-zsh ]
    grep -q '^state=restored$' "$DOTFILES_BACKUP_ROOT/$id/metadata"
}

@test "a second apply refuses an already-restored transaction" {
    run install_dotfiles
    [ "$status" -eq 0 ]
    id="$(latest_id)"
    run "$DOTFILES_DIR/bin/restore" --apply "$id" --yes
    [ "$status" -eq 0 ]
    before="$(cksum "$DOTFILES_BACKUP_ROOT/$id/metadata")"

    run "$DOTFILES_DIR/bin/restore" --apply "$id" --yes
    [ "$status" -ne 0 ]
    [[ "$output" == *"already been restored"* ]]
    [ "$(cksum "$DOTFILES_BACKUP_ROOT/$id/metadata")" = "$before" ]
}

@test "an unsupported FIFO target stops before transaction or target mutation" {
    mkdir -p "$HOME/.config"
    mkfifo "$HOME/.config/yazi"

    run install_dotfiles
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unsupported filesystem object at target: $HOME/.config/yazi"* ]]
    [ -p "$HOME/.config/yazi" ]
    [ ! -e "$DOTFILES_BACKUP_ROOT" ]
}

@test "an install failure after journaling marks the transaction failed" {
    mkdir -p "$HOME/.config"
    ln -s '../unsupported-parent-link' "$HOME/.config/ghostty"

    run install_dotfiles
    [ "$status" -ne 0 ]
    [ -L "$HOME/.config/ghostty" ]
    [ "$(readlink "$HOME/.config/ghostty")" = '../unsupported-parent-link' ]
    [ ! -e "$DOTFILES_BACKUP_ROOT/latest" ]
    id="$(basename "$(find "$DOTFILES_BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d)")"
    grep -q '^state=failed$' "$DOTFILES_BACKUP_ROOT/$id/metadata"
    grep -q '|.config/yazi|absent||yazi$' "$DOTFILES_BACKUP_ROOT/$id/entries"
}

@test "restore CLI help and usage errors follow the public contract" {
    run "$DOTFILES_DIR/bin/restore"
    [ "$status" -eq 0 ]
    [[ "$output" == *"dot restore --list"* ]]

    run "$DOTFILES_DIR/bin/restore" --unknown
    [ "$status" -eq 64 ]

    run "$DOTFILES_DIR/bin/restore" --plan --yes
    [ "$status" -eq 64 ]

    run "$DOTFILES_DIR/bin/restore" --apply one two
    [ "$status" -eq 64 ]
}
