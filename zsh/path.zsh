##############################
# Paths (core)
##############################
# Core daily-driver PATH. Product-specific bins live in path.extra.zsh
# (still existence-checked). Keep this list short and intentional.
export BREW_PATH=/opt/homebrew/bin
export JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
export CODE_DIR="$HOME/code"
export DEV_DIR="$HOME/Development"
export NPM_GLOBAL_BIN="$HOME/.npm-global/bin"
export PNPM_HOME="$HOME/Library/pnpm"
export PNPM_GLOBAL_BIN="$PNPM_HOME/bin"
export UV_PATH="$HOME/.local/bin"
export BUN_INSTALL="$HOME/.bun"
export USR_LOCAL_HOME=/usr/local/bin
export USR_LOCAL_SBIN=/usr/local/sbin
export PERSONAL_BIN="$DOTFILES_DIR/bin"
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

# Core paths (later entries have higher priority — prepended first = lower priority)
path_add \
    "$BREW_PATH" \
    "$PERSONAL_BIN" \
    "$USR_LOCAL_SBIN" \
    "$USR_LOCAL_HOME" \
    "$NPM_GLOBAL_BIN" \
    "$UV_PATH" \
    "$PNPM_GLOBAL_BIN" \
    "$BUN_INSTALL/bin" \
    "$JAVA_HOME/bin" \
    "$GROK_PATH" \
    "$HOME/bin"

export PATH

# Optional product/tool bins (LM Studio, Turso, IDE helpers, …)
[[ -r "$DOTFILES_DIR/zsh/path.extra.zsh" ]] && source "$DOTFILES_DIR/zsh/path.extra.zsh"
