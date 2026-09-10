#!/usr/bin/env bash
set -euo pipefail

#==============================================================================
# Dotfiles Installation Wizard
#==============================================================================

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"

# shellcheck source=bin/lib/symlinks.sh
source "$SCRIPT_DIR/bin/lib/symlinks.sh"
# shellcheck source=bin/lib/transactions.sh
source "$SCRIPT_DIR/bin/lib/transactions.sh"

AUTO_YES=false
SKIP_TPM=false
SKIP_BREW=false
WITH_OPTIONAL_BREW=false
WITH_LEGACY_VIM=false
SKIP_API_KEYS=false
SKIP_HOOKS=false
CLEAR_SCREEN=true
PLAN_MODE=false

# Keep confirmations on the original input stream. Manifest loops temporarily
# redirect stdin, and prompts must never consume manifest records.
exec 9<&0

CURRENT_TRANSACTION_ID=""
CURRENT_TRANSACTION_DIR=""
TRANSACTION_SEQUENCE=0
INSTALL_SUCCESS=false

# Isolate installer git operations from any caller/hook git environment
unset GIT_INDEX_FILE

cleanup_install_trap() {
    local exit_code=$?
    if [ "$INSTALL_SUCCESS" != true ] && [ -n "${CURRENT_TRANSACTION_DIR:-}" ] && [ -d "$CURRENT_TRANSACTION_DIR" ]; then
        local meta_file="$CURRENT_TRANSACTION_DIR/metadata"
        if [ -f "$meta_file" ]; then
            local state
            state="$(grep '^state=' "$meta_file" 2>/dev/null | cut -d'=' -f2 || true)"
            if [ "$state" = "in_progress" ]; then
                update_transaction_state "$CURRENT_TRANSACTION_DIR" "failed" 2>/dev/null || true
            fi
        fi
    fi
    exit "$exit_code"
}
trap cleanup_install_trap EXIT
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
  --yes                 Run non-interactively and accept all prompts
  --plan, --dry-run     Preview changes without modifying files
  --skip-tpm            Skip tmux plugin manager installation
  --skip-brew           Skip Homebrew package installation
  --with-optional-brew  Also install Brewfile.optional (default off under --yes)
  --with-legacy-vim     Symlink legacy Vim runtime/config (default off under --yes)
  --skip-api-keys       Skip creating secrets stubs from templates
  --skip-hooks          Skip installing git pre-commit hook
  --no-clear            Do not clear the screen before starting
  -h, --help            Show this help message
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
            --skip-tpm)
                SKIP_TPM=true
                shift
                ;;
            --skip-brew)
                SKIP_BREW=true
                shift
                ;;
            --with-optional-brew)
                WITH_OPTIONAL_BREW=true
                shift
                ;;
            --with-legacy-vim)
                WITH_LEGACY_VIM=true
                shift
                ;;
            --skip-api-keys)
                SKIP_API_KEYS=true
                shift
                ;;
            --skip-hooks)
                SKIP_HOOKS=true
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
        if ! read -r -u 9 -p "$prompt" answer; then
            print_warning "No confirmation input available; refusing this action"
            return 1
        fi
        answer="${answer:-$default}"
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Validate tracked sources before any managed target can be replaced.
validate_managed_sources() {
    local group source_rel target_rel _install_name _doctor_label _description
    local missing=0

    for group in config home legacy; do
        while IFS='|' read -r source_rel target_rel _install_name _doctor_label _description; do
            if [ ! -e "$DOTFILES_DIR/$source_rel" ]; then
                print_error "Managed source is missing: $DOTFILES_DIR/$source_rel"
                missing=$((missing + 1))
            fi
            if ! validate_target_ancestors_install "$target_rel"; then
                print_error "Target ancestor for $target_rel is a symlink or invalid directory"
                missing=$((missing + 1))
            fi
        done < <(managed_symlinks_for_group "$group")
    done

    if [ "$missing" -gt 0 ]; then
        print_error "Refusing to install with $missing invalid managed source/target precondition(s)"
        return 1
    fi
}

