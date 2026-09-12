#!/usr/bin/env bats

setup() {
    load helpers.bash
    setup_temp_home
}

teardown() {
    teardown_temp_home
}

check_clipboard() {
    local platform="$1" wayland="$2" x11="$3" expected="$4" expected_status="${5:-0}"
    local shell config
    for shell in bash zsh; do
        config="$DOTFILES_DIR/.bashrc"
        [ "$shell" = zsh ] && config="$DOTFILES_DIR/zsh/git.zsh"
        run "$shell" -fc '
            source "$1"
            export WAYLAND_DISPLAY="$3" DISPLAY="$4"
            # Functions share the requested platform through an outer variable.
            platform="$2"
            uname() { printf "%s\n" "$platform"; }
            pbcopy() { printf pbcopy; }
            wl-copy() { printf wl-copy; }
            xclip() { printf xclip; }
            xsel() { printf xsel; }
            _clipboard_copy
        ' -- "$config" "$platform" "$wayland" "$x11"
        [ "$status" -eq "$expected_status" ]
        [[ "$output" == *"$expected"* ]]
    done
}

@test "macOS uses pbcopy even with display variables present" {
    check_clipboard Darwin wayland-0 :0 pbcopy
}

@test "Wayland prefers wl-copy when XWayland is also present" {
    check_clipboard Linux wayland-0 :0 wl-copy
}

@test "X11 ignores an installed Wayland clipboard utility" {
    check_clipboard Linux '' :0 xclip
}

@test "headless sessions report a missing display instead of launching clipboard tools" {
    check_clipboard Linux '' '' 'No clipboard utility available for this display session' 1
}
