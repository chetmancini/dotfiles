#!/usr/bin/env bash

# Shared manifest for dotfiles symlinks installed by install.sh and verified by doctor.
# Fields are: source_relative_path|target_relative_to_home|install_name|doctor_label|description
all_managed_symlinks_for_group() {
    case "$1" in
        config)
            cat <<'EOF'
yazi|.config/yazi|Yazi File Manager|Yazi config|Terminal file manager with vim-like keybindings and image preview
ghostty|.config/ghostty|Ghostty Terminal|Ghostty config|GPU-accelerated terminal emulator configuration
nvim|.config/nvim|Neovim|Neovim config|Neovim config (vim.pack + modular plugin/*.lua)
mise|.config/mise|Mise|Mise config|Dev tool version manager with trusted config paths for ~/norm, ~/projects, ~/code
uv|.config/uv|uv|uv config|Python package manager config with exclude-newer for supply chain safety
atuin|.config/atuin|Atuin|Atuin config|Shell history search defaults (no secrets; sync is operator opt-in)
herdr/config.toml|.config/herdr/config.toml|Herdr|Herdr config|Herdr workspace manager durable config (runtime state stays in ~/.config/herdr)
EOF
            ;;
        home)
            cat <<'EOF'
.gitconfig|.gitconfig|Git Config|Git config|Main git configuration with aliases, delta pager, and conditional includes
.gitignore|.gitignore|Global Gitignore|Global gitignore|Global patterns to ignore across all repositories (e.g., .DS_Store)
.zshrc|.zshrc|Zsh Configuration|Zsh config|Main shell config: aliases, functions, PATH, and tool initialization
.bashrc|.bashrc|Bash Configuration|Bash config|Compatibility shell config for environments that still start bash
.bash_profile|.bash_profile|Bash Profile|Bash profile|Login-shell entry point for bash-based environments
.tmux.conf|.tmux.conf|Tmux Configuration|tmux config|Terminal multiplexer config for managing multiple terminal sessions
npm/npmrc|.npmrc|npm Configuration|npm config|User-level npm config with a portable global prefix and release-age guardrail
EOF
            ;;
        legacy)
            # Not installed by default. install.sh prompts (default No); doctor does not require these.
            cat <<'EOF'
.vimrc|.vimrc|Vim Configuration|Vim config|Legacy Vim configuration for environments that still use Vim
vim|.vim|Vim Runtime|Vim runtime|Legacy Vim runtime files, including colors and pathogen
EOF
            ;;
        *)
            return 1
            ;;
    esac
}

# Profiles are cumulative. An unset profile preserves the historical full manifest.
managed_symlinks_for_group() {
    local record source_rel
    while IFS= read -r record; do
        source_rel="${record%%|*}"
        case "${DOTFILES_PROFILE:-desktop}:$source_rel" in
            minimal:*)
                case "$source_rel" in
                    .gitconfig | .gitignore | .zshrc | .bashrc | .bash_profile | .tmux.conf) ;;
                    *) continue ;;
                esac
                ;;
            development:ghostty) continue ;;
        esac
        # Omarchy owns its Bash startup and desktop integration. Use our zsh
        # config separately without replacing the distribution's login shell.
        if [ "${DOTFILES_PLATFORM:-}" = linux ]; then
            case "$source_rel" in .bashrc | .bash_profile) continue ;; esac
        fi
        printf '%s\n' "$record"
    done < <(all_managed_symlinks_for_group "$1")
}

load_install_profile() {
    local state="$HOME/.config/dotfiles/profile"
    if [ -f "$state" ]; then
        # read returns nonzero without a final newline; validate the value even
        # then, and report empty files through the same invalid-profile error.
        IFS= read -r DOTFILES_PROFILE <"$state" || true
        case "$DOTFILES_PROFILE" in
            minimal | development | desktop) ;;
            *)
                echo "Invalid install profile in $state" >&2
                return 1
                ;;
        esac
        case "$(uname -s)" in
            Linux) DOTFILES_PLATFORM=linux ;;
            Darwin) DOTFILES_PLATFORM=macos ;;
        esac
    fi
}
