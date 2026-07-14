#!/usr/bin/env bash
set -euo pipefail

REPO="ryanoasis/nerd-fonts"
FONT="JetBrainsMono"
DEST="$HOME/.local/share/fonts/${FONT}NerdFont"

mkdir -p "$DEST"
cd "$DEST"

echo "Fetching latest release info..."

URL=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" \
  | jq -r '.assets[]
      | select(.name == "'"${FONT}"'.tar.xz")
      | .browser_download_url')

if [[ -z "$URL" ]]; then
  echo "JetBrainsMono.tar.xz not found in latest release"
  exit 1
fi

echo "Downloading $URL"
curl -LO "$URL"

tar xf "${FONT}.tar.xz"
# Keep only the standard variant; drop Mono/Propo/NL.
rm -f "${DEST}"/JetBrainsMonoNerdFontMono* \
      "${DEST}"/JetBrainsMonoNerdFontPropo* \
      "${DEST}"/JetBrainsMonoNLNerdFont*
rm -f "${FONT}.tar.xz"

fc-cache -fv

echo "JetBrainsMono Nerd Font installed."
