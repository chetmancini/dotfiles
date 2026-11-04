# Completion dirs must be on fpath before compinit so they're picked up by the
# single cached compinit below (installer blocks at the bottom only set fpath).
_compinit_rebuild=false
[ -d ~/.grok/completions/zsh ] && fpath=(~/.grok/completions/zsh $fpath)
if [ -d ~/.docker/completions ]; then
  fpath=(~/.docker/completions $fpath)
  if [[ -r ~/.zcompdump ]] && ! command grep -q "'docker' '_docker'" ~/.zcompdump; then
    _compinit_rebuild=true
  fi
fi

# Cached compinit — rebuild when the dump is missing or older than a day.
# The check has to be a real glob. Inside [[ ]], `(#q...)` is literal unless
# EXTENDED_GLOB is on, and a non-empty literal string is always true.
autoload -Uz compinit
_dotfiles_compdump_stale() {
  setopt LOCAL_OPTIONS EXTENDED_GLOB
  [[ -f ~/.zcompdump ]] || return 0
  local -a stale
  stale=(~/.zcompdump(Nmh+24))
  (( ${#stale} ))
}
if [[ "$_compinit_rebuild" == true ]] || _dotfiles_compdump_stale; then
  compinit
else
  compinit -C
fi
unset _compinit_rebuild
unfunction _dotfiles_compdump_stale


# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
# Docker CLI completions are added to fpath above, before compinit

if command -v terraform >/dev/null 2>&1; then
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C "$(command -v terraform)" terraform
fi
