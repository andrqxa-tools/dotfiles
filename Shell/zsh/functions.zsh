# functions.zsh — helpers used by the aliases above.

# mcd makes the directory and steps into it.
mcd() { mkdir -p -- "$1" && cd -P -- "$1" }

# lc enters a directory and lists it.
lc() { cd "$1" && la "$2" }

# xin runs a command in another directory without leaving this one.
xin() { (cd "${1}" && shift && ${@}) }

# ex extracts whatever archive it is handed.
ex() {
    [[ -f $1 ]] || { echo "'$1' is not a file"; return 1 }
    case $1 in
    *.tar.bz2 | *.tbz2) tar xjf "$1" ;;
    *.tar.gz | *.tgz)   tar xzf "$1" ;;
    *.tar)              tar xf "$1" ;;
    *.tar.xz | *.txz)   tar xJf "$1" ;;
    *.bz2)              bunzip2 "$1" ;;
    *.gz)               gunzip "$1" ;;
    *.xz)               unxz "$1" ;;
    *.zip)              unzip "$1" ;;
    *.7z)               7z x "$1" ;;
    *.rar)              unrar x "$1" ;;
    *.Z)                uncompress "$1" ;;
    *) echo "'$1' — unknown archive type" ; return 1 ;;
    esac
}

# grep_open picks a file among those containing the term and opens it there.
grep_open() {
    local editor="$EDITOR"
    [[ $EDITOR == (vim|nvim) ]] && editor="$EDITOR +/$1 +'norm! n'"
    rg -l "$1" | fzf --bind "enter:execute($editor {})"
}

# review_changes browses this branch's diff against its base.
review_changes() {
    local base="${1:-}"
    if [[ -z $base ]]; then
        base=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
        [[ -z $base ]] && base=main
    fi
    git diff --name-only "$base"...HEAD | fzf \
        --preview "git diff $base...HEAD -- {} | delta --width \$FZF_PREVIEW_COLUMNS" \
        --bind "enter:execute($EDITOR {})"
}

# changed_files browses staged and unstaged changes.
changed_files() {
    git status --short | awk '{print $2}' | fzf \
        --preview "git diff --cached -- {} | delta --width \$FZF_PREVIEW_COLUMNS && git diff -- {} | \
        delta --width \$FZF_PREVIEW_COLUMNS && git diff --no-index -- /dev/null {} | delta --width \$FZF_PREVIEW_COLUMNS" \
        --bind "enter:execute($EDITOR {})"
}

# pr_diff shows one pull request's diff through delta.
pr_diff() { gh pr diff "$1" | delta }

# pr_files browses the files a pull request touches.
pr_files() { gh pr diff "$1" --name-only | fzf --bind "enter:execute($EDITOR {})" }

# binary_edit opens whatever is on PATH under that name — handy for symlinked scripts.
binary_edit() {
    local bin=$(command -v "$1")
    [[ -n $bin ]] || { echo "not on PATH: $1"; return 1 }
    $EDITOR "$bin"
}

# tmux-clean kills every detached session.
tmux-clean() {
    tmux list-sessions 2>/dev/null | grep -Ev '\(attached\)$' | while read -r line; do
        tmux kill-session -t "${line%%:*}"
    done
}

# man paints man pages, since less does not.
man() {
    env LESS_TERMCAP_mb=$(printf "\e[1;31m") LESS_TERMCAP_md=$(printf "\e[1;36m") \
        LESS_TERMCAP_me=$(printf "\e[0m")    LESS_TERMCAP_se=$(printf "\e[0m") \
        LESS_TERMCAP_so=$(printf "\e[1;44;33m") LESS_TERMCAP_ue=$(printf "\e[0m") \
        LESS_TERMCAP_us=$(printf "\e[1;32m") man "$@"
}

# _fzf_comprun gives the fzf completion trigger a per-command preview.
_fzf_comprun() {
    local command=$1
    shift
    case "$command" in
    cd) fzf "$@" --preview 'eza -TFl --group-directories-first --icons --git -L 2 --no-user {}' ;;
    nvim | vim) fzf "$@" --preview 'bat --color=always --style=numbers --line-range=:500 {}' ;;
    *) fzf "$@" ;;
    esac
}
