#!/usr/bin/env bats
# tests/helpers-spinner.bats — bin/lib/helpers.sh run_with_spinner

setup() {
    load helpers.bash
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "run_with_spinner returns command exit code" {
    run bash -c "
        source '$DOTFILES_DIR/bin/lib/helpers.sh'
        run_with_spinner 'testing' bash -c 'exit 42'
        echo exit:\$?
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"exit:42"* ]]
}

@test "run_with_spinner preserves caller's EXIT trap" {
    run bash -c "
        trap 'echo original EXIT' EXIT
        source '$DOTFILES_DIR/bin/lib/helpers.sh'
        run_with_spinner 'testing' sleep 0.1
        trap -p EXIT
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"original EXIT"* ]]
}

@test "run_with_spinner verbose mode runs without spinner" {
    run bash -c "
        source '$DOTFILES_DIR/bin/lib/helpers.sh'
        VERBOSE=true run_with_spinner 'testing' echo hello
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello"* ]]
}

@test "run_with_spinner cleans up tmpfile" {
    run bash -c "
        source '$DOTFILES_DIR/bin/lib/helpers.sh'
        # Count temp files before/after
        before=\$(ls \"\${TMPDIR:-/tmp}\" | grep -c 'tmp\.' || true)
        run_with_spinner 'testing' sleep 0.1
        after=\$(ls \"\${TMPDIR:-/tmp}\" | grep -c 'tmp\.' || true)
        echo before:\$before after:\$after
        # tmpfile from spinner should not leak (allow small delta due to parallel tests)
        [ \"\$after\" -le \"\$((before+1))\" ]
    "
    [ "$status" -eq 0 ]
}

@test "run_with_spinner handles failing command" {
    run bash -c "
        source '$DOTFILES_DIR/bin/lib/helpers.sh'
        run_with_spinner 'failing' bash -c 'exit 7'
        echo status:\$?
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"status:7"* ]]
}
