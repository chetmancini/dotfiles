#!/usr/bin/env bats

setup() {
    load helpers.bash
    TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-profiles.XXXXXX")"
    export HOME="$TEST_ROOT/home"
    mkdir -p "$HOME" "$TEST_ROOT/bin"
    export PATH="$TEST_ROOT/bin:$PATH"
    export PACKAGE_LOG="$TEST_ROOT/packages"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

platform() {
    printf '#!/bin/sh\necho %s\n' "$1" >"$TEST_ROOT/bin/uname"
    chmod +x "$TEST_ROOT/bin/uname"
}

install_profile() {
    run "$DOTFILES_DIR/install.sh" --yes --skip-packages --skip-tpm --skip-api-keys --skip-hooks --no-clear "$@"
    [ "$status" -eq 0 ]
}

@test "each profile installs only its links and passes doctor on both platforms" {
    for os in Linux Darwin; do
        platform "$os"
        for profile in minimal development desktop; do
            export HOME="$TEST_ROOT/$os-$profile"
            mkdir -p "$HOME"
            install_profile --profile "$profile"
            [ -L "$HOME/.zshrc" ]
            [ "$(cat "$HOME/.config/dotfiles/profile")" = "$profile" ]
            if [ "$profile" = minimal ]; then
                [ ! -e "$HOME/.config/nvim" ]
                [ ! -e "$HOME/.npm-global" ]
            else
                [ -L "$HOME/.config/nvim" ]
            fi
            if [ "$profile" = desktop ]; then
                [ -L "$HOME/.config/ghostty" ]
            else
                [ ! -e "$HOME/.config/ghostty" ]
            fi
            if [ "$os" = Linux ]; then
                [ ! -e "$HOME/.bashrc" ]
            else
                [ -L "$HOME/.bashrc" ]
            fi
            run "$DOTFILES_DIR/bin/doctor" --skip-tools
            [ "$status" -eq 0 ]
        done
    done
}

@test "Linux defaults preserve Omarchy Bash and terminal configuration" {
    platform Linux
    mkdir -p "$HOME/.config/ghostty"
    echo omarchy >"$HOME/.bashrc"
    echo theme >"$HOME/.config/ghostty/config"
    install_profile
    [ "$(cat "$HOME/.bashrc")" = omarchy ]
    [ "$(cat "$HOME/.config/ghostty/config")" = theme ]
    [ "$(cat "$HOME/.config/dotfiles/profile")" = development ]
}

@test "plan and invalid profile leave home untouched" {
    platform Linux
    install_profile --profile minimal --plan
    [ -z "$(ls -A "$HOME")" ]
    run "$DOTFILES_DIR/install.sh" --profile bogus --yes
    [ "$status" -ne 0 ]
    [ -z "$(ls -A "$HOME")" ]
}

@test "Arch install uses cumulative native packages and preview never executes sudo" {
    platform Linux
    printf '#!/bin/sh\nexit 0\n' >"$TEST_ROOT/bin/pacman"
    printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "$PACKAGE_LOG"\n' >"$TEST_ROOT/bin/sudo"
    chmod +x "$TEST_ROOT/bin/pacman" "$TEST_ROOT/bin/sudo"
    run "$DOTFILES_DIR/install.sh" --profile development --plan --yes --skip-tpm --skip-api-keys --skip-hooks --no-clear
    [ "$status" -eq 0 ]
    [[ "$output" == *"sudo pacman -S --needed"* ]]
    [ ! -e "$PACKAGE_LOG" ]
    run "$DOTFILES_DIR/install.sh" --profile development --yes --skip-tpm --skip-api-keys --skip-hooks --no-clear
    [ "$status" -eq 0 ]
    grep -qx git "$PACKAGE_LOG"
    grep -qx neovim "$PACKAGE_LOG"
    grep -qx wl-clipboard "$PACKAGE_LOG"
    run grep -qx ghostty "$PACKAGE_LOG"
    [ "$status" -eq 1 ]
    run grep -qx -- -Sy "$PACKAGE_LOG"
    [ "$status" -eq 1 ]
}

@test "Mac development excludes all desktop casks from Homebrew" {
    platform Darwin
    cat >"$TEST_ROOT/bin/brew" <<'BREW'
#!/bin/sh
if [ "$1" = bundle ]; then
    printf '%s\n' "$HOMEBREW_BUNDLE_CASK_SKIP" > "$PACKAGE_LOG"
fi
BREW
    chmod +x "$TEST_ROOT/bin/brew"
    run "$DOTFILES_DIR/install.sh" --profile development --yes --skip-tpm --skip-api-keys --skip-hooks --no-clear
    [ "$status" -eq 0 ]
    grep -q ghostty "$PACKAGE_LOG"
    grep -q font-hack "$PACKAGE_LOG"
}

@test "Linux rejects optional Mac packages before installing anything" {
    platform Linux
    run "$DOTFILES_DIR/install.sh" --yes --with-optional-brew
    [ "$status" -ne 0 ]
    [ -z "$(ls -A "$HOME")" ]
}

@test "Linux pnpm paths preserve custom settings and use XDG defaults" {
    run env DOTFILES_DIR="$DOTFILES_DIR" zsh -fc '
        OSTYPE=linux-gnu
        unset PNPM_HOME JAVA_HOME
        export XDG_DATA_HOME="$HOME/data"
        mkdir -p "$XDG_DATA_HOME/pnpm"
        source "$DOTFILES_DIR/zsh/path.zsh"
        [[ "$PNPM_HOME" = "$HOME/data/pnpm" ]] || exit 1
        [[ ":$PATH:" = *":$PNPM_HOME:"* ]] || exit 1
        export PNPM_HOME="$HOME/custom"
        source "$DOTFILES_DIR/zsh/path.zsh"
        [[ "$PNPM_HOME" = "$HOME/custom" ]]
    '
    [ "$status" -eq 0 ]
}

@test "reinstall retains the saved minimal profile on both platforms" {
    for os in Linux Darwin; do
        platform "$os"
        export HOME="$TEST_ROOT/reinstall-$os"
        mkdir -p "$HOME"
        install_profile --profile minimal
        install_profile
        [ "$(cat "$HOME/.config/dotfiles/profile")" = minimal ]
        [ ! -e "$HOME/.config/nvim" ]
        [ ! -e "$HOME/.config/ghostty" ]
    done
}

@test "explicit profile overrides saved state while preview preserves it" {
    platform Linux
    install_profile --profile minimal
    install_profile --profile development --plan
    [[ "$output" == *"profile: development"* ]]
    [ "$(cat "$HOME/.config/dotfiles/profile")" = minimal ]
    [ ! -e "$HOME/.config/nvim" ]
    install_profile --profile development
    [ "$(cat "$HOME/.config/dotfiles/profile")" = development ]
    [ -L "$HOME/.config/nvim" ]
}

@test "saved profile without a trailing newline is accepted" {
    platform Linux
    mkdir -p "$HOME/.config/dotfiles"
    printf minimal >"$HOME/.config/dotfiles/profile"
    install_profile --plan
    [[ "$output" == *"profile: minimal"* ]]
    [ ! -e "$HOME/.zshrc" ]
}

@test "invalid saved profiles stop installation and can be explicitly repaired" {
    platform Linux
    mkdir -p "$HOME/.config/dotfiles"
    for invalid in bogus ''; do
        printf '%s' "$invalid" >"$HOME/.config/dotfiles/profile"
        run "$DOTFILES_DIR/install.sh" --yes --skip-packages --skip-tpm --skip-api-keys --skip-hooks --no-clear
        [ "$status" -ne 0 ]
        [[ "$output" == *"Invalid install profile"* ]]
        [ ! -e "$HOME/.zshrc" ]
        [ "$(cat "$HOME/.config/dotfiles/profile")" = "$invalid" ]
    done
    install_profile --profile minimal
    [ "$(cat "$HOME/.config/dotfiles/profile")" = minimal ]
    [ -L "$HOME/.zshrc" ]
}
