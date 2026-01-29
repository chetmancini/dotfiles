#!/bin/bash
set -e

#==============================================================================
# Dotfiles Installation Wizard
#==============================================================================

DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

#==============================================================================
# Helper Functions
#==============================================================================

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${BOLD}$1${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}→${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

# Ask user for confirmation, returns 0 for yes, 1 for no
ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi

    while true; do
        read -p "$prompt" answer
        answer="${answer:-$default}"
        case "$answer" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Back up a file or directory if it exists and is not a symlink
backup_if_exists() {
    local target="$1"
    local name="$2"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup_path="$BACKUP_DIR/$name"
        mv "$target" "$backup_path"
        print_warning "Backed up existing $name to $backup_path"
        return 0
    elif [ -L "$target" ]; then
        print_info "Existing symlink found, will be replaced"
        rm -f "$target"
        return 0
    fi
    return 0
}

# Create a symlink with explanation
create_symlink() {
    local source="$1"
    local target="$2"
    local name="$3"
    local description="$4"

    echo ""
    print_step "${BOLD}$name${NC}"
    print_info "$description"
    print_info "Source: $source"
    print_info "Target: $target"

    if [ -L "$target" ] && [ "$(readlink "$target")" == "$source" ]; then
        print_success "Already correctly symlinked"
        return 0
    fi

    if ask_yes_no "  Create this symlink?"; then
        backup_if_exists "$target" "$(basename "$target")"
        ln -sf "$source" "$target"
        print_success "Symlink created"
        SYMLINKS_CREATED=$((SYMLINKS_CREATED + 1))
    else
        print_warning "Skipped"
        SYMLINKS_SKIPPED=$((SYMLINKS_SKIPPED + 1))
    fi
}

#==============================================================================
# Main Script
#==============================================================================

# Counters for summary
SYMLINKS_CREATED=0
SYMLINKS_SKIPPED=0

clear
print_header "Dotfiles Installation Wizard"

echo -e "Welcome! This wizard will help you set up your dotfiles."
echo -e "Each step will be explained and you'll be asked for confirmation."
echo ""
echo -e "  ${BOLD}Dotfiles directory:${NC} $DOTFILES_DIR"
echo -e "  ${BOLD}Backup directory:${NC}   $BACKUP_DIR (if needed)"
echo ""

if ! ask_yes_no "Ready to begin?"; then
    echo "Installation cancelled."
    exit 0
fi

#==============================================================================
# Step 1: Clone oh-my-zsh
#==============================================================================
print_header "Step 1: Oh My Zsh"

echo "Oh My Zsh is a framework for managing your Zsh configuration."
echo "It provides helpful functions, plugins, and themes."
echo ""

if [ -d "$DOTFILES_DIR/oh-my-zsh" ]; then
    print_success "Oh My Zsh is already installed"
else
    if ask_yes_no "Clone Oh My Zsh repository?"; then
        print_step "Cloning oh-my-zsh..."
        git clone https://github.com/ohmyzsh/ohmyzsh.git "$DOTFILES_DIR/oh-my-zsh"
        print_success "Oh My Zsh cloned successfully"
    else
        print_warning "Skipped Oh My Zsh installation"
    fi
fi

#==============================================================================
# Step 2: Homebrew packages
#==============================================================================
print_header "Step 2: Homebrew Packages"

echo "The Brewfile contains a list of CLI tools, applications, and fonts"
echo "that will be installed via Homebrew."
echo ""

if command -v brew &> /dev/null; then
    if ask_yes_no "Install/update Homebrew packages from Brewfile?"; then
        print_step "Updating Homebrew..."
        brew update
        print_step "Installing packages from Brewfile..."
        brew bundle --file="$DOTFILES_DIR/Brewfile"
        print_success "Homebrew packages installed"
    else
        print_warning "Skipped Homebrew packages"
    fi
else
    print_warning "Homebrew is not installed. Skipping package installation."
    print_info "Install Homebrew from https://brew.sh"
fi

#==============================================================================
# Step 3: Config directory symlinks
#==============================================================================
print_header "Step 3: Config Directory Symlinks"

echo "These symlinks set up application configurations in ~/.config/"
echo ""

# Ensure ~/.config exists
mkdir -p ~/.config

create_symlink \
    "$DOTFILES_DIR/yazi" \
    "$HOME/.config/yazi" \
    "Yazi File Manager" \
    "Terminal file manager with vim-like keybindings and image preview"

create_symlink \
    "$DOTFILES_DIR/ghostty" \
    "$HOME/.config/ghostty" \
    "Ghostty Terminal" \
    "GPU-accelerated terminal emulator configuration"

create_symlink \
    "$DOTFILES_DIR/nvim" \
    "$HOME/.config/nvim" \
    "Neovim" \
    "LazyVim-based Neovim configuration with plugins and keymaps"

#==============================================================================
# Step 4: Git configuration
#==============================================================================
print_header "Step 4: Git Configuration"

echo "These symlinks set up git configuration files."
echo ""

create_symlink \
    "$DOTFILES_DIR/.gitconfig" \
    "$HOME/.gitconfig" \
    "Git Config" \
    "Main git configuration with aliases, delta pager, and conditional includes"

create_symlink \
    "$DOTFILES_DIR/.gitignore" \
    "$HOME/.gitignore" \
    "Global Gitignore" \
    "Global patterns to ignore across all repositories (e.g., .DS_Store)"

#==============================================================================
# Step 5: Shell configuration
#==============================================================================
print_header "Step 5: Shell Configuration"

echo "These symlinks set up your shell environment."
echo ""

create_symlink \
    "$DOTFILES_DIR/.zshrc" \
    "$HOME/.zshrc" \
    "Zsh Configuration" \
    "Main shell config: aliases, functions, PATH, and tool initialization"

create_symlink \
    "$DOTFILES_DIR/.tmux.conf" \
    "$HOME/.tmux.conf" \
    "Tmux Configuration" \
    "Terminal multiplexer config for managing multiple terminal sessions"

#==============================================================================
# Step 6: API Keys Template
#==============================================================================
print_header "Step 6: API Keys Setup"

echo "The api_keys.sh file stores environment variables and API keys."
echo "This file is gitignored to keep secrets out of version control."
echo ""

if [ -f "$DOTFILES_DIR/api_keys.sh" ]; then
    print_success "api_keys.sh already exists"
else
    if [ -f "$DOTFILES_DIR/api_keys.sh.template" ]; then
        if ask_yes_no "Create api_keys.sh from template?"; then
            cp "$DOTFILES_DIR/api_keys.sh.template" "$DOTFILES_DIR/api_keys.sh"
            print_success "Created api_keys.sh from template"
            print_info "Edit $DOTFILES_DIR/api_keys.sh to add your API keys"
        else
            print_warning "Skipped api_keys.sh creation"
        fi
    else
        print_warning "No api_keys.sh.template found"
    fi
fi

#==============================================================================
# Summary
#==============================================================================
print_header "Installation Complete!"

echo -e "  ${GREEN}Symlinks created:${NC} $SYMLINKS_CREATED"
echo -e "  ${YELLOW}Symlinks skipped:${NC} $SYMLINKS_SKIPPED"

if [ -d "$BACKUP_DIR" ]; then
    echo ""
    echo -e "  ${YELLOW}Backup directory:${NC} $BACKUP_DIR"
    echo -e "  Files that were replaced have been backed up there."
fi

echo ""
echo -e "${BOLD}Next steps:${NC}"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. If you created api_keys.sh, edit it to add your API keys"
echo "  3. Open Neovim to let LazyVim install plugins automatically"
echo ""
print_success "Happy coding!"
