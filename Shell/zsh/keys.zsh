# keys.zsh — key bindings. Bindings for tools I do not have (tdo, tea, dexe) dropped.
autoload -U up-line-or-beginning-search down-line-or-beginning-search
autoload -Uz copy-earlier-word edit-command-line
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
zle -N copy-earlier-word
zle -N edit-command-line

# quote-word wraps the word under the cursor in double quotes.
quote-word() {
    zle backward-word
    local start=$CURSOR
    zle forward-word
    local end=$CURSOR
    local quoted="\"${BUFFER[start,end]}\""
    BUFFER="${BUFFER[1,start]}${quoted}${BUFFER[end+1,#BUFFER]}"
    (( CURSOR = start + #quoted ))
}
zle -N quote-word

bindkey "^[." insert-last-word
bindkey "^[m" copy-earlier-word
bindkey "^[f" forward-word
bindkey "^[b" backward-word
bindkey "^b" backward-word
bindkey "^s" forward-word
bindkey "^f" fzf-file-widget
bindkey "^k" autosuggest-accept
bindkey "^o" edit-command-line
bindkey "^x^e" edit-command-line
bindkey "^q" quote-word
bindkey "^u" undo
bindkey "^x^v" vi-cmd-mode
bindkey "^x^x" exchange-point-and-mark
bindkey -s "^g" " lazygit^M"
bindkey -s "^h" ' exec zsh^M'

if [[ -n $CLIPCOPY ]]; then
    copy-command() { print -r -- $BUFFER | ${=CLIPCOPY} }
    zle -N copy-command
    bindkey "^y" copy-command
fi
