bindkey "^[[3~" delete-char # delete
bindkey "^[[1;5D" backward-word # Ctl-left
bindkey "^[[1;5C" forward-word # Ctl-right
bindkey "^[[3;5~" forward-kill-word # Ctl-delete

### ghq ###
bindkey "^G" widget::ghq::session # C-g
bindkey "^[g" widget::ghq::dir # Alt-g