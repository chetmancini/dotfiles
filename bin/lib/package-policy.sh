#!/usr/bin/env bash
# shellcheck shell=bash

# Canonical package-manager policy. Each record uses this format:
# id|brew_kind|brew_name|command|owner|install_hint
#
# `brew_name` lets brew-sync recognize a Brewfile entry that is intentionally
# supplied by another owner. One executable has one preferred owner; do not
# add duplicate installs merely to satisfy a package manager's drift check.
package_policy_records() {
    cat <<'EOF'
# id|brew_kind|brew_name|command|owner|install_hint
node|formula|node|node|mise|Install and pin Node with mise, not Homebrew
python|formula|python|python|mise|Install and pin Python with mise, not Homebrew
bun|formula|bun|bun|mise|Install bun with mise, not Homebrew
pnpm|formula|pnpm|pnpm|mise|Install pnpm with mise, not Homebrew
uv|formula|uv|uv|mise|Install uv with mise, not Homebrew
ruff|formula|ruff|ruff|mise|Install ruff with mise, not Homebrew
gh|formula|gh|gh|mise|Install gh with mise, not Homebrew
jq|formula|jq|jq|mise|Install jq with mise, not Homebrew
ripgrep|formula|ripgrep|rg|mise|Install ripgrep with mise, not Homebrew
fd|formula|fd|fd|mise|Install fd with mise, not Homebrew
bat|formula|bat|bat|mise|Install bat with mise, not Homebrew
fzf|formula|fzf|fzf|mise|Install fzf with mise, not Homebrew
zoxide|formula|zoxide|zoxide|mise|Install zoxide with mise, not Homebrew
shellcheck|formula|shellcheck|shellcheck|mise|Install shellcheck with mise, not Homebrew
shfmt|formula|shfmt|shfmt|mise|Install shfmt with mise, not Homebrew
stylua|formula|stylua|stylua|mise|Install stylua with mise, not Homebrew
rtk|formula|rtk|rtk|mise|Install rtk with mise, not Homebrew
mise|formula|mise|mise|vendor|Install mise with the official installer: curl https://mise.run | sh
claude-code|cask|claude-code|claude|vendor|Use the official Claude Code installer; Homebrew releases can lag
EOF
}

# Print policy entries for Brewfile packages already supplied by their preferred
# non-Homebrew owner. Arguments: brew_kind, newline-delimited package names.
# Output: package|owner|command|install_hint
package_policy_external_satisfaction() {
    local brew_kind="$1"
    local packages="$2"
    local package id record_kind brew_name command owner install_hint

    [ -n "$packages" ] || return 0

    # brew-sync says "brew"; records and `brew list --formula` say "formula".
    if [ "$brew_kind" = "brew" ]; then
        brew_kind="formula"
    fi

    while IFS= read -r package; do
        [ -n "$package" ] || continue
        while IFS='|' read -r id record_kind brew_name command owner install_hint; do
            case "$id" in
                '' | \#*) continue ;;
            esac
            [ "$record_kind" = "$brew_kind" ] || continue
            [ "$brew_name" = "$package" ] || continue
            [ "$owner" != "brew" ] || continue
            if command -v "$command" >/dev/null 2>&1; then
                printf '%s|%s|%s|%s\n' "$package" "$owner" "$command" "$install_hint"
                break
            fi
        done < <(package_policy_records)
    done <<EOF
$packages
EOF

    return 0
}
