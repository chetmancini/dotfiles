##############################
# Secrets / org-specific env
##############################
# Prefer 1Password-backed secrets (api_keys_1password.sh).
# Plaintext api_keys.sh is bootstrap-only; keep it empty or delete once 1P works.
# Load order: plaintext first, then 1Password so op-backed exports can override
# during migration. Long-term: use only the 1Password file.
# Templates: api_keys.sh.template, api_keys_1password.sh.template (both gitignored when copied).
# Never commit real secret values. Set DOTFILES_DEBUG=1 to see load/op warnings (names only).

if [[ -n "${DOTFILES_DEBUG:-}" ]]; then
  [[ -f "$DOTFILES_DIR/api_keys.sh" ]] && echo "dotfiles: sourcing api_keys.sh" >&2
  [[ -f "$DOTFILES_DIR/api_keys_1password.sh" ]] && echo "dotfiles: sourcing api_keys_1password.sh" >&2
fi

[ -f "$DOTFILES_DIR/api_keys.sh" ] && source "$DOTFILES_DIR/api_keys.sh"
[ -f "$DOTFILES_DIR/api_keys_1password.sh" ] && source "$DOTFILES_DIR/api_keys_1password.sh"

# SSH keys are managed by macOS Keychain automatically
# No need to call ssh-add on every shell startup
[ -f "$DOTFILES_DIR/norm_specific.sh" ] && source "$DOTFILES_DIR/norm_specific.sh"
