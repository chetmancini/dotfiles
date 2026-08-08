##############################
# Secrets / org-specific env
##############################
# Source API keys if file exists (gitignored, see api_keys.sh.template)
[ -f "$DOTFILES_DIR/api_keys.sh" ] && source "$DOTFILES_DIR/api_keys.sh"

# Source 1Password-backed API keys (can override above, see api_keys_1password.sh.template)
[ -f "$DOTFILES_DIR/api_keys_1password.sh" ] && source "$DOTFILES_DIR/api_keys_1password.sh"

# SSH keys are managed by macOS Keychain automatically
# No need to call ssh-add on every shell startup
[ -f "$DOTFILES_DIR/norm_specific.sh" ] && source "$DOTFILES_DIR/norm_specific.sh"
