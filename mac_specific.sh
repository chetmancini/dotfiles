notify() {
    body=${1-'Demo notification\nsyntax: notify "title" "body"'}
    title=${2-'Terminal notification'}
    osascript -e "display notification \"${body//\"/\\\"}\" with title \"${title//\"/\\\"}\""
}
