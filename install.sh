#!/usr/bin/env bash
set -euo pipefail

#==============================================================================
# Dotfiles Installation Wizard
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# shellcheck source=bin/lib/symlinks.sh
source "$SCRIPT_DIR/bin/lib/symlinks.sh"

AUTO_YES=false
SKIP_OH_MY_ZSH=false
SKIP_TPM=false
SKIP_BREW=false
SKIP_API_KEYS=false
CLEAR_SCREEN=true
PLAN_MODE=false

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

print_help() {
    cat <<'EOF'
Usage: ./install.sh [options]

Install dotfiles into the current HOME directory.

Options:
  --yes              Run non-interactively and accept all prompts
  --plan, --dry-run  Preview changes without modifying files
  --skip-oh-my-zsh   Skip cloning oh-my-zsh and theme installation
  --skip-tpm         Skip tmux plugin manager installation
  --skip-brew        Skip Homebrew package installation
  --skip-api-keys    Skip creating api_keys.sh from template
  --no-clear         Do not clear the screen before starting
  -h, --help         Show this help message
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --yes)
                AUTO_YES=true
                shift
                ;;
            --plan | --dry-run)
                PLAN_MODE=true
                shift
                ;;
            --skip-oh-my-zsh)
                SKIP_OH_MY_ZSH=true
                shift
                ;;
            --skip-tpm)
                SKIP_TPM=true
                shift
                ;;
            --skip-brew)
                SKIP_BREW=true
                shift
                ;;
            --skip-api-keys)
                SKIP_API_KEYS=true
                shift
                ;;
            --no-clear)
                CLEAR_SCREEN=false
                shift
                ;;
            -h | --help)
                print_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done
}

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}  ${BOLD}$1${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}>${NC} $1"
}

print_success() {
    echo -e "${GREEN}[ok]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[warn]${NC} $1"
}

print_error() {
    echo -e "${RED}[error]${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}[info]${NC} $1"
}

print_plan() {
    echo -e "  ${BLUE}[plan]${NC} $1"
}

# Ask user for confirmation, returns 0 for yes, 1 for no
ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"

    if [ "$AUTO_YES" = true ]; then
        print_info "$prompt (auto-yes)"
        return 0
    fi

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi

    while true; do
        read -r -p "$prompt" answer
        answer="${answer:-$default}"
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Back up a file or directory if it exists and is not a symlink
backup_if_exists() {
    local target="$1"
    local name="$2"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
        local backup_path="$BACKUP_DIR/$name"
        if [ "$PLAN_MODE" = true ]; then
            print_plan "Would back up existing $name to $backup_path"
            BACKUPS_PLANNED=$((BACKUPS_PLANNED + 1))
        else
            mkdir -p "$BACKUP_DIR"
            mv "$target" "$backup_path"
            print_warning "Backed up existing $name to $backup_path"
        fi
        return 0
    elif [ -L "$target" ]; then
        if [ "$PLAN_MODE" = true ]; then
            print_plan "Existing symlink found, would replace it"
        else
            print_info "Existing symlink found, will be replaced"
            rm -f "$target"
        fi
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

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        print_success "Already correctly symlinked"
        return 0
    fi

    if ask_yes_no "  Create this symlink?"; then
        backup_if_exists "$target" "$(basename "$target")"
        if [ "$PLAN_MODE" = true ]; then
            if [ ! -d "$(dirname "$target")" ]; then
                print_plan "Would create parent directory $(dirname "$target")"
            fi
            print_success "Symlink would be created"
            SYMLINKS_PLANNED=$((SYMLINKS_PLANNED + 1))
        else
            mkdir -p "$(dirname "$target")"
            ln -sf "$source" "$target"
            print_success "Symlink created"
            SYMLINKS_CREATED=$((SYMLINKS_CREATED + 1))
        fi
    else
        print_warning "Skipped"
        SYMLINKS_SKIPPED=$((SYMLINKS_SKIPPED + 1))
    fi
}

