# Version managers — mise is the single runtime manager (node, python, …).
# Package managers stay separate: uv, pnpm, bun.
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi
