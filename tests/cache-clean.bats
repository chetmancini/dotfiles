#!/usr/bin/env bats
# tests/cache-clean.bats — dry-run-first package cache cleanup

setup() {
    load helpers.bash
    FAKE_BIN="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-cache-clean-bin.XXXXXX")"
    TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-cache-clean-home.XXXXXX")"
    CLEAN_LOG="$TMP_HOME/clean.log"

    mkdir -p "$TMP_HOME/.cache/uv"
    printf 'cached\n' >"$TMP_HOME/.cache/uv/archive"

    cat >"$FAKE_BIN/uv" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "cache" ] && [ "$2" = "dir" ]; then
    echo "$TEST_HOME/.cache/uv"
    exit 0
fi
printf '%s\n' "$*" >>"$CACHE_CLEAN_TEST_LOG"
exit 0
EOF
    chmod +x "$FAKE_BIN/uv"
}

teardown() {
    rm -rf "$FAKE_BIN" "$TMP_HOME"
}

run_cache_clean() {
    run env \
        HOME="$TMP_HOME" \
        TEST_HOME="$TMP_HOME" \
        CACHE_CLEAN_TEST_LOG="$CLEAN_LOG" \
        PATH="$FAKE_BIN:/usr/bin:/bin" \
        "$DOTFILES_DIR/bin/cache-clean" "$@"
}

@test "cache-clean previews without executing" {
    run_cache_clean --only uv --no-size
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cache cleanup (preview)"* ]]
    [[ "$output" == *"command: uv cache prune"* ]]
    [[ "$output" == *"Preview only"* ]]
    [ ! -e "$CLEAN_LOG" ]
}

@test "cache-clean requires yes for non-interactive apply" {
    run_cache_clean --only uv --apply --no-size
    [ "$status" -ne 0 ]
    [[ "$output" == *"refusing non-interactive cleanup without --yes"* ]]
    [ ! -e "$CLEAN_LOG" ]
}

@test "cache-clean apply runs the conservative command" {
    run_cache_clean --only uv --apply --yes --no-size
    [ "$status" -eq 0 ]
    [[ "$output" == *"[done] uv"* ]]
    [ "$(cat "$CLEAN_LOG")" = "cache prune" ]
}

@test "cache-clean aggressive mode clears the UV cache" {
    run_cache_clean --only uv --apply --yes --aggressive --no-size
    [ "$status" -eq 0 ]
    [ "$(cat "$CLEAN_LOG")" = "cache clean" ]
}

@test "cache-clean rejects unknown cleaners" {
    run_cache_clean --only mystery
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown cleaner: mystery"* ]]
}
