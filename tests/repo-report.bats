#!/usr/bin/env bats
# tests/repo-report.bats — repo-report health check and exit code semantics

setup() {
    load helpers.bash
    setup_temp_home

    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES

    TEST_REPOS_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-repos.XXXXXX")"
    export GIT_AUTHOR_NAME="Bats Test"
    export GIT_AUTHOR_EMAIL="test@example.com"
    export GIT_COMMITTER_NAME="Bats Test"
    export GIT_COMMITTER_EMAIL="test@example.com"
}

teardown() {
    if [[ -n "${TEST_REPOS_DIR:-}" && -d "$TEST_REPOS_DIR" ]]; then
        rm -rf "$TEST_REPOS_DIR"
    fi
    teardown_temp_home
}

create_clean_repo() {
    local name="$1"
    local repo_dir="$TEST_REPOS_DIR/$name"
    mkdir -p "$repo_dir"
    git -C "$repo_dir" init -q -b main
    echo "hello" >"$repo_dir/file.txt"
    git -C "$repo_dir" add file.txt
    git -C "$repo_dir" commit -q -m "initial commit"
}

create_dirty_repo() {
    local name="$1"
    local repo_dir="$TEST_REPOS_DIR/$name"
    create_clean_repo "$name"
    echo "uncommitted changes" >>"$repo_dir/file.txt"
}

@test "repo-report --help prints usage and --check option" {
    run "$DOTFILES_DIR/bin/repo-report" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: repo-report"* ]]
    [[ "$output" == *"--check"* ]]
    [[ "$output" == *"Exit codes (with --check):"* ]]
}

@test "repo-report without --check exits 0 even when repos are dirty (legacy)" {
    create_dirty_repo "dirty-project"
    run "$DOTFILES_DIR/bin/repo-report" "$TEST_REPOS_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dirty: 1"* ]]
}

@test "repo-report --check exits 0 when all repos are clean" {
    create_clean_repo "clean-project"
    run "$DOTFILES_DIR/bin/repo-report" --check "$TEST_REPOS_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Clean: 1"* ]]
    [[ "$output" == *"Dirty: 0"* ]]
}

@test "repo-report --check exits 1 when repos have issues" {
    create_clean_repo "clean-project"
    create_dirty_repo "dirty-project"
    run "$DOTFILES_DIR/bin/repo-report" --check "$TEST_REPOS_DIR"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Clean: 1"* ]]
    [[ "$output" == *"Dirty: 1"* ]]
}

@test "repo-report --check exits 2 when directory does not exist" {
    run "$DOTFILES_DIR/bin/repo-report" --check "$TEST_REPOS_DIR/nonexistent"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Directory not found"* ]]
}

@test "repo-report --check exits 2 when no scan directories exist" {
    run env HOME="$TMP_HOME" "$DOTFILES_DIR/bin/repo-report" --check
    [ "$status" -eq 2 ]
    [[ "$output" == *"No directories to scan"* ]]
}

@test "repo-report without --check exits 1 when no scan directories exist" {
    run env HOME="$TMP_HOME" "$DOTFILES_DIR/bin/repo-report"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No directories to scan"* ]]
}
