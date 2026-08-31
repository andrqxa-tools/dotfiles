#!/bin/sh
# Active Oberon SDK (minia2) for Linux and Termux.
#
# With no arguments on x86-64 Linux, prefer a local minia2 checkout and run `task update`: a
# released SDK can have the same date in its version banner as newer commits made later that day,
# which made the installed language server look current while fixes such as cross-module
# go-to-definition were still missing. Set MINIA2_CHECKOUT to name another checkout explicitly.
#
# Termux uses the published Android/Bionic bundle instead. That bundle needs an Android NDK and is
# cross-built by the release workflow; `task update` in a source checkout produces the ordinary
# desktop bundle and cannot replace the native Termux SDK.
#
# With arguments, use upstream's release installer and pass them through unchanged: --dir, --bin,
# --version, --tarball, --no-link, --uninstall.
set -eu

repo=https://raw.githubusercontent.com/active-oberon/minia2/main/sdk/install.sh
here=$(cd "$(dirname "$0")/.." && pwd)

checkout=${MINIA2_CHECKOUT:-}
case $(uname -m) in
    x86_64|amd64) auto_local=1 ;;
    *) auto_local=0 ;;
esac
if [ -z "$checkout" ] && [ "$#" -eq 0 ] && [ "$auto_local" -eq 1 ]; then
    for candidate in \
        "$HOME/projects/A2/minia2" \
        "$HOME/Projects/A2/minia2"
    do
        if [ -f "$candidate/Taskfile.yml" ] && [ -f "$candidate/sdk/install.sh" ]; then
            checkout=$candidate
            break
        fi
    done
fi
unset auto_local

if [ -n "$checkout" ] && [ "$#" -eq 0 ]; then
    [ -f "$checkout/Taskfile.yml" ] && [ -f "$checkout/sdk/install.sh" ] || {
        echo "MINIA2_CHECKOUT is not a minia2 checkout: $checkout" >&2
        exit 1
    }
    command -v task >/dev/null 2>&1 || {
        echo "task is needed to build the local minia2 checkout: $checkout" >&2
        exit 1
    }
    echo "Updating the A2 SDK from the local checkout: $checkout"
    (cd "$checkout" && task update)
else
    command -v curl >/dev/null 2>&1 || { echo "curl is needed" >&2; exit 1; }
    curl -fsSL "$repo" | sh -s -- "$@"
fi

mkdir -p "$HOME/.config/profile.d"
ln -sfn "$here/Shell/profile.d/a2.sh" "$HOME/.config/profile.d/a2.sh"
echo "Linked $HOME/.config/profile.d/a2.sh — A2_OB, A2_SYMS and A2_STDLIB_SRC come from the next shell."

# These directories are loaded by Neovim itself, outside lua/.  Keep the links here as well as in
# README so updating a configured machine does not require copying the setup commands by hand.
# A real directory may contain somebody's local configuration, so never replace one implicitly.
mkdir -p "$HOME/.config/nvim"
for part in after ftdetect syntax; do
    source_dir=$here/Editors/NeoVim/NvChad/$part
    target_dir=$HOME/.config/nvim/$part
    if [ -e "$target_dir" ] && [ ! -L "$target_dir" ]; then
        echo "Left $target_dir alone — it exists and is not a symlink." >&2
    else
        ln -sfn "$source_dir" "$target_dir"
        echo "Linked $target_dir"
    fi
done
