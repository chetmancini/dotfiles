_ssh_indicator() {
  if [[ -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]]; then
    echo "%{$fg_bold[yellow]%}%m%{$reset_color%} "
  fi
}

PROMPT='%{$fg_bold[red]%}λ $(_ssh_indicator)%{$fg_bold[green]%}%p %{$fg[cyan]%}%c %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} % %{$reset_color%}'

ZSH_THEME_GIT_PROMPT_PREFIX="git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