inspect_target() {
    local target="$1"
    local raw

    TARGET_PRIOR_VALUE=
    if [ -L "$target" ]; then
        TARGET_KIND="symlink"
        raw="$(
            readlink -n "$target"
            printf x
        )"
        TARGET_PRIOR_VALUE="${raw%x}"
        if [[ "$TARGET_PRIOR_VALUE" == *$'\n'* || "$TARGET_PRIOR_VALUE" == *$'\r'* || "$TARGET_PRIOR_VALUE" == *'|'* ]]; then
            echo "Error: unsupported characters in symlink target at $target" >&2
            return 1
        fi
    elif [ -f "$target" ]; then
        TARGET_KIND="file"
    elif [ -d "$target" ]; then
        TARGET_KIND="directory"
    elif [ ! -e "$target" ]; then
        TARGET_KIND="absent"
    else
        echo "Error: unsupported filesystem object at $target" >&2
        return 1
    fi
}

# Create a symlink with explanation and transactional safety.
create_symlink() {
    local source_rel="$1"
    local target_rel="$2"
    local name="$3"
    local description="$4"
    local source="$DOTFILES_DIR/$source_rel"
    local target="$HOME/$target_rel"

    validate_relative_path "$target_rel" || {
        echo "Error: invalid relative target path: $target_rel" >&2
        exit 1
    }
    validate_relative_path "$source_rel" || {
        echo "Error: invalid relative source path: $source_rel" >&2
        exit 1
    }
    validate_target_ancestors_install "$target_rel" || {
        echo "Error: target ancestor for $target_rel is a symlink or invalid directory" >&2
        exit 1
    }

    echo ""
    print_step "${BOLD}$name${NC}"
    print_info "$description"
    print_info "Source: $source"
    print_info "Target: $target"

    if [ ! -e "$source" ]; then
        print_error "Managed source is missing; target left unchanged"
        return 1
    fi

    if [ -L "$target" ] && is_managed_symlink "$target" "$source"; then
        print_success "Already correctly symlinked"
        return 0
    fi

    inspect_target "$target"

    if ask_yes_no "  Create this symlink?"; then
        validate_target_ancestors_install "$target_rel" || {
            echo "Error: target ancestor for $target_rel changed while awaiting confirmation" >&2
            return 1
        }
        if [ -L "$target" ] && is_managed_symlink "$target" "$source"; then
            print_success "Already correctly symlinked"
            return 0
        fi
        # Confirmation may have taken arbitrarily long. Inspect again before
        # writing a journal record or changing the target.
        inspect_target "$target"

        if [ "$PLAN_MODE" = true ]; then
            case "$TARGET_KIND" in
                file | directory)
                    print_plan "Would back up existing $name to transaction payload"
                    BACKUPS_PLANNED=$((BACKUPS_PLANNED + 1))
                    ;;
                symlink)
                    print_plan "Existing symlink found, would replace it"
                    ;;
                absent) ;;
            esac
            if [ ! -d "$(dirname "$target")" ]; then
                print_plan "Would create parent directory $(dirname "$target")"
            fi
            print_success "Symlink would be created"
            SYMLINKS_PLANNED=$((SYMLINKS_PLANNED + 1))
            return 0
        fi

        # Lazily create transaction on the first target that actually needs a change
        if [ -z "$CURRENT_TRANSACTION_ID" ]; then
            local root
            root="$(transaction_backup_root)"
            if [ -L "$root" ] || { [ -e "$root" ] && [ ! -d "$root" ]; }; then
                echo "Error: backup root at $root is invalid or symlinked" >&2
                exit 1
            fi
            CURRENT_TRANSACTION_ID="$(generate_transaction_id)" || {
                echo "Error: failed to generate transaction ID" >&2
                exit 1
            }
            CURRENT_TRANSACTION_DIR="$root/$CURRENT_TRANSACTION_ID"
            mkdir -p "$CURRENT_TRANSACTION_DIR/payload"
            local repo_rev
            repo_rev="$(git -C "$DOTFILES_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")"
            local created_at
            created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            write_transaction_metadata "$CURRENT_TRANSACTION_DIR" "$CURRENT_TRANSACTION_ID" "$created_at" "$repo_rev" "in_progress" || {
                echo "Error: failed to write transaction metadata" >&2
                exit 1
            }
        fi

        TRANSACTION_SEQUENCE=$((TRANSACTION_SEQUENCE + 1))
        local seq
        seq="$(printf "%04d" "$TRANSACTION_SEQUENCE")"

        local prior_value="$TARGET_PRIOR_VALUE"
        case "$TARGET_KIND" in
            file | directory)
                prior_value="payload/$seq"
                ;;
        esac

        # Append and flush journal record before any move, removal, or link creation
        append_journal_entry "$CURRENT_TRANSACTION_DIR" "$seq" "$target_rel" "$TARGET_KIND" "$prior_value" "$source_rel" || {
            echo "Error: failed to append journal entry for $target_rel" >&2
            exit 1
        }

        # After the record is durable, move prior file/directory or remove prior symlink
        case "$TARGET_KIND" in
            file | directory)
                mv "$target" "$CURRENT_TRANSACTION_DIR/payload/$seq"
                print_warning "Backed up existing $name to $CURRENT_TRANSACTION_DIR/payload/$seq"
                ;;
            symlink)
                rm -f "$target"
                print_info "Existing symlink found, replaced"
                ;;
            absent) ;;
        esac

        mkdir -p "$(dirname "$target")"
        ln -s "$source" "$target"
        print_success "Symlink created"
        SYMLINKS_CREATED=$((SYMLINKS_CREATED + 1))
    else
        print_warning "Skipped"
        SYMLINKS_SKIPPED=$((SYMLINKS_SKIPPED + 1))
    fi
}

