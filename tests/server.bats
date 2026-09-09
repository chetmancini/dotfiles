#!/usr/bin/env bats
# tests/server.bats — safe bind defaults for the local HTTP server

setup() {
    load helpers.bash
    setup_temp_home
    FAKE_BIN="$TMP_HOME/bin"
    SERVER_ARGS_FILE="$TMP_HOME/server-args"
    mkdir -p "$FAKE_BIN"
    export SERVER_ARGS_FILE

    printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"$FAKE_BIN/lsof"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'printf "%s\n" "$@" >"$SERVER_ARGS_FILE"' >"$FAKE_BIN/python3"
    chmod +x "$FAKE_BIN/lsof" "$FAKE_BIN/python3"
}

teardown() {
    teardown_temp_home
}

@test "server binds to loopback by default" {
    run env PATH="$FAKE_BIN:/usr/bin:/bin" SERVER_ARGS_FILE="$SERVER_ARGS_FILE" \
        "$DOTFILES_DIR/bin/server" --no-browser 8123

    [ "$status" -eq 0 ]
    run grep -Fx -- '--bind' "$SERVER_ARGS_FILE"
    [ "$status" -eq 0 ]
    run grep -Fx -- '127.0.0.1' "$SERVER_ARGS_FILE"
    [ "$status" -eq 0 ]
}

@test "server requires an explicit bind option for network sharing" {
    run env PATH="$FAKE_BIN:/usr/bin:/bin" SERVER_ARGS_FILE="$SERVER_ARGS_FILE" \
        "$DOTFILES_DIR/bin/server" --no-browser --bind 0.0.0.0 8123

    [ "$status" -eq 0 ]
    run grep -Fx -- '0.0.0.0' "$SERVER_ARGS_FILE"
    [ "$status" -eq 0 ]
}
