#!/usr/bin/env bats
# tests/git-rm-gone.bats — preview-first behavior and unmerged preservation

setup() {
    load helpers.bash
    setup_temp_home

    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES

    export GIT_AUTHOR_NAME="Bats Test"
    export GIT_AUTHOR_EMAIL="test@example.com"
    export GIT_COMMITTER_NAME="Bats Test"
    export GIT_COMMITTER_EMAIL="test@example.com"

    TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-rm-gone.XXXXXX")"
    ORIGIN="$TEST_TMP/origin.git"
    REPO="$TEST_TMP/repo"
    git init -q --bare "$ORIGIN"
    git init -q -b main "$REPO"
    echo "hello" >"$REPO/file.txt"
    git -C "$REPO" add file.txt
    git -C "$REPO" commit -q -m "initial commit"
    git -C "$REPO" remote add origin "$ORIGIN"
    git -C "$REPO" push -q -u origin main
}

teardown() {
    if [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]]; then
        rm -rf "$TEST_TMP"
    fi
    teardown_temp_home
}

# make_gone_branch <name> <merged:true|false>
# Creates a branch, pushes it with upstream, optionally merges it into main,
# then deletes the remote branch and prunes — leaving a ": gone]" branch.
make_gone_branch() {
    local name="$1"
    local merged="$2"

    git -C "$REPO" checkout -q -b "$name"
    echo "$name" >"$REPO/$name.txt"
    git -C "$REPO" add "$name.txt"
    git -C "$REPO" commit -q -m "$name work"
    git -C "$REPO" push -q -u origin "$name"
    git -C "$REPO" checkout -q main
    if [ "$merged" = true ]; then
        git -C "$REPO" merge -q --no-ff "$name" -m "merge $name"
    fi
    git -C "$REPO" push -q origin --delete "$name"
    git -C "$REPO" fetch -q --prune
}

branch_exists() {
    git -C "$REPO" show-ref --verify -q "refs/heads/$1"
}

# make_gone_worktree <name> <merged:true|false> [dirty:true|false] [live:true|false]
# Adds a worktree on a new branch, pushes it with upstream, optionally merges
# it into main, then (unless live) deletes the remote branch and prunes.
make_gone_worktree() {
    local name="$1"
    local merged="$2"
    local dirty="${3:-false}"
    local live="${4:-false}"
    local wt_path="$TEST_TMP/wt-$name"

    git -C "$REPO" worktree add "$wt_path" -b "$name" >/dev/null
    echo "$name" >"$wt_path/$name.txt"
    git -C "$wt_path" add "$name.txt"
    git -C "$wt_path" commit -qm "$name work"
    git -C "$wt_path" push -q -u origin "$name"
    git -C "$REPO" checkout -q main
    if [ "$merged" = true ]; then
        git -C "$REPO" merge -q --no-ff "$name" -m "merge $name"
    fi
    if [ "$live" != true ]; then
        git -C "$REPO" push -q origin --delete "$name"
        git -C "$REPO" fetch -q --prune
    fi
    if [ "$dirty" = true ]; then
        echo "uncommitted" >"$wt_path/dirty.txt"
    fi
    # Canonical path as registered with git (resolves symlinks like /tmp).
    LAST_WT="$(git -C "$REPO" worktree list --porcelain | awk '/^worktree / { path = substr($0, 10) } END { print path }')"
}

worktree_listed() {
    git -C "$REPO" worktree list --porcelain | grep -q "^worktree $1$"
}

@test "git-rm-gone --help prints usage and new options" {
    run "$DOTFILES_DIR/bin/git-rm-gone" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: git-rm-gone"* ]]
    [[ "$output" == *"--apply"* ]]
    [[ "$output" == *"--force"* ]]
}

@test "git-rm-gone reports no gone branches and exits 0" {
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No branches with gone upstreams found."* ]]
}

@test "git-rm-gone preview (default) deletes nothing" {
    make_gone_branch "feature-preview" true
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone"
    [ "$status" -eq 0 ]
    [[ "$output" == *"feature-preview"* ]]
    [[ "$output" == *"Preview only"* ]]
    branch_exists "feature-preview"
}

@test "git-rm-gone --apply --yes deletes a merged gone branch" {
    make_gone_branch "feature-merged" true
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"Done:"* ]]
    ! branch_exists "feature-merged"
}

@test "git-rm-gone --apply --yes preserves an unmerged gone branch" {
    make_gone_branch "feature-unmerged" false
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"UNMERGED"* ]]
    branch_exists "feature-unmerged"
}

@test "git-rm-gone --apply --force --yes deletes an unmerged gone branch" {
    make_gone_branch "feature-force" false
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --force --yes
    [ "$status" -eq 0 ]
    ! branch_exists "feature-force"
}