install_tpm() {
    print_header "Step 1: Tmux Plugin Manager"

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
            env -u GIT_INDEX_FILE -u GIT_DIR -u GIT_WORK_TREE git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
            print_success "TPM installed"
        fi
        print_info "After setup, press prefix + I in tmux to install plugins"
    else
        print_warning "Skipped TPM installation"
    fi
}

install_homebrew() {
    print_header "Step 2: Homebrew Packages"

    echo "Core CLI/dev tools install from Brewfile."
    echo "Optional apps/tools are in Brewfile.optional (opt-in)."
    echo ""

    if [ "$SKIP_BREW" = true ]; then
        print_warning "Skipping Homebrew package installation by request"
        return 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
        print_warning "Homebrew is not installed. Skipping package installation."
        print_info "Install Homebrew from https://brew.sh"
        return 0
    fi

    if ask_yes_no "Install/update core Homebrew packages from Brewfile?"; then
        if [ "$PLAN_MODE" = true ]; then
            print_step "Would run: brew update"
            print_step "Would run: brew bundle --file=\"$DOTFILES_DIR/Brewfile\""
            print_success "Core Homebrew package install planned"
        else
            print_step "Updating Homebrew..."
            brew update
            print_step "Installing core packages from Brewfile..."
            brew bundle --file="$DOTFILES_DIR/Brewfile"
            print_success "Core Homebrew packages installed"
        fi
    else
        print_warning "Skipped core Homebrew packages"
    fi

    # Optional profile: default No under --yes (keep CI/bootstrap light).
    local install_optional=false
    if [ "$WITH_OPTIONAL_BREW" = true ]; then
        install_optional=true
    elif [ "$AUTO_YES" = true ]; then
        print_info "Skipping optional Brewfile.optional under --yes (pass --with-optional-brew to include)"
    elif ask_yes_no "Install optional Brew packages (Brewfile.optional)?" "n"; then
        install_optional=true
    fi

    if [ "$install_optional" = true ]; then
        if [ ! -f "$DOTFILES_DIR/Brewfile.optional" ]; then
            print_warning "Brewfile.optional not found; skipping optional packages"
            return 0
        fi
        if [ "$PLAN_MODE" = true ]; then
            print_step "Would run: brew bundle --file=\"$DOTFILES_DIR/Brewfile.optional\""
            print_success "Optional Homebrew package install planned"
        else
            print_step "Installing optional packages from Brewfile.optional..."
            brew bundle --file="$DOTFILES_DIR/Brewfile.optional"
            print_success "Optional Homebrew packages installed"
        fi
    else
        print_info "Optional packages skipped (brew bundle --file=~/dotfiles/Brewfile.optional later)"
    fi
}

install_config_symlinks() {
    print_header "Step 3: Config Directory Symlinks"

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
            "$source_rel" \
            "$target_rel" \
            "$install_name" \
            "$description"
    done < <(managed_symlinks_for_group config)
}

