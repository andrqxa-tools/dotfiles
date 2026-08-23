#!/bin/sh
# install.sh — put this zsh setup in place. Idempotent: skips whatever is already there.
set -e

CONF=$(cd "$(dirname "$0")" && pwd)
ZSH_HOME=${ZSH_HOME:-$HOME/.local/share/oh-my-zsh}
GH=https://github.com

# oh-my-zsh and its third-party plugins are clones, not repo content — nothing vendored here.
if [ ! -d "$ZSH_HOME" ]; then
    git clone --depth 1 "$GH/ohmyzsh/ohmyzsh" "$ZSH_HOME"
fi

clone() { [ -d "$2" ] || git clone --depth 1 "$1" "$2"; }

mkdir -p "$ZSH_HOME/custom/plugins" "$ZSH_HOME/custom/themes"
clone "$GH/romkatv/powerlevel10k"      "$ZSH_HOME/custom/themes/powerlevel10k"
clone "$GH/zsh-users/zsh-autosuggestions" "$ZSH_HOME/custom/plugins/zsh-autosuggestions"
clone "$GH/clarketm/zsh-completions"   "$ZSH_HOME/custom/plugins/zsh-completions"
clone "$GH/z-shell/F-Sy-H"             "$ZSH_HOME/custom/plugins/F-Sy-H"
clone "$GH/djui/alias-tips"            "$ZSH_HOME/custom/plugins/alias-tips"
clone "$GH/unixorn/git-extra-commands" "$ZSH_HOME/custom/plugins/git-extra-commands"
clone "$GH/Aloxaf/fzf-tab"             "$ZSH_HOME/custom/plugins/fzf-tab"
clone "$GH/hlissner/zsh-autopair"      "$ZSH_HOME/custom/plugins/zsh-autopair"

ln -sfnv "$CONF/zshrc" "$HOME/.zshrc"

mkdir -p "$HOME/.config/shell"
[ -f "$HOME/.config/shell/local.sh" ] || cat > "$HOME/.config/shell/local.sh" <<'LOCAL'
# Machine-local settings, deliberately outside the dotfiles repo.
LOCAL

echo
echo "Done. Make zsh the login shell if it is not yet:"
if [ -n "$TERMUX_VERSION" ]; then
    echo "  chsh -s zsh        # Termux: writes ~/.termux/shell"
else
    echo "  chsh -s \"\$(command -v zsh)\""
fi
