#!/usr/bin/env bats
# tests/git-rm-gone.bats — bin/git-rm-gone cleanup of gone-upstream branches

setup() {
    load helpers.bash
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/git-rm-gone.XXXXXX")"
    ORIGIN="$TEST_ROOT/origin.git"
    REPO="$TEST_ROOT/repo"

    git init -q --bare "$ORIGIN"
    git init -q -b main "$REPO"
    git -C "$REPO" config user.email tests@example.com
    git -C "$REPO" config user.name tests
    git -C "$REPO" commit -q --allow-empty -m init
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q origin main
}

teardown() {
    rm -rf "$TEST_ROOT"
}

# Push $1, delete it on the remote, prune locally: upstream is now gone.
make_gone_branch() {
    git -C "$REPO" checkout -q -b "$1"
    git -C "$REPO" commit -q --allow-empty -m "$1"
    git -C "$REPO" push -q -u origin "$1"
    git -C "$REPO" checkout -q main
    git -C "$REPO" push -q origin --delete "$1"
    git -C "$REPO" fetch -q --prune
}

# Run the script inside the fixture repo (never the dotfiles checkout).
gone_cleanup() {
    (cd "$REPO" && "$DOTFILES_DIR/bin/git-rm-gone" "$@")
}

branch_exists() {
    git -C "$REPO" show-ref --verify --quiet "refs/heads/$1"
}

@test "git-rm-gone deletes branches with gone upstreams" {
    make_gone_branch feature

    run gone_cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted 1 branch(es):"* ]]
    ! branch_exists feature
}

@test "git-rm-gone leaves branches without an upstream alone" {
    git -C "$REPO" checkout -q -b local-only
    git -C "$REPO" checkout -q main

    run gone_cleanup
    [ "$status" -eq 0 ]
    [[ "$output" == *"No branches with gone upstreams found."* ]]
    branch_exists local-only
}

@test "git-rm-gone reports worktree-blocked branches and still removes the rest" {
    make_gone_branch blocked
    make_gone_branch free
    git -C "$REPO" worktree add -q "$TEST_ROOT/wt" blocked

    run gone_cleanup
    [ "$status" -eq 1 ]
    [[ "$output" == *"Deleted 1 branch(es):"* ]]
    [[ "$output" == *"Could not remove 1 branch(es):"* ]]
    [[ "$output" == *"blocked"* ]]
    [[ "$output" == *"$TEST_ROOT/wt"* ]]
    ! branch_exists free
    branch_exists blocked
}

@test "git-rm-gone --dry-run deletes nothing" {
    make_gone_branch feature
    make_gone_branch blocked
    git -C "$REPO" worktree add -q "$TEST_ROOT/wt" blocked

    run gone_cleanup --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would delete 1 branch(es):"* ]]
    [[ "$output" == *"blocked (checked out in worktree $TEST_ROOT/wt)"* ]]
    branch_exists feature
    branch_exists blocked
    [ -d "$TEST_ROOT/wt" ]
}

@test "git-rm-gone --remove-worktrees clears a clean blocking worktree" {
    make_gone_branch feature
    git -C "$REPO" worktree add -q "$TEST_ROOT/wt" feature

    run gone_cleanup --remove-worktrees
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed 1 clean worktree(s):"* ]]
    [ ! -d "$TEST_ROOT/wt" ]
    ! branch_exists feature
}

@test "git-rm-gone --remove-worktrees never removes a dirty worktree" {
    make_gone_branch feature
    git -C "$REPO" worktree add -q "$TEST_ROOT/wt" feature
    echo dirty >"$TEST_ROOT/wt/untracked.txt"

    run gone_cleanup --remove-worktrees
    [ "$status" -eq 1 ]
    [[ "$output" == *"uncommitted or untracked changes"* ]]
    [ -d "$TEST_ROOT/wt" ]
    branch_exists feature
}

@test "git-rm-gone refuses to run outside a git repository" {
    mkdir -p "$TEST_ROOT/nowhere"

    run env GIT_CEILING_DIRECTORIES="$TEST_ROOT" GIT_DIR= GIT_WORK_TREE= \
        bash -c "cd '$TEST_ROOT/nowhere' && '$DOTFILES_DIR/bin/git-rm-gone'"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Not inside a git repository."* ]]
}

@test "git-rm-gone rejects unknown options" {
    run gone_cleanup --nope
    [ "$status" -eq 64 ]
    [[ "$output" == *"Unknown option: --nope"* ]]
}
