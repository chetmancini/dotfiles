#!/bin/bash

# helpers.sh: Shared functions for dotfiles scripts
# Source this file in other scripts: source "$(dirname "$0")/lib/helpers.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Global verbose flag (can be set by sourcing script)
VERBOSE=${VERBOSE:-false}

print_section() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

print_error() {
    echo -e "${RED}  ✗ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

# Print a clickable hyperlink using OSC 8 escape sequence
# Usage: print_link "url" "text"
print_link() {
    local url="$1"
    local text="$2"
    printf '\e]8;;%s\e\\%s\e]8;;\e\\\n' "$url" "$text"
}

# Run a command with a spinner (quiet mode) or show output (verbose mode)
# Usage: run_with_spinner "message" command args...
run_with_spinner() {
    local message="$1"
    shift

    if [ "$VERBOSE" = true ]; then
        # Verbose mode: just run the command with output
        "$@"
        return $?
    fi

    # Quiet mode: show spinner while command runs
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local pid
    local i=0

    # Run command in background, capture output
    local tmpfile
    tmpfile=$(mktemp)

    # Set up cleanup trap for temp file
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile'" EXIT INT TERM

    "$@" > "$tmpfile" 2>&1 &
    pid=$!

    # Show spinner while waiting
    printf "  %s " "$message"
    while kill -0 "$pid" 2>/dev/null; do
        printf "\b%s" "${spin_chars:i++%${#spin_chars}:1}"
        sleep 0.1
    done

    # Get exit status
    wait "$pid"
    local status=$?

    # Clear spinner
    printf "\b \b"
    printf "\r"

    # Clean up (trap will also clean up on signals)
    rm -f "$tmpfile"
    trap - EXIT INT TERM
    return $status
}
