notify() {
    local title="${1:-Terminal notification}"
    local body="${2:-Demo notification}"
    osascript - "$title" "$body" <<'APPLESCRIPT'
on run argv
    display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
}
