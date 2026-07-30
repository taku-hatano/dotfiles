### utility ###
forward-kill-word() {
	zle vi-forward-word
	zle vi-backward-kill-word
}

zle -N forward-kill-word

mkcd() { command mkdir -p -- "$@" && builtin cd "${@[-1]:a}" }

j() {
	local root dir
	root="${$(git rev-parse --show-cdup 2>/dev/null):-.}"
	dir="$(fd --color=always --hidden --type=d . "$root" | fzf --select-1 --query="$*" --preview='fzf-preview-directory {}')"
	if [ -n "$dir" ]; then
		builtin cd "$dir"
		echo "$PWD"
	fi
}

jj() {
	local root
	root="$(git rev-parse --show-toplevel)" || return 1
	builtin cd "$root"
}

### diff ###
diff() {
	command diff "$@" | bat --paging=never --plain --language=diff
}

hunk-pr() {
	local tmpfile="$(mktemp)"
	{
		gh pr diff "$@" > "$tmpfile"
		hunk patch "$tmpfile"
	} always {
		rm -f "$tmpfile"
	}
}

widget::ghq::source() {
    local session color green="\e[32m" blue="\e[34m" reset="\e[m" checked=$'\U000f063d' unchecked=$'\U000f063b'
    local sessions=($(tmux list-sessions -F "#S" 2>/dev/null))

    ghq list | while read -r repo; do
        session="${repo//[:. ]/-}"
        color="$blue"
        icon="$unchecked"
        if (( ${+sessions[(r)$session]} )); then
            color="$green"
            icon="$checked"
        fi
        printf "$color$icon %s$reset\n" "$repo"
    done
}

widget::ghq::select() {
    local root="$(ghq root)"
    widget::ghq::source | fzf --exit-0 --preview="fzf-preview-git ${(q)root}/{+2}" --preview-window="right:60%" | cut -d' ' -f2-
}

widget::ghq::dir() {
    local selected="$(widget::ghq::select)"
    if [ -z "$selected" ]; then
        return
    fi

    local root="$(ghq root)"
    BUFFER="cd ${(q)root}/$selected"
    zle accept-line
    zle -R -c # refresh screen
}

widget::ghq::session() {
    local selected="$(herdr-ghq-select)"
    if [ -z "$selected" ]; then
        return
    fi

    local root="$(ghq root)"
    local repo_dir="${(q)root}/$selected"
    local label="${selected//[:. ]/-}"

    if ! herdr workspace list >/dev/null 2>&1; then
        # サーバー未起動時: herdrはセッション復元時に起動時cwdを無視するため、
        # cwd頼みの起動はせずサーバーだけ先に上げ、後段でworkspaceを明示的に作る
        herdr server >/dev/null 2>&1 &!
        local waited=0
        until herdr workspace list >/dev/null 2>&1; do
            sleep 0.1
            waited=$((waited + 1))
            if [ "$waited" -gt 50 ]; then
                break
            fi
        done
    fi

    local existing_id="$(herdr workspace list 2>/dev/null | jq -r --arg label "$label" '.result.workspaces[]? | select(.label==$label) | .workspace_id' | head -n1)"
    if [ -n "$existing_id" ]; then
        herdr workspace focus "$existing_id" >/dev/null
    else
        herdr workspace create --cwd "$repo_dir" --label "$label" --focus >/dev/null
    fi

    BUFFER="herdr"
    zle accept-line
    zle -R -c # refresh screen
}

zle -N widget::ghq::dir
zle -N widget::ghq::session

### docker ###
docker() {
	if [ "$#" -eq 0 ] || [ "$1" = "compose" ] || ! command -v "docker-$1" >/dev/null; then
		command docker "${@:1}"
	else
		"docker-$1" "${@:2}"
	fi
}
docker-rm() {
	if [ "$#" -eq 0 ]; then
		command docker ps -a | \
		fzf --exit-0 --multi --header-lines=1 | \
		awk '{ print $1 }' | \
		xargs -r docker rm --
	else
		command docker rm "$@"
	fi
}
docker-rmi() {
	if [ "$#" -eq 0 ]; then
		command docker images | \
		fzf --exit-0 --multi --header-lines=1 | \
		awk '{ print $3 }' | \
		xargs -r docker rmi --
	else
		command docker rmi "$@"
	fi
}

### Editor ###
e() {
	tmux split-window -h
	tmux split-window -v
	tmux resize-pane -D 20
	tmux resize-pane -L 60
	tmux select-pane -t 1
	tmux split-window -v
	# clear
	tmux setw synchronize-panes on
	tmux send-keys "clear" C-m
	tmux setw synchronize-panes off
	tmux select-pane -t 3
	tmux send-keys "nvim $@" C-m
}

### shrink path ###
colorlist() {
	for i in {0..255}; do
		printf "\x1b[48;5;${i}m\x1b[38;5;0mcolor%03d\x1b[0m " $i
		if [ $((($i + 1) % 8)) -eq 0 ]; then
			echo
		fi
	done
}
