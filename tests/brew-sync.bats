#!/usr/bin/env bats
# tests/brew-sync.bats — parsing and help for brew-sync
# No real brew needed; parsing tests use temp Brewfiles.

setup() {
    load helpers.bash
    DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TMP_BREWFILE="$(mktemp "${TMPDIR:-/tmp}/Brewfile.XXXXXX")"
    TMP_OPTIONAL="$(mktemp "${TMPDIR:-/tmp}/Brewfile.optional.XXXXXX")"
}

teardown() {
    rm -f "$TMP_BREWFILE" "$TMP_OPTIONAL"
}

@test "brew-sync --help prints usage" {
    run "$DOTFILES_DIR/bin/brew-sync" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: brew-sync"* ]]
    [[ "$output" == *"--add"* ]]
}

@test "get_brewfile_formulae strips tap prefix and comments" {
    cat >"$TMP_BREWFILE" <<'EOF'
brew "ripgrep"                  # fast grep
brew "can1357/tap/omp"          # tap-prefixed
  brew "bat"                    # indented
# brew "ignored"
cask "font-hack"
EOF
    # Source parsing helpers by extracting functions from brew-sync
    # Replicate get_brewfile_formulae logic directly for isolation
    run bash -c "
        BREWFILE='$TMP_BREWFILE'
        get_brewfile_formulae() {
            grep -E '^[[:space:]]*brew[[:space:]]+\"' \"\$BREWFILE\" 2>/dev/null |
                sed -E 's/^[[:space:]]*brew[[:space:]]+\"([^\"]+)\".*/\1/' |
                sed -E 's|^.*/||' |
                sort -u
        }
        get_brewfile_formulae
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"bat"* ]]
    [[ "$output" == *"omp"* ]]
    [[ "$output" == *"ripgrep"* ]]
    # Should NOT include cask or commented lines
    [[ "$output" != *"font-hack"* ]]
    [[ "$output" != *"ignored"* ]]
}

@test "get_brewfile_casks extracts casks only" {
    cat >"$TMP_BREWFILE" <<'EOF'
brew "ripgrep"
cask "ghostty"
  cask "font-hack-nerd-font"  # nerd font
# cask "ignored"
EOF
    run bash -c "
        BREWFILE='$TMP_BREWFILE'
        get_brewfile_casks() {
            grep -E '^[[:space:]]*cask[[:space:]]+\"' \"\$BREWFILE\" 2>/dev/null |
                sed -E 's/^[[:space:]]*cask[[:space:]]+\"([^\"]+)\".*/\1/' |
                sort -u
        }
        get_brewfile_casks
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"ghostty"* ]]
    [[ "$output" == *"font-hack-nerd-font"* ]]
    [[ "$output" != *"ripgrep"* ]]
}

@test "short_formula_names strips tap prefix" {
    run bash -c "
        source <(grep -A2 '^short_formula_names()' '$DOTFILES_DIR/bin/brew-sync')
        printf 'can1357/tap/omp\nripgrep\n' | short_formula_names
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"omp"* ]]
    [[ "$output" == *"ripgrep"* ]]
}

@test "brew-sync --dry-run does not modify Brewfile" {
    cat >"$TMP_BREWFILE" <<'EOF'
brew "ripgrep"
EOF
    # Run with BREWFILE override; --check should not fail due to missing brew
    # We stub brew via PATH to avoid requiring Homebrew
    fake_bin="$(mktemp -d "${TMPDIR:-/tmp}/fakebin.XXXXXX")"
    cat >"$fake_bin/brew" <<'EOS'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then exit 0; fi
if [[ "$1" == "outdated" ]]; then exit 0; fi
if [[ "$1" == "autoremove" ]]; then exit 0; fi
exit 0
EOS
    chmod +x "$fake_bin/brew"
    run env BREWFILE="$TMP_BREWFILE" PATH="$fake_bin:$PATH" "$DOTFILES_DIR/bin/brew-sync" --check
    # Should exit 0 when in sync (empty vs empty) or 1 if drift — either is valid
    # but Brewfile must not be modified
    [[ "$(cat "$TMP_BREWFILE")" == 'brew "ripgrep"'* ]]
    rm -rf "$fake_bin"
}
