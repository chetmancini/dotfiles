##############################
# Generic Tools
##############################
function lt() { eza -la --sort=modified "$@" | tail; }
function psgrep() { ps axuf | grep -v grep | grep "$@" -i --color=auto; }
function fname() { fd --ignore-case "$@"; }  # Uses fd for fast searching
function take() { mkdir -p "$1" && builtin cd "$1" || return; }

function strip_quotes() { sed 's/\"//g' "$@"; }

# These commands are now in bin/ with better error handling:
#   server, killbyname, dtgz


function removeFromPath() {
    local target="$1"
    local dir
    local -a new_path

    [[ -z "$target" ]] && return 0

    for dir in "${path[@]}"; do
        [[ "$dir" == "$target" ]] || new_path+=("$dir")
    done

    path=("${new_path[@]}")
    export PATH
}

function setjdk() {
  local new_java_home

  (( $# == 0 )) && return 0

  removeFromPath '/System/Library/Frameworks/JavaVM.framework/Home/bin'
  if [[ -n "${JAVA_HOME:-}" ]]; then
    removeFromPath "$JAVA_HOME"
    removeFromPath "$JAVA_HOME/bin"
  fi

  new_java_home="$(/usr/libexec/java_home -v "$@")" || return 1
  export JAVA_HOME="$new_java_home"
  path=("$JAVA_HOME/bin" "${path[@]}")
  export PATH
}

# Quick weather from wttr.in
function weather() {
    local location="${1:-}"
    curl -s "wttr.in/${location}?F"
}

function xtitle()      # Adds some text in the terminal frame.
{
    case "$TERM" in
        *term | rxvt)
            echo -n -e "\033]0;$*\007" ;;
        *)
            ;;
    esac
}

##############################
# Stupid shortcuts
##############################
function svim {
    sudo vim "$@"
}

# Find a file with a pattern in name:
function ff() { fd --type f --ignore-case "$*" ; }

function my_ps() { ps "$@" -u $USER -o pid,%cpu,%mem,bsdtime,command ; }
function pp() { my_ps f | awk '!/awk/ && $0~var' var=${1:-".*"} ; }

# Kill by process name.
function killps()
{
    local pid pname sig="-TERM"   # Default signal.
    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "Usage: killps [-SIGNAL] pattern"
        return;
    fi
    if [ $# = 2 ]; then sig=$1 ; fi
    for pid in $(my_ps| awk '!/awk/ && $0~pat { print $1 }' pat=${!#} ) ; do
        pname=$(my_ps | awk '$1~var { print $5 }' var=$pid )
        read -p "Kill process $pid <$pname> with signal $sig?" RESP
        if [ "$RESP" = "y" ]; then
            kill $sig $pid
        fi
    done
}


# Get current host related info (macOS compatible).
function sysinfo()
{
    local RED='\033[0;31m'
    local NC='\033[0m'
    echo -e "\nYou are logged on ${RED}$HOST${NC}"
    echo -e "\n${RED}Additional information:${NC}" ; uname -a
    echo -e "\n${RED}Users logged on:${NC}" ; w -h
    echo -e "\n${RED}Current date:${NC}" ; date
    echo -e "\n${RED}Machine stats:${NC}" ; uptime
    echo -e "\n${RED}Memory stats:${NC}"
    if [[ "$(uname)" == "Darwin" ]]; then
        vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf "%-16s %8.2f MB\n", "$1:", $2 * $size / 1048576'
    else
        free -h
    fi
    echo -e "\n${RED}Local IP Address:${NC}"
    if [[ "$(uname)" == "Darwin" ]]; then
        ipconfig getifaddr en0 2>/dev/null || echo "Not connected"
    else
        ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1 | head -1 || echo "Not connected"
    fi
    echo -e "\n${RED}Public IP Address:${NC}" ; curl -s ifconfig.me 2>/dev/null || echo "Not connected"
    echo
}

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# thefuck removed from default shell (prefer zsh CORRECT + atuin history).
# Re-enable: brew install thefuck && eval $(thefuck --alias)
