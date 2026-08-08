##############################
# fun
##############################

# Show current WiFi password (macOS only)
function wifi-password() {
    if [[ "$(uname)" != "Darwin" ]]; then
        echo "macOS only" >&2
        return 1
    fi
    local ssid
    ssid=$(/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I | awk -F': ' '/ SSID/{print $2}')
    if [[ -z "$ssid" ]]; then
        echo "Not connected to WiFi" >&2
        return 1
    fi
    echo "SSID: $ssid"
    security find-generic-password -D "AirPort network password" -wa "$ssid"
}

# System info on login shells only (not every new terminal tab)
# Run 'fastfetch' manually to see system info
if [[ -o login ]] && command -v fastfetch &> /dev/null; then
  fastfetch
fi

if [[ "$TERM_PROGRAM" == "kiro" ]] && command -v kiro &> /dev/null; then
  . "$(kiro --locate-shell-integration-path zsh)"
fi

##############################
# Terminal Screensaver
##############################
# cmatrix after 15 min of idle (900 seconds)
if command -v cmatrix &> /dev/null; then
  TMOUT=900
  TRAPALRM() {
    # Only run if terminal is idle (no background jobs, no text in prompt)
    if [[ -z "$(jobs)" ]] && [[ -z "$BUFFER" ]]; then
      cmatrix -s  # -s exits on any keypress
      zle reset-prompt 2>/dev/null
    fi
  }
fi
