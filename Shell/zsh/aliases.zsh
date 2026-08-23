# aliases.zsh — only aliases whose tool actually exists on the machines I use.

# Navigation and files
alias ..="cd ../"
alias ...="cd ../../"
alias ....="cd ../../../"
alias .....="cd ../../../../"
alias cat="bat"
alias cp="cp -irv"
alias mv="mv -iv"
alias rm="rm -irv"
alias rmf="rm -rf"
alias ln="ln -sfnv"
alias ls="ls --color=auto"
alias grep="grep --color=auto"
alias diff="diff --color=auto"
alias fd="fd -H"
alias fdir="find . -type d -name"
alias ffil="find . -type f -name"
alias ldir="ls -d */"
alias q="exit"

alias ez="eza -Ah -s=extension --group-directories-first --icons"
alias ezl="eza -AhlT -L=1 -s=extension --group-directories-first --icons --git --git-ignore"
alias ezr="eza -AhlR -L=2 -s=extension --group-directories-first --icons --git --git-ignore"
alias ezt="eza -ahlT -L=2 -s=extension --group-directories-first --icons --git --git-ignore"
alias la="ez"
alias ll="ezl"
alias lr="ezr"
alias lt="ezt"

# Git
alias g="git"
alias ga="git add"
alias gc="git commit -m"
alias gca="git commit --all -m"
alias gl="git pull --rebase --autostash"
alias gp="git push"
alias gss="git status -s"
alias gsv="git status -v"
alias gsd="git status -s && git diff HEAD"
alias gdh="git diff HEAD"
alias gmv="git mv"
alias gcma="git commit --amend -m"
alias gcman="git commit --amend --no-edit"
alias gcmn="git add . && git commit --amend --no-edit"
alias gcm='git checkout $(git_main_branch)'
alias gtop='cd "$(git rev-parse --show-toplevel)"'
alias gbrr="git for-each-ref --count=30 --sort=-committerdate refs/heads/ --format='%(refname:short)'"

# GitHub CLI
alias ghpr="gh pr create"
alias ghpd="pr_diff"
alias ghpf="pr_files"
alias ghrc="gh repo clone"
alias ghro="gh repo view --web"
alias ghrs="gh release create"
alias ghkey='gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)" --type signing'

# Editing
alias vi="nvim"
alias e='nvim $(fzf)'
alias vg="grep_open"
alias vc="changed_files"
alias vr="review_changes"
alias vb="binary_edit"
alias me='$EDITOR README.md'
alias files="fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}'"

# Configs — all of them live in this repo
alias zshc='$EDITOR "$ZSH_CONF/zshrc"'
alias alia='$EDITOR "$ZSH_CONF/aliases.zsh"'
alias func='$EDITOR "$ZSH_CONF/functions.zsh"'
alias keysc='$EDITOR "$ZSH_CONF/keys.zsh"'
alias p10c='$EDITOR "$ZSH_CONF/p10k.theme.zsh"'
alias loca='$EDITOR ~/.config/shell/local.sh'
alias gitc='$EDITOR ~/.gitconfig'
alias tmuxc='$EDITOR ~/.config/tmux/tmux.conf'
alias nvimc='$EDITOR ~/.config/nvim/init.lua'

# Misc
alias tmux="tmux -u"
alias ncdu="ncdu --color=dark -x"
alias logshare="curl -F 'file=@-' 0x0.st"

# Packages: Termux speaks pkg, Fedora dnf
if [[ -n $TERMUX_VERSION ]]; then
    alias pki="pkg install"
    alias pks="pkg search"
    alias pkr="pkg uninstall"
    alias pku="pkg upgrade"
elif (( $+commands[dnf] )); then
    alias pki="sudo dnf install"
    alias pks="dnf search"
    alias pkr="sudo dnf remove"
    alias pku="sudo dnf upgrade"
fi

# zsh-only sugar
alias reload="exec zsh"
alias -s md=nvim
alias -s html=nvim
alias -g G="| grep"
alias -g L="| wc -l"
alias -g Q="&& exit"
alias -g Z="| fzf"
alias -g wcc="| wc -m"
alias -g wcw="| wc -w"
[[ -n $CLIPCOPY ]] && alias -g C="| $CLIPCOPY"
