#!/usr/bin/env bats
# tests/status.bats — bin/status aggregator and JSON contract

setup() {
    load helpers.bash
    setup_temp_home

    FAKE_BIN="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-status-fakebin.XXXXXX")"
    FAKE_BREWFILE="$(mktemp "${TMPDIR:-/tmp}/dotfiles-status-brewfile.XXXXXX")"
    cat <<EOF >"$FAKE_BREWFILE"
brew "ripgrep"
cask "alacritty"
EOF
}

teardown() {
    if [[ -n "${FAKE_BIN:-}" && -d "$FAKE_BIN" ]]; then
        rm -rf "$FAKE_BIN"
    fi
    if [[ -n "${FAKE_BREWFILE:-}" && -f "$FAKE_BREWFILE" ]]; then
        rm -f "$FAKE_BREWFILE"
    fi
    teardown_temp_home
}

create_fake_doctor() {
    local exit_code="${1:-0}"
    cat <<EOF >"$FAKE_BIN/fake-doctor"
#!/bin/sh
exit $exit_code
EOF
    chmod +x "$FAKE_BIN/fake-doctor"
    export STATUS_DOCTOR_BIN="$FAKE_BIN/fake-doctor"
}

create_fake_repo_report() {
    local exit_code="${1:-0}"
    cat <<EOF >"$FAKE_BIN/fake-repo-report"
#!/bin/sh
exit $exit_code
EOF
    chmod +x "$FAKE_BIN/fake-repo-report"
    export STATUS_REPO_REPORT_BIN="$FAKE_BIN/fake-repo-report"
}

@test "status --help prints usage and exits 0" {
    run "$DOTFILES_DIR/bin/status" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: status"* ]]
    [[ "$output" == *"--deep"* ]]
    [[ "$output" == *"--json"* ]]
}

@test "status rejects unknown options with exit 64" {
    run "$DOTFILES_DIR/bin/status" --unknown-flag
    [ "$status" -eq 64 ]
    [[ "$output" == *"unknown option"* ]]
}

@test "status fast mode healthy result and component order" {
    create_fake_doctor 0
    create_fake_repo_report 0
    mkdir -p "$TMP_HOME/code"

    run "$DOTFILES_DIR/bin/status" --json
    [ "$status" -eq 0 ]

    python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["schema"] == "dotfiles.status/v1"
assert data["overall_status"] == "ok"
assert data["deep"] is False
assert len(data["components"]) == 2
assert data["components"][0]["id"] == "doctor"
assert data["components"][0]["status"] == "ok"
assert data["components"][1]["id"] == "repositories"
assert data["components"][1]["status"] == "ok"
' "$output"
}

@test "status doctor failure maps to error and exit 2" {
    create_fake_doctor 1
    create_fake_repo_report 0
    mkdir -p "$TMP_HOME/code"

    run "$DOTFILES_DIR/bin/status" --json
    [ "$status" -eq 2 ]

    python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["overall_status"] == "error"
assert data["components"][0]["id"] == "doctor"
assert data["components"][0]["status"] == "error"
assert data["components"][0]["exit_code"] == 1
' "$output"
}

@test "status dirty repositories maps to warning and exit 1" {
    create_fake_doctor 0
    create_fake_repo_report 1
    mkdir -p "$TMP_HOME/code"

    run "$DOTFILES_DIR/bin/status" --json
    [ "$status" -eq 1 ]

    python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["overall_status"] == "warning"
assert data["components"][1]["id"] == "repositories"
assert data["components"][1]["status"] == "warning"
assert data["components"][1]["exit_code"] == 1
' "$output"
}

@test "status missing repo roots skips repositories without error" {
    create_fake_doctor 0
    # Neither ~/code nor ~/norm exists in TMP_HOME

    run "$DOTFILES_DIR/bin/status" --json
    [ "$status" -eq 0 ]

    python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["overall_status"] == "ok"
assert data["components"][1]["id"] == "repositories"
assert data["components"][1]["status"] == "skipped"
assert data["components"][1]["exit_code"] == 0
' "$output"
}

@test "status --deep skips homebrew when brew is absent" {
    create_fake_doctor 0
    create_fake_repo_report 0
    mkdir -p "$TMP_HOME/code"

    # Minimal PATH without brew
    run env PATH="/usr/bin:/bin" "$DOTFILES_DIR/bin/status" --deep --json
    [ "$status" -eq 0 ]

    python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["overall_status"] == "ok"
assert data["deep"] is True
assert len(data["components"]) == 3
assert data["components"][2]["id"] == "homebrew"
assert data["components"][2]["status"] == "skipped"
' "$output"
}

@test "status --deep handles fake brew healthy drift and error mappings" {
    create_fake_doctor 0
    create_fake_repo_report 0
    mkdir -p "$TMP_HOME/code"

    # 1. Healthy: fake brew-sync returns 0
    cat <<EOF >"$FAKE_BIN/fake-brew-sync-0"
#!/bin/sh
exit 0
EOF
    chmod +x "$FAKE_BIN/fake-brew-sync-0"

    # Fake brew command on PATH so brew is detected
    cat <<EOF >"$FAKE_BIN/brew"
#!/bin/sh
exit 0
EOF
    chmod +x "$FAKE_BIN/brew"

    STATUS_BREW_SYNC_BIN="$FAKE_BIN/fake-brew-sync-0" run env PATH="$FAKE_BIN:$PATH" "$DOTFILES_DIR/bin/status" --deep --json
    [ "$status" -eq 0 ]
    python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["overall_status"] == "ok"
assert data["components"][2]["id"] == "homebrew"
assert data["components"][2]["status"] == "ok"
' "$output"

    # 2. Drift: fake brew-sync returns 1
    cat <<EOF >"$FAKE_BIN/fake-brew-sync-1"
#!/bin/sh
exit 1
EOF
    chmod +x "$FAKE_BIN/fake-brew-sync-1"

    STATUS_BREW_SYNC_BIN="$FAKE_BIN/fake-brew-sync-1" run env PATH="$FAKE_BIN:$PATH" "$DOTFILES_DIR/bin/status" --deep --json
    [ "$status" -eq 1 ]
    python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["overall_status"] == "warning"
assert data["components"][2]["id"] == "homebrew"
assert data["components"][2]["status"] == "warning"
' "$output"

    # 3. Error: fake brew-sync returns 2
    cat <<EOF >"$FAKE_BIN/fake-brew-sync-2"
#!/bin/sh
exit 2
EOF
    chmod +x "$FAKE_BIN/fake-brew-sync-2"

    STATUS_BREW_SYNC_BIN="$FAKE_BIN/fake-brew-sync-2" run env PATH="$FAKE_BIN:$PATH" "$DOTFILES_DIR/bin/status" --deep --json
    [ "$status" -eq 2 ]
    python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["overall_status"] == "error"
assert data["components"][2]["id"] == "homebrew"
assert data["components"][2]["status"] == "error"
' "$output"
}

@test "status fast mode never invokes brew or validate-api-keys" {
    create_fake_doctor 0
    create_fake_repo_report 0
    mkdir -p "$TMP_HOME/code"

    sentry_file="$TMP_HOME/sentry_invoked"

    # Place tripwire scripts in front of PATH
    cat <<EOF >"$FAKE_BIN/brew"
#!/bin/sh
touch "$sentry_file"
echo "ERROR: brew should not be called" >&2
exit 99
EOF
    chmod +x "$FAKE_BIN/brew"

    cat <<EOF >"$FAKE_BIN/validate-api-keys"
#!/bin/sh
touch "$sentry_file"
echo "ERROR: validate-api-keys should not be called" >&2
exit 99
EOF
    chmod +x "$FAKE_BIN/validate-api-keys"

    run env PATH="$FAKE_BIN:$PATH" "$DOTFILES_DIR/bin/status"
    [ "$status" -eq 0 ]
    [ ! -f "$sentry_file" ]

    run env PATH="$FAKE_BIN:$PATH" "$DOTFILES_DIR/bin/status" --json
    [ "$status" -eq 0 ]
    [ ! -f "$sentry_file" ]
}

@test "status json output is clean on stdout with valid schema" {
    create_fake_doctor 0
    create_fake_repo_report 0
    mkdir -p "$TMP_HOME/code"

    run "$DOTFILES_DIR/bin/status" --json
    [ "$status" -eq 0 ]

    # Verify stdout parses cleanly as JSON and contains required schema keys
    python3 -c '
import json, sys
data = json.loads(sys.argv[1])
assert data["schema"] == "dotfiles.status/v1"
assert "overall_status" in data
assert "deep" in data
assert isinstance(data["components"], list)
for comp in data["components"]:
    assert "id" in comp
    assert "status" in comp
    assert "exit_code" in comp
    assert "summary" in comp
    assert "remediation" in comp
' "$output"
}
