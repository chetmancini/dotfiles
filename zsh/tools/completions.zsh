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

# Cached compinit - only regenerate once per day
autoload -Uz compinit
if [[ "$_compinit_rebuild" == true || -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi
unset _compinit_rebuild


# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
# Docker CLI completions are added to fpath above, before compinit

if [ -x /opt/homebrew/bin/terraform ]; then
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C /opt/homebrew/bin/terraform terraform
fi
