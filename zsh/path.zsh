##############################
# Paths (core)
##############################
# Core daily-driver PATH. Product-specific bins live in path.extra.zsh
# (still existence-checked). Keep this list short and intentional.
# Respect custom Homebrew prefixes; discover standard installs without invoking
# brew on every shell startup (Apple Silicon, Intel Mac, and Linuxbrew).
if [[ -z "${HOMEBREW_PREFIX:-}" ]]; then
    for _brew_prefix in /opt/homebrew /home/linuxbrew/.linuxbrew /usr/local; do
        if [[ -x "$_brew_prefix/bin/brew" ]]; then
            export HOMEBREW_PREFIX="$_brew_prefix"
            break
        fi
    done
    unset _brew_prefix
fi
export BREW_PATH="${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/bin}"
if [[ -z "${JAVA_HOME:-}" && -n "${HOMEBREW_PREFIX:-}" ]]; then
    if [[ "$OSTYPE" == darwin* ]]; then
        _java_home="$HOMEBREW_PREFIX/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
    else
        _java_home="$HOMEBREW_PREFIX/opt/openjdk/libexec/openjdk"
    fi
    [[ -d "$_java_home" ]] && export JAVA_HOME="$_java_home"
    unset _java_home
fi
export CODE_DIR="$HOME/code"
export DEV_DIR="$HOME/Development"
export NPM_GLOBAL_BIN="$HOME/.npm-global/bin"
if [[ "$OSTYPE" == darwin* ]]; then
    export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
else
    export PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
fi
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
    "$PNPM_HOME" \
    "$PNPM_GLOBAL_BIN" \
    "$BUN_INSTALL/bin" \
    "${JAVA_HOME:+$JAVA_HOME/bin}" \
    "$GROK_PATH" \
    "$HOME/bin"

export PATH

# Optional product/tool bins (LM Studio, Turso, IDE helpers, …)
[[ -r "$DOTFILES_DIR/zsh/path.extra.zsh" ]] && source "$DOTFILES_DIR/zsh/path.extra.zsh"
