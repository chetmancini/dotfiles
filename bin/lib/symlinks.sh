#!/usr/bin/env bash

# Shared manifest for dotfiles symlinks installed by install.sh and verified by doctor.
# Fields are: source_relative_path|target_relative_to_home|install_name|doctor_label|description
managed_symlinks_for_group() {
    case "$1" in
        config)
            cat <<'EOF'
yazi|.config/yazi|Yazi File Manager|Yazi config|Terminal file manager with vim-like keybindings and image preview
ghostty|.config/ghostty|Ghostty Terminal|Ghostty config|GPU-accelerated terminal emulator configuration
nvim|.config/nvim|Neovim|Neovim config|LazyVim-based Neovim configuration with plugins and keymaps
mise|.config/mise|Mise|Mise config|Dev tool version manager with trusted config paths for ~/norm, ~/projects, ~/code
uv|.config/uv|uv|uv config|Python package manager config with exclude-newer for supply chain safety
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
.vimrc|.vimrc|Vim Configuration|Vim config|Legacy Vim configuration for environments that still use Vim
vim|.vim|Vim Runtime|Vim runtime|Legacy Vim runtime files, including colors and pathogen
.npmrc|.npmrc|npm Configuration|npm config|npm config with min-release-age to avoid installing very new packages
EOF
            ;;
        *)
            return 1
            ;;
    esac
}
