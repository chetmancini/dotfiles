# Version managers — mise is the single runtime manager (node, python, …).
# Package managers stay separate: uv, pnpm, bun.
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"

  # Mise rebuilds PATH and can drop pnpm's module-owned global bin.
  _dotfiles_restore_pnpm_path() {
    path_add "$PNPM_GLOBAL_BIN"
    export PATH
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook -d precmd _dotfiles_restore_pnpm_path 2>/dev/null || :
  add-zsh-hook -d chpwd _dotfiles_restore_pnpm_path 2>/dev/null || :
  add-zsh-hook precmd _dotfiles_restore_pnpm_path
  add-zsh-hook chpwd _dotfiles_restore_pnpm_path
  _dotfiles_restore_pnpm_path
fi
