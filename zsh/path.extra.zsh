##############################
# Paths (extras — product / optional tools)
##############################
# Sourced from path.zsh when present. Each entry is still existence-checked.
# Add machine-specific tools here rather than bloating the core path list.
# To disable all extras temporarily: rename/remove this file or comment path_add.

export MODULAR_HOME="${MODULAR_HOME:-$HOME/.modular}"
export LMSTUDIO_PATH="${LMSTUDIO_PATH:-$HOME/.lmstudio/bin}"
export LMSTUDIO_CACHE_PATH="${LMSTUDIO_CACHE_PATH:-$HOME/.cache/lm-studio/bin}"
export ZEROBREW_PATH="${ZEROBREW_PATH:-/opt/zerobrew/prefix/bin}"
export OPENCODE_PATH="${OPENCODE_PATH:-$HOME/.opencode/bin}"
export ANTIGRAVITY_PATH="${ANTIGRAVITY_PATH:-$HOME/.antigravity/antigravity/bin}"
export TURSO_PATH="${TURSO_PATH:-$HOME/.turso}"
export BROWSER_USE_PATH="${BROWSER_USE_PATH:-$HOME/.browser-use/bin}"

path_add \
    "$LMSTUDIO_PATH" \
    "$LMSTUDIO_CACHE_PATH" \
    "$MODULAR_HOME/bin" \
    "$ZEROBREW_PATH" \
    "$OPENCODE_PATH" \
    "$ANTIGRAVITY_PATH" \
    "$TURSO_PATH" \
    "$BROWSER_USE_PATH"

export PATH

# Tool-managed env files (only if the tool dir is in use)
[[ -f "$HOME/.turso/env" ]] && . "$HOME/.turso/env"

# Optional classpath for local jars (no-op if unused)
export CLASSPATH="${CLASSPATH:-$HOME/lib/jars}"
