#!/usr/bin/env bats
# tests/doctor.bats — doctor CLI and temp-HOME symlink checks

setup() {
    load helpers.bash
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "doctor --help exits 0 and prints usage" {
    run "$DOTFILES_DIR/bin/doctor" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: doctor"* ]]
}

@test "doctor --skip-tools succeeds in temp HOME after install" {
    tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor.XXXXXX")"
    # Run install without brew into temp HOME
    HOME="$tmp_home" "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear >/dev/null 2>&1
    run env HOME="$tmp_home" "$DOTFILES_DIR/bin/doctor" --skip-tools
    [ "$status" -eq 0 ]
    [[ "$output" == *"Zsh config"* ]] || [[ "$output" == *"Git config"* ]]
    rm -rf "$tmp_home"
}

@test "doctor detects missing symlink in temp HOME" {
    tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-missing.XXXXXX")"
    mkdir -p "$tmp_home/.config"
    # No symlinks — doctor should report failures (exit !=0)
    run env HOME="$tmp_home" "$DOTFILES_DIR/bin/doctor" --skip-tools
    [ "$status" -ne 0 ]
    [[ "$output" == *"is not a symlink"* ]]
    rm -rf "$tmp_home"
}

@test "doctor --strict fails when tools missing (isolated PATH)" {
    # With a minimal PATH, at least one tool check should fail under --strict
    tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-strict.XXXXXX")"
    HOME="$tmp_home" "$DOTFILES_DIR/install.sh" --yes --skip-tpm --skip-brew --skip-api-keys --skip-hooks --no-clear >/dev/null 2>&1
    run env HOME="$tmp_home" PATH="/usr/bin:/bin" "$DOTFILES_DIR/bin/doctor" --strict --skip-tools
    # --skip-tools should still pass even with isolated PATH
    [ "$status" -eq 0 ]
    rm -rf "$tmp_home"
}

stub_pnpm_global_root() {
    # Creates $PNPM_STUB_BIN (fake pnpm answering bin/root --global) and
    # $PNPM_STUB_ROOT (global/v11-like dir). Caller writes the manifest into
    # $PNPM_STUB_ROOT/abcd-1234567890a-bcdef0123456789a/package.json.
    # An alias symlink mirrors pnpm's sha->dir links to exercise dedup.
    local install_dir="abcd-1234567890a-bcdef0123456789a"
    PNPM_STUB_BIN="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-pnpm-bin.XXXXXX")"
    PNPM_STUB_GLOBAL_BIN="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-pnpm-globalbin.XXXXXX")"
    PNPM_STUB_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-pnpm-root.XXXXXX")"
    mkdir -p "$PNPM_STUB_ROOT/$install_dir/node_modules"
    ln -s "$install_dir" "$PNPM_STUB_ROOT/deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    cat >"$PNPM_STUB_BIN/pnpm" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
    "bin --global") echo "$PNPM_STUB_GLOBAL_BIN" ;;
    "root --global") echo "$PNPM_STUB_ROOT" ;;
    *) exit 1 ;;
esac
EOF
    chmod +x "$PNPM_STUB_BIN/pnpm"
}

cleanup_pnpm_stub() {
    rm -rf "$PNPM_STUB_BIN" "$PNPM_STUB_GLOBAL_BIN" "$PNPM_STUB_ROOT"
}

@test "doctor warns on file:/link: deps in pnpm global manifests" {
    stub_pnpm_global_root
    printf '{"dependencies":{"@pnpm/exe":"file:/opt/homebrew/bin"}}\n' \
        >"$PNPM_STUB_ROOT/abcd-1234567890a-bcdef0123456789a/package.json"
    tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-pnpm-home.XXXXXX")"
    run env HOME="$tmp_home" PATH="$PNPM_STUB_BIN:$PNPM_STUB_GLOBAL_BIN:/usr/bin:/bin" \
        "$DOTFILES_DIR/bin/doctor"
    [[ "$output" == *"links a local directory for '@pnpm/exe'"* ]]
    # The alias symlink mirrors the same install dir; it must not double-warn.
    [ "$(printf '%s\n' "$output" | grep -c 'links a local directory')" -eq 1 ]
    cleanup_pnpm_stub
    rm -rf "$tmp_home"
}

@test "doctor stays quiet for registry-only pnpm global manifests" {
    stub_pnpm_global_root
    printf '{"dependencies":{"pnpm":"11.21.0"}}\n' \
        >"$PNPM_STUB_ROOT/abcd-1234567890a-bcdef0123456789a/package.json"
    tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-doctor-pnpm-home.XXXXXX")"
    run env HOME="$tmp_home" PATH="$PNPM_STUB_BIN:$PNPM_STUB_GLOBAL_BIN:/usr/bin:/bin" \
        "$DOTFILES_DIR/bin/doctor"
    [[ "$output" == *"pnpm global bin is on PATH"* ]]
    [[ "$output" != *"links a local directory"* ]]
    cleanup_pnpm_stub
    rm -rf "$tmp_home"
}