install_oh_my_zsh() {
    print_header "Step 1: Oh My Zsh"

    echo "Oh My Zsh is a framework for managing your Zsh configuration."
    echo "It provides helpful functions, plugins, and themes."
    echo ""

    if [ "$SKIP_OH_MY_ZSH" = true ]; then
        print_warning "Skipping Oh My Zsh installation by request"
        return 0
    fi

    if [ -d "$DOTFILES_DIR/oh-my-zsh" ]; then
        print_success "Oh My Zsh is already installed"
    else
        if ask_yes_no "Clone Oh My Zsh repository?"; then
            if [ "$PLAN_MODE" = true ]; then
                print_step "Would clone oh-my-zsh into $DOTFILES_DIR/oh-my-zsh"
                print_success "Oh My Zsh clone planned"
            else
                print_step "Cloning oh-my-zsh..."
                git clone https://github.com/ohmyzsh/ohmyzsh.git "$DOTFILES_DIR/oh-my-zsh"
                print_success "Oh My Zsh cloned successfully"
            fi
        else
            print_warning "Skipped Oh My Zsh installation"
            return 0
        fi
    fi

    print_header "Step 2: Oh My Zsh Theme"

    create_symlink \
        "$DOTFILES_DIR/chetmancini.zsh-theme" \
        "$DOTFILES_DIR/oh-my-zsh/custom/themes/chetmancini.zsh-theme" \
        "Chetmancini Theme" \
        "Custom oh-my-zsh theme used by .zshrc for prompt and git status"
}

install_tpm() {
    print_header "Step 3: Tmux Plugin Manager"

    echo "TPM manages tmux plugins like tmux-resurrect (session save/restore)"
    echo "and tmux-continuum (automatic session persistence across reboots)."
    echo ""

    if [ "$SKIP_TPM" = true ]; then
        print_warning "Skipping TPM installation by request"
        return 0
    fi

    if [ -d "$HOME/.tmux/plugins/tpm" ]; then
        print_success "TPM is already installed"
        return 0
    fi

    if ask_yes_no "Install Tmux Plugin Manager (TPM)?"; then
        if [ "$PLAN_MODE" = true ]; then
            print_step "Would clone TPM into $HOME/.tmux/plugins/tpm"
            print_success "TPM install planned"
        else
            print_step "Cloning TPM..."
            git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
            print_success "TPM installed"
        fi
        print_info "After setup, press prefix + I in tmux to install plugins"
    else
        print_warning "Skipped TPM installation"
    fi
}

install_homebrew() {
    print_header "Step 4: Homebrew Packages"

    echo "The Brewfile contains a list of CLI tools, applications, and fonts"
    echo "that will be installed via Homebrew."
    echo ""

    if [ "$SKIP_BREW" = true ]; then
        print_warning "Skipping Homebrew package installation by request"
        return 0
    fi

    if command -v brew >/dev/null 2>&1; then
        if ask_yes_no "Install/update Homebrew packages from Brewfile?"; then
            if [ "$PLAN_MODE" = true ]; then
                print_step "Would run: brew update"
                print_step "Would run: brew bundle --file=\"$DOTFILES_DIR/Brewfile\""
                print_success "Homebrew package install planned"
            else
                print_step "Updating Homebrew..."
                brew update
                print_step "Installing packages from Brewfile..."
                brew bundle --file="$DOTFILES_DIR/Brewfile"
                print_success "Homebrew packages installed"
            fi
        else
            print_warning "Skipped Homebrew packages"
        fi
    else
        print_warning "Homebrew is not installed. Skipping package installation."
        print_info "Install Homebrew from https://brew.sh"
    fi
}

install_config_symlinks() {
    print_header "Step 5: Config Directory Symlinks"

    echo "These symlinks set up application configurations in ~/.config/"
    echo ""

    if [ "$PLAN_MODE" = true ]; then
        if [ ! -d "$HOME/.config" ]; then
            print_plan "Would create directory $HOME/.config"
        fi
    else
        mkdir -p "$HOME/.config"
    fi

    while IFS='|' read -r source_rel target_rel install_name _doctor_label description; do
        create_symlink \
            "$DOTFILES_DIR/$source_rel" \
            "$HOME/$target_rel" \
            "$install_name" \
            "$description"
    done < <(managed_symlinks_for_group config)
}

install_home_symlinks() {
    print_header "Step 6: Home Directory Symlinks"

    echo "These symlinks set up git, shell, and editor files in your home directory."
    echo ""

    while IFS='|' read -r source_rel target_rel install_name _doctor_label description; do
        create_symlink \
            "$DOTFILES_DIR/$source_rel" \
            "$HOME/$target_rel" \
            "$install_name" \
            "$description"
    done < <(managed_symlinks_for_group home)
}

