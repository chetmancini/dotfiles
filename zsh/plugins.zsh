# Zsh plugins — load order is load-bearing.
# history-substring-search first (then rebind ^P/^N), then autosuggestions,
# then syntax-highlighting last (must wrap all other zle widgets).

_zsh_plugin_share_dirs=(
  /opt/homebrew/share
  /home/linuxbrew/.linuxbrew/share
  /usr/local/share
  /usr/share
)

_zsh_source_plugin() {
  local name="$1"
  local dir file
  for dir in "${_zsh_plugin_share_dirs[@]}"; do
    file="$dir/$name/$name.zsh"
    if [[ -f "$file" ]]; then
      source "$file"
      return 0
    fi
  done
  return 1
}

_zsh_source_plugin zsh-history-substring-search
if (( $+functions[history-substring-search-up] )); then
  bindkey '^P' history-substring-search-up
  bindkey '^N' history-substring-search-down
  [[ -n "${terminfo[kcuu1]:-}" ]] && bindkey "${terminfo[kcuu1]}" history-substring-search-up
  [[ -n "${terminfo[kcud1]:-}" ]] && bindkey "${terminfo[kcud1]}" history-substring-search-down
fi

_zsh_source_plugin zsh-autosuggestions
# Must be sourced last — after all zle/bindkey calls
_zsh_source_plugin zsh-syntax-highlighting

unset -f _zsh_source_plugin
unset _zsh_plugin_share_dirs