install_home_symlinks() {
    print_header "Step 4: Home Directory Symlinks"

    echo "These symlinks set up git, shell, and related files in your home directory."
    echo "Legacy Vim is optional (primary editor is Neovim + Ghostty)."
    echo ""

    while IFS='|' read -r source_rel target_rel install_name _doctor_label description; do
        create_symlink \
            "$source_rel" \
            "$target_rel" \
            "$install_name" \
            "$description"
    done < <(managed_symlinks_for_group home)

    # npm's portable user-level prefix is managed by npm/npmrc. Create it here
    # so npm list/update work on a freshly bootstrapped machine before its first
    # global install.
    if [ "$PLAN_MODE" = true ]; then
        print_plan "Would create npm global prefix directory $HOME/.npm-global"
    else
        mkdir -p "$HOME/.npm-global"
        print_success "npm global prefix directory exists: $HOME/.npm-global"
    fi

    # Legacy Vim: default No under --yes; opt in with --with-legacy-vim or interactive yes.
    local install_legacy_vim=false
    if [ "$WITH_LEGACY_VIM" = true ]; then
        install_legacy_vim=true
    elif [ "$AUTO_YES" = true ]; then
        print_info "Skipping legacy Vim symlinks under --yes (pass --with-legacy-vim to include)"
    elif ask_yes_no "Install legacy Vim runtime/config symlinks?" "n"; then
        install_legacy_vim=true
    fi

    if [ "$install_legacy_vim" = true ]; then
        print_header "Step 4b: Legacy Vim Symlinks"
        while IFS='|' read -r source_rel target_rel install_name _doctor_label description; do
            create_symlink \
                "$source_rel" \
                "$target_rel" \
                "$install_name" \
                "$description"
        done < <(managed_symlinks_for_group legacy)
    fi
}

install_api_keys_template() {
    print_header "Step 5: Secrets Setup (1Password preferred)"

    echo "Secrets are gitignored. Prefer 1Password CLI (api_keys_1password.sh)."
    echo "Plaintext api_keys.sh is bootstrap-only for machines without 1Password."
    echo ""

    if [ "$SKIP_API_KEYS" = true ]; then
        print_warning "Skipping secrets template setup by request"
        return 0
    fi

    local has_plaintext=false
    local has_1p=false
    [ -f "$DOTFILES_DIR/api_keys.sh" ] && has_plaintext=true
    [ -f "$DOTFILES_DIR/api_keys_1password.sh" ] && has_1p=true

    if [ "$has_1p" = true ]; then
        print_success "api_keys_1password.sh already exists (preferred)"
    fi
    if [ "$has_plaintext" = true ]; then
        print_info "api_keys.sh present (bootstrap/plaintext path)"
        if [ "$has_1p" = true ]; then
            print_info "Both files exist: 1Password file loads second and can override"
        fi
    fi

    # Preferred: 1Password-backed stub
    if [ "$has_1p" = false ] && [ -f "$DOTFILES_DIR/api_keys_1password.sh.template" ]; then
        local create_1p=false
        if [ "$AUTO_YES" = true ]; then
            # Headless default: 1Password stub (not plaintext)
            create_1p=true
            print_info "Creating api_keys_1password.sh from template (--yes default)"
        elif ask_yes_no "Create preferred api_keys_1password.sh from template?" "y"; then
            create_1p=true
        fi

        if [ "$create_1p" = true ]; then
            if [ "$PLAN_MODE" = true ]; then
                print_step "Would copy api_keys_1password.sh.template → api_keys_1password.sh"
                print_success "1Password secrets stub planned"
            else
                cp "$DOTFILES_DIR/api_keys_1password.sh.template" "$DOTFILES_DIR/api_keys_1password.sh"
                print_success "Created api_keys_1password.sh from template"
            fi
            print_info "Next: enable 1Password app CLI integration, unlock app, edit op:// refs"
            print_info "Check session with: op whoami"
            has_1p=true
        else
            print_warning "Skipped api_keys_1password.sh creation"
        fi
    elif [ "$has_1p" = false ]; then
        print_warning "No api_keys_1password.sh.template found"
    fi

    # Fallback: plaintext bootstrap (interactive only unless neither 1P path possible)
    if [ "$has_plaintext" = false ] && [ -f "$DOTFILES_DIR/api_keys.sh.template" ]; then
        local create_plain=false
        if [ "$AUTO_YES" = true ]; then
            # Under --yes we already prefer 1P; only create plaintext if 1P stub missing
            if [ "$has_1p" = false ]; then
                create_plain=true
                print_info "Creating bootstrap api_keys.sh (--yes, no 1Password stub available)"
            fi
        elif [ "$has_1p" = true ]; then
            if ask_yes_no "Also create bootstrap api_keys.sh (plaintext, not recommended)?" "n"; then
                create_plain=true
            fi
        elif ask_yes_no "Create bootstrap api_keys.sh from template (no 1Password)?" "n"; then
            create_plain=true
        fi

        if [ "$create_plain" = true ]; then
            if [ "$PLAN_MODE" = true ]; then
                print_step "Would copy api_keys.sh.template → api_keys.sh"
                print_success "Plaintext secrets stub planned"
            else
                cp "$DOTFILES_DIR/api_keys.sh.template" "$DOTFILES_DIR/api_keys.sh"
                print_success "Created api_keys.sh from template"
                print_info "Prefer migrating to api_keys_1password.sh when possible"
            fi
        fi
    fi
}

