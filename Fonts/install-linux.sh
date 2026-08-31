#!/usr/bin/env bash
set -euo pipefail

REPO="ryanoasis/nerd-fonts"
FONT="JetBrainsMono"
# Pinned: v3.5.x ships wider metrics that blow the letter spacing apart in VTE — 2026-08-30.
VERSION="v3.4.0"
DEST="$HOME/.local/share/fonts/${FONT}NerdFont"

mkdir -p "$DEST"
cd "$DEST"

URL="https://github.com/${REPO}/releases/download/${VERSION}/${FONT}.tar.xz"

echo "Downloading $URL"
curl -LO "$URL"

tar xf "${FONT}.tar.xz"
# Keep the standard variant (NvChad wants non-Mono: its icons stay full size) and
# Mono alongside it, for terminals that need every glyph one cell wide. Drop Propo/NL.
rm -f "${DEST}"/JetBrainsMonoNerdFontPropo* \
      "${DEST}"/JetBrainsMonoNLNerdFont*
rm -f "${FONT}.tar.xz"

fc-cache -fv

echo "JetBrainsMono Nerd Font installed."
