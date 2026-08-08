# direnv — load project .envrc when cd'ing into a directory.
# Per project: create .envrc, then `direnv allow`. Never commit secrets;
# prefer gitignored .env + `dotenv`/`source_env`, or `op inject`.
if command -v direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi
