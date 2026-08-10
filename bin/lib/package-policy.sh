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
