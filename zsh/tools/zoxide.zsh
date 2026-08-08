if command -v zoxide &> /dev/null; then
  # --cmd cd makes zoxide own `cd` (it still cd's into literal paths) and adds
  # `cdi` for interactive fuzzy jumps. Replaces the hand-rolled cd() wrapper.
  eval "$(zoxide init zsh --cmd cd)"
fi
