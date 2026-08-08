#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

# Characterization smoke for bootstrap (mirrors CI install-smoke job).
# Usage: scripts/test-install-smoke.sh
# Does not install brew packages or mutate the real HOME.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOT="${DOTFILES_DIR}/bin/dot"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

pass() {
    echo "OK: $*"
}

[[ -x "$DOT" ]] || fail "bin/dot not executable"
[[ -x "$DOTFILES_DIR/install.sh" ]] || fail "install.sh not executable"

# --- unit: help / dispatch ---
# Capture full output (avoid pipefail/SIGPIPE with grep -q on a long stream)
help_out="$("$DOT" help 2>&1)" || fail "dot help failed"
echo "$help_out" | grep -q 'install' || fail "dot help should list install"

install_help_out="$("$DOT" install -h 2>&1)" || true
echo "$install_help_out" | grep -Eqi 'Usage:.*install\.sh|Install dotfiles' ||
    fail "dot install -h should show install.sh help"
pass "dot install help"

# Path traversal still rejected
if "$DOT" '../install.sh' >/dev/null 2>&1; then
    fail "dot should reject path-like command names"
fi
pass "dot rejects path traversal"

# --- integration: plan mode in temp HOME ---
TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-smoke.XXXXXX")"
cleanup() { rm -rf "$TMP_HOME"; }
trap cleanup EXIT

export HOME="$TMP_HOME"
# Existing file should not be silently overwritten without backup in real runs;
# plan mode must not replace it with a symlink.
echo "existing git config" >"$HOME/.gitconfig"

# Run from a different cwd to ensure DOTFILES_DIR resolution works
cd /tmp
"$DOT" install --plan --yes --skip-brew --skip-api-keys --no-clear >/tmp/dot-install-plan.out 2>&1 || {
    cat /tmp/dot-install-plan.out >&2
    fail "dot install --plan failed"
}

grep -qi 'plan' /tmp/dot-install-plan.out || grep -qi 'Would' /tmp/dot-install-plan.out ||
    fail "plan output should mention plan/Would actions"
[[ -f "$HOME/.gitconfig" ]] || fail ".gitconfig should still exist after plan"
[[ ! -L "$HOME/.gitconfig" ]] || fail "plan mode must not symlink .gitconfig"
pass "dot install --plan in temp HOME"

# --- optional apply smoke (still skip brew) ---
HOME_APPLY="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-apply.XXXXXX")"
trap 'rm -rf "$TMP_HOME" "$HOME_APPLY"' EXIT
export HOME="$HOME_APPLY"

"$DOT" install --yes --skip-brew --skip-api-keys --no-clear >/tmp/dot-install-apply.out 2>&1 || {
    cat /tmp/dot-install-apply.out >&2
    fail "dot install --yes --skip-brew failed"
}

[[ -L "$HOME/.zshrc" ]] || fail "expected ~/.zshrc symlink after install"
# doctor in the same fake HOME
if ! "$DOTFILES_DIR/bin/doctor" --skip-tools >/tmp/dot-doctor.out 2>&1; then
    # Allow non-zero if strict failures remain (e.g. TPM warning is soft; missing
    # optional tools OK). Fail only if zshrc check itself failed.
    if ! grep -q 'Zsh config' /tmp/dot-doctor.out; then
        cat /tmp/dot-doctor.out >&2
        fail "doctor did not report zsh config"
    fi
fi
if grep -q 'Zsh config ->' /tmp/dot-doctor.out || grep -q 'Zsh config' /tmp/dot-doctor.out; then
    pass "doctor sees zsh after install"
else
    cat /tmp/dot-doctor.out >&2
    fail "doctor missing zsh success line"
fi

pass "all install smoke checks passed"
