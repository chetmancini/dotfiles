#######################
# Git Aliases to make it all shorter
########################
unalias gs 2>/dev/null  # Ensure ghostscript doesn't override
alias gs='git status -sb'
alias gd='git diff'
alias gb='git branch -vv'
alias gf='git fetch --all --prune'
alias gch='git ch'
alias gadd='git a'
alias gaa='git aa'
alias gco='git commit -m'
alias gca='git commit -am'
alias grod='git rebase origin/develop'
alias gri='git ri'
alias grc='git rc'
alias glog='git log'
alias ghist='git hist'
alias gpush='git push'
alias gpushod='git push origin develop'
alias gpushom='git push origin main'
alias gdiff='git diff --color'
alias gmerge='git merge'
alias gff='git merge --ff-only'
alias gpull='git pull --prune'
alias grm="git status | grep deleted | awk '{print \$3}' | xargs git rm"
alias gamend="git commit --amend -C HEAD"
alias gclean='git clean -nd'
alias gcleanf='git checkout . && git clean -f'

# Git worktree shortcuts (Conductor and parallel-branch workflows)
alias wt='git wt'
alias wtl='git wtl'
alias wta='git wta'
alias wtr='git wtr'

# Rebase onto the remote's default branch, whatever it's named.
alias grom='git rom'

__git_files () {
    _wanted files expl 'local files' _files
}

#############################
# Random git commands for my usual branch protocol of 1234storynum_title_of_feature
#############################
# Cross-platform clipboard copy
_clipboard_copy() {
    if [[ "$(uname)" == "Darwin" ]]; then
        pbcopy
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        xsel --clipboard
    else
        echo "Error: No clipboard utility found (pbcopy, xclip, or xsel)" >&2
        return 1
    fi
}

function cpbranch() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        git rev-parse --abbrev-ref HEAD | tr -d '\n' | _clipboard_copy
    else
        echo "not in a repo" >&2
    fi
}
function cpmsg() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "[#`git rev-parse --abbrev-ref HEAD | cut -d'_' -f 1`] CM: " | tr -d '\n' | _clipboard_copy
    else
        echo "not in a repo" >&2
    fi
}
