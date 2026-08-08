# atuin — SQLite-backed shell history with fuzzy search.
#
# Binding policy:
#   - atuin owns Ctrl-R (modern history search UI)
#   - up/down and ^P/^N stay with history-substring-search (see plugins.zsh)
#   - fzf keeps Ctrl-T / Alt-C for files and directories
#
# Load after options.zsh history binds so atuin wins on ^R; load before
# plugins.zsh so syntax-highlighting remains last.
if command -v atuin &>/dev/null; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi
