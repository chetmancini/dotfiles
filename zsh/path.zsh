##############################
# Paths
##############################
export BREW_PATH=/opt/homebrew/bin
export JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
export CODE_DIR="$HOME/code"
export DEV_DIR="$HOME/Development"
export NPM_GLOBAL_BIN="$HOME/.npm-global/bin"
export PNPM_HOME="$HOME/Library/pnpm"
export UV_PATH="$HOME/.local/bin"
export BUN_INSTALL="$HOME/.bun"
export USR_LOCAL_HOME=/usr/local/bin
export USR_LOCAL_SBIN=/usr/local/sbin
export PERSONAL_BIN="$DOTFILES_DIR/bin"
export MODULAR_HOME="$HOME/.modular"
export LMSTUDIO_PATH="$HOME/.lmstudio/bin"
export ZEROBREW_PATH="/opt/zerobrew/prefix/bin"
export OPENCODE_PATH="$HOME/.opencode/bin"
export LMSTUDIO_CACHE_PATH="$HOME/.cache/lm-studio/bin"
export ANTIGRAVITY_PATH="$HOME/.antigravity/antigravity/bin"
export TURSO_PATH="$HOME/.turso"
export BROWSER_USE_PATH="$HOME/.browser-use/bin"
export GROK_PATH="$HOME/.grok/bin"
# Keep PATH unique when this file is sourced multiple times.
typeset -U path PATH

# Build PATH dynamically, only adding directories that exist
path_add() {
    local dir
    for dir in "$@"; do
        if [[ -d "$dir" ]]; then
            path=("$dir" "${path[@]}")
        fi
    done
}

# Add paths in order (later entries have higher priority)
path_add \
    "$LMSTUDIO_PATH" \
    "$LMSTUDIO_CACHE_PATH" \
    "$MODULAR_HOME/bin" \
    "$BREW_PATH" \
    "$PERSONAL_BIN" \
    "$USR_LOCAL_SBIN" \
    "$USR_LOCAL_HOME" \
    "$ZEROBREW_PATH" \
    "$NPM_GLOBAL_BIN" \
    "$UV_PATH" \
    "$PNPM_HOME" \
    "$BUN_INSTALL/bin" \
    "$JAVA_HOME/bin" \
    "$OPENCODE_PATH" \
    "$ANTIGRAVITY_PATH" \
    "$TURSO_PATH" \
    "$BROWSER_USE_PATH" \
    "$GROK_PATH" \
    "$HOME/bin"

export PATH
# Source tool-managed env files after PATH is built (may set additional vars)
[[ -f "$HOME/.turso/env" ]] && . "$HOME/.turso/env"
export CLASSPATH=$HOME/lib/jars
