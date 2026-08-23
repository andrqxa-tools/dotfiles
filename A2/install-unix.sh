#!/bin/sh
# Active Oberon SDK (minia2) for Linux and Termux. Thin wrapper: upstream's installer
# already picks the right tarball (glibc x86_64, glibc arm64, Bionic arm64) by looking at
# the loader, so all this adds is linking the env file this repo carries.
# Flags are passed through: --dir, --bin, --version, --tarball, --uninstall.
set -e

repo=https://raw.githubusercontent.com/active-oberon/minia2/main/sdk/install.sh
here=$(cd "$(dirname "$0")/.." && pwd)

command -v curl >/dev/null 2>&1 || { echo "curl is needed" >&2; exit 1; }
curl -fsSL "$repo" | sh -s -- "$@"

mkdir -p "$HOME/.config/profile.d"
ln -sfn "$here/Shell/profile.d/a2.sh" "$HOME/.config/profile.d/a2.sh"
echo "Linked $HOME/.config/profile.d/a2.sh — A2_OB and A2_SYMS come from the next shell."