install_api_keys_template() {
    print_header "Step 7: API Keys Setup"

    echo "The api_keys.sh file stores environment variables and API keys."
    echo "This file is gitignored to keep secrets out of version control."
    echo ""

    if [ "$SKIP_API_KEYS" = true ]; then
        print_warning "Skipping api_keys.sh creation by request"
        return 0
    fi

    if [ -f "$DOTFILES_DIR/api_keys.sh" ]; then
        print_success "api_keys.sh already exists"
    elif [ -f "$DOTFILES_DIR/api_keys.sh.template" ]; then
        if ask_yes_no "Create api_keys.sh from template?"; then
            if [ "$PLAN_MODE" = true ]; then
                print_step "Would copy api_keys.sh.template to api_keys.sh"
                print_success "api_keys.sh creation planned"
                print_info "You would then edit $DOTFILES_DIR/api_keys.sh to add your API keys"
            else
                cp "$DOTFILES_DIR/api_keys.sh.template" "$DOTFILES_DIR/api_keys.sh"
                print_success "Created api_keys.sh from template"
                print_info "Edit $DOTFILES_DIR/api_keys.sh to add your API keys"
            fi
        else
            print_warning "Skipped api_keys.sh creation"
        fi
    else
        print_warning "No api_keys.sh.template found"
    fi
}

print_summary() {
    if [ "$PLAN_MODE" = true ]; then
        print_header "Installation Plan Complete!"
        echo -e "  ${GREEN}Symlinks planned:${NC} $SYMLINKS_PLANNED"
        echo -e "  ${YELLOW}Backups planned:${NC} $BACKUPS_PLANNED"
    else
        print_header "Installation Complete!"
        echo -e "  ${GREEN}Symlinks created:${NC} $SYMLINKS_CREATED"
    fi
    echo -e "  ${YELLOW}Symlinks skipped:${NC} $SYMLINKS_SKIPPED"

    if [ "$PLAN_MODE" = true ] && [ "$BACKUPS_PLANNED" -gt 0 ]; then
        echo ""
        echo -e "  ${YELLOW}Backup directory:${NC} $BACKUP_DIR"
        echo -e "  Existing files would be moved there before applying changes."
    elif [ -d "$BACKUP_DIR" ]; then
        echo ""
        echo -e "  ${YELLOW}Backup directory:${NC} $BACKUP_DIR"
        echo -e "  Files that were replaced have been backed up there."
    fi

    echo ""
    if [ "$PLAN_MODE" = true ]; then
        print_info "Preview only. No files were modified."
        echo ""
        echo -e "${BOLD}Next steps:${NC}"
        echo "  1. Review the planned actions above"
        echo "  2. Re-run ./install.sh without --plan to apply them"
        echo ""
        print_success "Plan complete"
    else
        echo -e "${BOLD}Next steps:${NC}"
        echo "  1. Restart your terminal or run: source ~/.zshrc"
        echo "  2. Run 'doctor' to verify the installed state"
        echo "  3. Open Neovim to let LazyVim install plugins automatically"
        echo "  4. In tmux, press prefix + I to install tmux plugins"
        echo "  5. Run 'brew-sync --check' to verify Brewfile is in sync"
        echo ""
        print_success "Happy coding!"
    fi
}

#==============================================================================
# Main Script
#==============================================================================

SYMLINKS_CREATED=0
SYMLINKS_PLANNED=0
SYMLINKS_SKIPPED=0
BACKUPS_PLANNED=0

parse_args "$@"

if [ "$CLEAR_SCREEN" = true ] && [ -t 1 ]; then
    clear
fi

print_header "Dotfiles Installation Wizard"

echo "Welcome! This wizard will help you set up your dotfiles."
echo "Each step will be explained and you'll be asked for confirmation."
echo ""
echo -e "  ${BOLD}Dotfiles directory:${NC} $DOTFILES_DIR"
echo -e "  ${BOLD}Home directory:${NC}     $HOME"
echo -e "  ${BOLD}Backup directory:${NC}   $BACKUP_DIR (if needed)"
if [ "$PLAN_MODE" = true ]; then
    echo -e "  ${BOLD}Mode:${NC}               Preview only (--plan)"
fi
echo ""

if ! ask_yes_no "Ready to begin?"; then
    echo "Installation cancelled."
    exit 0
fi

install_oh_my_zsh
install_tpm
install_homebrew
install_config_symlinks
install_home_symlinks
install_api_keys_template
print_summary
