#!/usr/bin/env bash
# scripts/install-hooks.sh — install git hooks from scripts/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! git -C "$DOTFILES_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    # Not a git repo (e.g. temp HOME smoke) — nothing to install
    echo "hooks: $DOTFILES_DIR is not a Git checkout — skipping" >&2
    exit 2
fi

HOOKS_DIR="$(git -C "$DOTFILES_DIR" rev-parse --git-path hooks)"
if [[ "$HOOKS_DIR" != /* ]]; then
    HOOKS_DIR="$DOTFILES_DIR/$HOOKS_DIR"
fi

HOOK_SRC="$DOTFILES_DIR/scripts/pre-commit"
HOOK_DST="$HOOKS_DIR/pre-commit"

if [[ ! -f "$HOOK_SRC" ]]; then
    echo "install-hooks: scripts/pre-commit not found" >&2
    exit 1
fi

if ! mkdir -p "$HOOKS_DIR" 2>/dev/null; then
    echo "hooks: cannot write to $HOOKS_DIR (read-only in this environment) — skipping" >&2
    exit 2
fi

# If a pre-commit hook already exists and is not our symlink/file, back it up
if [[ -e "$HOOK_DST" && ! -L "$HOOK_DST" ]]; then
    # Check if it's already our hook (content comparison)
    if cmp -s "$HOOK_SRC" "$HOOK_DST" 2>/dev/null; then
        echo "hooks: pre-commit already installed"
        exit 0
    fi
    backup="$HOOK_DST.backup.$(date +%Y%m%d-%H%M%S)"
    echo "hooks: backing up existing pre-commit to $backup"
    mv "$HOOK_DST" "$backup"
elif [[ -L "$HOOK_DST" ]]; then
    if [[ "$(readlink "$HOOK_DST")" == "$HOOK_SRC" ]]; then
        echo "hooks: pre-commit already linked"
        exit 0
    fi
    rm -f "$HOOK_DST"
fi

# Prefer symlink so updates to scripts/pre-commit apply automatically
if ln -sf "$HOOK_SRC" "$HOOK_DST" 2>/dev/null; then
    chmod +x "$HOOK_DST" 2>/dev/null || true
    echo "hooks: installed pre-commit (symlink)"
elif cp "$HOOK_SRC" "$HOOK_DST" 2>/dev/null; then
    chmod +x "$HOOK_DST" 2>/dev/null || true
    echo "hooks: installed pre-commit (copy)"
else
    echo "hooks: cannot install to $HOOK_DST (read-only) — skipping" >&2
    exit 2
fi
