#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

FONT="JetBrainsMono"
DEST="$HOME/.termux"
TMP="$HOME/.cache/fonts"

mkdir -p "$DEST" "$TMP"
cd "$TMP"

echo "Downloading JetBrainsMono Nerd Font..."

URL=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
  | sed -n 's/.*"browser_download_url": "\(.*JetBrainsMono.tar.xz\)".*/\1/p' \
  | head -n1)

curl -LO "$URL"
tar -xf JetBrainsMono.tar.xz

# Копируем только один файл
cp JetBrainsMonoNerdFont-Regular.ttf "$DEST/font.ttf"

# Перезапуск терминала обязателен
termux-reload-settings

echo "Done. Restart Termux."