install_git_hooks() {
    print_header "Step 6: Git Hooks"

    echo "Pre-commit hook runs 'make check' (formatting, lint, bats) before each commit."
    echo "Bypass per-commit with: SKIP_HOOK=1 git commit  or  git commit --no-verify"
    echo ""

    if [ "$SKIP_HOOKS" = true ]; then
        print_warning "Skipping git hooks by request (--skip-hooks)"
        return 0
    fi

    if [ "$PLAN_MODE" = true ]; then
        if [ -f "$DOTFILES_DIR/scripts/pre-commit" ]; then
            print_plan "Would install pre-commit hook to .git/hooks/pre-commit"
            print_success "Git hook install planned"
        else
            print_warning "scripts/pre-commit not found; skipping hook install"
        fi
        return 0
    fi

    if [ ! -f "$DOTFILES_DIR/scripts/install-hooks.sh" ]; then
        print_warning "scripts/install-hooks.sh not found; skipping hook install"
        return 0
    fi

    local hook_status=0
    bash "$DOTFILES_DIR/scripts/install-hooks.sh" || hook_status=$?
    case "$hook_status" in
        0) print_success "Git pre-commit hook installed" ;;
        2) print_warning "Git hook installation skipped (see output above)" ;;
        *) print_warning "Git hook install failed (see output above)" ;;
    esac
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
        echo -e "  ${YELLOW}Backup directory:${NC} $(transaction_backup_root)"
        echo -e "  Existing files would be moved there before applying changes."
    elif [ -n "$CURRENT_TRANSACTION_ID" ]; then
        echo ""
        echo -e "  ${YELLOW}Backup directory:${NC} $CURRENT_TRANSACTION_DIR"
        echo -e "  Files that were replaced have been backed up there."
        echo ""
        echo -e "  ${YELLOW}Transaction:${NC} $CURRENT_TRANSACTION_ID"
        echo -e "  ${YELLOW}Restore preview:${NC} dot restore --plan $CURRENT_TRANSACTION_ID"
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
        echo "  3. Open Neovim — plugins sync via vim.pack on first launch (may take a moment)"
        echo "  4. In tmux, press prefix + I to install tmux plugins"
        echo "  5. Run 'brew-sync --check' to verify core Brewfile is in sync"
        echo "  6. Optional apps: brew bundle --file=~/dotfiles/Brewfile.optional"
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
echo -e "  ${BOLD}Backup root:${NC}        $(transaction_backup_root) (if needed)"
if [ "$PLAN_MODE" = true ]; then
    echo -e "  ${BOLD}Mode:${NC}               Preview only (--plan)"
fi
echo ""

if ! ask_yes_no "Ready to begin?"; then
    echo "Installation cancelled."
    exit 0
fi

if [ "$PLAN_MODE" != true ]; then
    early_tx_root="$(transaction_backup_root)"
    if [ -L "$early_tx_root" ] || { [ -e "$early_tx_root" ] && [ ! -d "$early_tx_root" ]; }; then
        echo "Error: backup root at $early_tx_root is invalid or symlinked" >&2
        exit 1
    fi
fi

validate_managed_sources

install_tpm
install_homebrew
install_config_symlinks
install_home_symlinks
install_api_keys_template
install_git_hooks

if [ "$PLAN_MODE" != true ] && [ -n "$CURRENT_TRANSACTION_DIR" ] && [ -d "$CURRENT_TRANSACTION_DIR" ]; then
    update_transaction_state "$CURRENT_TRANSACTION_DIR" "complete" "$TRANSACTION_SEQUENCE" || {
        echo "Error: failed to mark transaction complete" >&2
        exit 1
    }
    tx_root="$(transaction_backup_root)"
    tx_tmp_latest="$(mktemp "$tx_root/latest.tmp.XXXXXX")"
    printf "%s\n" "$CURRENT_TRANSACTION_ID" >"$tx_tmp_latest"
    mv -f "$tx_tmp_latest" "$tx_root/latest"
fi
INSTALL_SUCCESS=true

print_summary
