# Git prompt helpers + custom λ theme (chetmancini.zsh-theme).

typeset -g GIT_PROMPT_INFO=""

_update_git_prompt_info() {
  local ref status_text

  GIT_PROMPT_INFO=""

  GIT_OPTIONAL_LOCKS=0 command git rev-parse --git-dir >/dev/null 2>&1 || return

  ref=$(GIT_OPTIONAL_LOCKS=0 command git symbolic-ref --quiet --short HEAD 2>/dev/null) \
    || ref=$(GIT_OPTIONAL_LOCKS=0 command git describe --tags --exact-match HEAD 2>/dev/null) \
    || ref=$(GIT_OPTIONAL_LOCKS=0 command git rev-parse --short HEAD 2>/dev/null) \
    || return

  status_text=$(GIT_OPTIONAL_LOCKS=0 command git status --porcelain --ignore-submodules=dirty 2>/dev/null)

  if [[ -n "$status_text" ]]; then
    GIT_PROMPT_INFO="git:(%{$fg[red]%}${ref:gs/%/%%}%{$reset_color%}%{$fg[blue]%}) %{$fg[yellow]%}✗%{$reset_color%}"
  else
    GIT_PROMPT_INFO="git:(%{$fg[red]%}${ref:gs/%/%%}%{$reset_color%}%{$fg[blue]%})"
  fi
}

git_prompt_info() {
  echo -n "$GIT_PROMPT_INFO"
}

add-zsh-hook precmd _update_git_prompt_info

[ -f "$DOTFILES_DIR/chetmancini.zsh-theme" ] && source "$DOTFILES_DIR/chetmancini.zsh-theme"