@test "git-rm-gone --apply --yes skips the current branch" {
    make_gone_branch "feature-current" true
    git -C "$REPO" checkout -q "feature-current"
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"current branch"* ]]
    branch_exists "feature-current"
}

@test "git-rm-gone --yes without --apply is a usage error" {
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --yes
    [ "$status" -eq 2 ]
}

@test "git-rm-gone --force without --apply is a usage error" {
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --force
    [ "$status" -eq 2 ]
}

@test "git-rm-gone preview lists dead worktree and removes nothing" {
    make_gone_worktree "wt-preview" true
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone"
    [ "$status" -eq 0 ]
    [[ "$output" == *"wt-preview"* ]]
    [[ "$output" == *"will remove"* ]]
    [[ "$output" == *"Preview only"* ]]
    [ -d "$TEST_TMP/wt-wt-preview" ]
    branch_exists "wt-preview"
}

@test "git-rm-gone --apply --yes removes merged worktree and deletes its branch" {
    make_gone_worktree "wt-dead" true
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"worktrees removed"* ]]
    [ ! -e "$TEST_TMP/wt-wt-dead" ]
    ! worktree_listed "$LAST_WT"
    ! branch_exists "wt-dead"
}

@test "git-rm-gone --apply --yes preserves an unmerged worktree" {
    make_gone_worktree "wt-unmerged" false
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"UNMERGED"* ]]
    [ -d "$TEST_TMP/wt-wt-unmerged" ]
    branch_exists "wt-unmerged"
}

@test "git-rm-gone --apply --force --yes removes an unmerged worktree" {
    make_gone_worktree "wt-force" false
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --force --yes
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_TMP/wt-wt-force" ]
    ! branch_exists "wt-force"
}

@test "git-rm-gone --apply --yes preserves a dirty worktree even when merged" {
    make_gone_worktree "wt-dirty" true true
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"uncommitted changes"* ]]
    [ -d "$TEST_TMP/wt-wt-dirty" ]
    branch_exists "wt-dirty"
}

@test "git-rm-gone --apply --yes skips a worktree whose upstream is present" {
    make_gone_worktree "wt-live" true false true
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"upstream present"* ]]
    [ -d "$TEST_TMP/wt-wt-live" ]
    branch_exists "wt-live"
}

@test "git-rm-gone --apply --yes skips the worktree you run from" {
    make_gone_worktree "wt-here" true
    cd "$TEST_TMP/wt-wt-here"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"current worktree"* ]]
    [ -d "$TEST_TMP/wt-wt-here" ]
    branch_exists "wt-here"
}

@test "git-rm-gone --apply --yes preserves a worktree with only ignored files" {
    git -C "$REPO" worktree add "$TEST_TMP/wt-wt-ignored" -b wt-ignored >/dev/null
    printf 'local-secret.txt\n' >"$TEST_TMP/wt-wt-ignored/.gitignore"
    echo "data" >"$TEST_TMP/wt-wt-ignored/tracked.txt"
    git -C "$TEST_TMP/wt-wt-ignored" add .gitignore tracked.txt
    git -C "$TEST_TMP/wt-wt-ignored" commit -qm "wt-ignored work"
    git -C "$TEST_TMP/wt-wt-ignored" push -q -u origin wt-ignored
    git -C "$REPO" checkout -q main
    git -C "$REPO" merge -q --no-ff wt-ignored -m "merge wt-ignored"
    git -C "$REPO" push -q origin --delete wt-ignored
    git -C "$REPO" fetch -q --prune
    echo "sekret" >"$TEST_TMP/wt-wt-ignored/local-secret.txt"
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"uncommitted changes"* ]]
    [ -f "$TEST_TMP/wt-wt-ignored/local-secret.txt" ]
    branch_exists "wt-ignored"
}

@test "git-rm-gone --apply --force still preserves a dirty worktree" {
    make_gone_worktree "wt-dirty-force" false true
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --force --yes
    [ "$status" -eq 0 ]
    [ -d "$TEST_TMP/wt-wt-dirty-force" ]
    branch_exists "wt-dirty-force"
}

@test "git-rm-gone --apply --yes prunes stale worktree entries" {
    make_gone_worktree "wt-stale" true
    rm -rf "$TEST_TMP/wt-wt-stale"
    cd "$REPO"
    run "$DOTFILES_DIR/bin/git-rm-gone" --apply --yes
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale"* ]]
    ! worktree_listed "$LAST_WT"
}

@test "git-rm-gone fails cleanly when run outside a git repository" {
    local non_repo="$TEST_TMP/non-repo"
    mkdir -p "$non_repo"
    cd "$non_repo"
    run "$DOTFILES_DIR/bin/git-rm-gone"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not inside a git repository"* ]]
}
