# Resolve the repo root from this file so the config works outside ~/dotfiles.
typeset -g DOTFILES_DIR="${${(%):-%N}:A:h}"

# Modular zsh config — order is load-bearing (see plans/002).
# New aliases → zsh/aliases.zsh or zsh/git.zsh; new tools → zsh/tools/<name>.zsh.
_zsh_modules=(
  options
  path
  platform
  theme
  aliases
  git
  functions
  secrets
  tools/fzf
  tools/zoxide
  tools/mise
  tools/direnv
  tools/atuin
  tools/completions
  tools/workbench
  fun
  plugins
)

for _m in ${_zsh_modules[@]}; do
  [[ -r "$DOTFILES_DIR/zsh/${_m}.zsh" ]] && source "$DOTFILES_DIR/zsh/${_m}.zsh"
done
unset _m _zsh_modules
