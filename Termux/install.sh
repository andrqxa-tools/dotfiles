#!/data/data/com.termux/files/usr/bin/sh
set -eu

if ! command -v termux-reload-settings >/dev/null 2>&1; then
    echo "Error: run this installer inside Termux." >&2
    exit 1
fi

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_file="$config_dir/termux.properties"
target_dir="$HOME/.termux"
target_file="$target_dir/termux.properties"

if [ ! -f "$source_file" ]; then
    echo "Error: $source_file does not exist." >&2
    exit 1
fi

mkdir -p "$target_dir"

if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
    echo "Already linked: $target_file -> $source_file"
else
    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
        backup_file="$target_file.pre-dotfiles"
        suffix=0
        while [ -e "$backup_file" ] || [ -L "$backup_file" ]; do
            suffix=$((suffix + 1))
            backup_file="$target_file.pre-dotfiles.$suffix"
        done
        mv "$target_file" "$backup_file"
        echo "Backed up existing config to $backup_file"
    fi

    ln -s "$source_file" "$target_file"
    echo "Linked: $target_file -> $source_file"
fi

termux-reload-settings
echo "Termux settings reloaded."
