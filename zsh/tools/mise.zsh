# Version managers — mise is the single runtime manager (node, python, …).
# Package managers stay separate: uv, pnpm, bun.
# Official/core install lives at ~/.local/bin (not Homebrew).
# Equivalent to: eval "$(~/.local/bin/mise activate zsh)"
_dotfiles_mise="${HOME}/.local/bin/mise"
if [[ ! -x "$_dotfiles_mise" ]]; then
  _dotfiles_mise="$(command -v mise 2>/dev/null || true)"
fi
if [[ -n "$_dotfiles_mise" ]]; then
  eval "$("$_dotfiles_mise" activate zsh)"

  # Mise rebuilds PATH and can drop pnpm's home and global bin directories.
  # Register these after activate so they run after mise's own hooks.
  _dotfiles_restore_pnpm_path() {
    path_add "$PNPM_HOME" "$PNPM_GLOBAL_BIN"
    export PATH
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook -d precmd _dotfiles_restore_pnpm_path 2>/dev/null || :
  add-zsh-hook -d chpwd _dotfiles_restore_pnpm_path 2>/dev/null || :
  add-zsh-hook precmd _dotfiles_restore_pnpm_path
  add-zsh-hook chpwd _dotfiles_restore_pnpm_path
  _dotfiles_restore_pnpm_path
fi
unset _dotfiles_mise
