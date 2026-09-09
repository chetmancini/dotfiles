#!/usr/bin/env bats
# tests/install-hooks.bats — hook installation across Git checkout layouts

setup() {
    load helpers.bash
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
    TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-hooks.XXXXXX")"
    REPO="$TEST_ROOT/repo"
    WORKTREE="$TEST_ROOT/worktree"
    mkdir -p "$REPO/scripts"
    cp "$DOTFILES_DIR/scripts/install-hooks.sh" "$DOTFILES_DIR/scripts/pre-commit" "$REPO/scripts/"
    git -C "$REPO" init -q -b main
    git -C "$REPO" config user.name "Bats Test"
    git -C "$REPO" config user.email "test@example.com"
    git -C "$REPO" add scripts
    git -C "$REPO" commit -q -m "fixtures"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "install-hooks resolves the shared hook directory from a linked worktree" {
    git -C "$REPO" worktree add -q -b test-worktree "$WORKTREE"

    run "$WORKTREE/scripts/install-hooks.sh"

    [ "$status" -eq 0 ]
    hooks_dir="$(git -C "$WORKTREE" rev-parse --git-path hooks)"
    if [[ "$hooks_dir" != /* ]]; then
        hooks_dir="$WORKTREE/$hooks_dir"
    fi
    [ -L "$hooks_dir/pre-commit" ]
    [ "$(readlink "$hooks_dir/pre-commit")" = "$WORKTREE/scripts/pre-commit" ]
}
