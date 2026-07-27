#!/usr/bin/env bash
set -euo pipefail

# Install mpv/fzf/yt-dlp and deploy the console YouTube player for the current user.
# Usage: ./install-linux.sh [--skip-packages] [--system-ytdlp]

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
YT_DIR="$CONFIG_HOME/yt"
BIN_DIR="$HOME/.local/bin"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SKIP_PACKAGES=false
SYSTEM_YTDLP=false

usage() {
  cat <<'EOF'
Usage: ./install-linux.sh [--skip-packages] [--system-ytdlp]

Installs mpv and fzf with the system package manager, installs yt-dlp through
pipx (the packaged yt-dlp is usually stale and breaks on YouTube), then deploys:
  ~/.local/bin/yt
  ~/.config/yt/bookmarks.tsv      (never overwritten once it exists)
  ~/.config/yt/mpv-audio.conf
  ~/.config/yt/mpv-video.conf

Options:
  --skip-packages  do not invoke the system package manager or pipx
  --system-ytdlp   accept the distro yt-dlp instead of installing it via pipx
  -h, --help       show this help
EOF
}

while (($#)); do
  case "$1" in
    --skip-packages) SKIP_PACKAGES=true ;;
    --system-ytdlp) SYSTEM_YTDLP=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

run_root() {
  if ((EUID == 0)); then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf 'Root privileges are required, but sudo is not installed.\n' >&2
    exit 1
  fi
}

pkg_install() {
  local -a packages=("$@")

  ((${#packages[@]})) || return 0
  printf 'Installing packages: %s\n' "${packages[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    run_root apt-get update
    run_root apt-get install -y "${packages[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y "${packages[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    run_root pacman -S --needed --noconfirm "${packages[@]}"
  elif command -v zypper >/dev/null 2>&1; then
    run_root zypper --non-interactive install "${packages[@]}"
  else
    printf 'Unsupported package manager. Install manually: %s\n' "${packages[*]}" >&2
    exit 1
  fi
}

install_packages() {
  local -a packages=()

  command -v mpv >/dev/null 2>&1 || packages+=(mpv)
  command -v fzf >/dev/null 2>&1 || packages+=(fzf)
  if ((${#packages[@]})); then
    pkg_install "${packages[@]}"
  else
    printf 'mpv and fzf are already installed.\n'
  fi
}

install_ytdlp() {
  if [[ "$SYSTEM_YTDLP" == true ]]; then
    command -v yt-dlp >/dev/null 2>&1 || pkg_install yt-dlp
    return
  fi

  command -v pipx >/dev/null 2>&1 || pkg_install pipx

  if ! command -v pipx >/dev/null 2>&1; then
    printf 'pipx is unavailable; falling back to the packaged yt-dlp.\n' >&2
    command -v yt-dlp >/dev/null 2>&1 || pkg_install yt-dlp
    return
  fi

  if pipx list --short 2>/dev/null | grep -q '^yt-dlp '; then
    pipx upgrade yt-dlp || true
  else
    pipx install yt-dlp
  fi
  pipx ensurepath >/dev/null 2>&1 || true
}

backup_if_changed() {
  local source="$1"
  local target="$2"

  if [[ -e "$target" ]] && ! cmp -s -- "$source" "$target"; then
    cp -a -- "$target" "${target}.bak-${TIMESTAMP}"
    printf 'Backup: %s\n' "${target}.bak-${TIMESTAMP}"
  fi
}

if [[ "$SKIP_PACKAGES" == false ]]; then
  install_packages
  install_ytdlp
fi

command -v mpv >/dev/null 2>&1 || {
  printf 'mpv is not installed. Re-run without --skip-packages.\n' >&2
  exit 1
}

mkdir -p "$BIN_DIR" "$YT_DIR"

backup_if_changed "$SOURCE_DIR/yt" "$BIN_DIR/yt"
backup_if_changed "$SOURCE_DIR/mpv-audio.conf" "$YT_DIR/mpv-audio.conf"
backup_if_changed "$SOURCE_DIR/mpv-video.conf" "$YT_DIR/mpv-video.conf"

install -m 0755 "$SOURCE_DIR/yt" "$BIN_DIR/yt"
install -m 0644 "$SOURCE_DIR/mpv-audio.conf" "$YT_DIR/mpv-audio.conf"
install -m 0644 "$SOURCE_DIR/mpv-video.conf" "$YT_DIR/mpv-video.conf"

# Bookmarks are user data: seed them once, never clobber later edits.
if [[ -e "$YT_DIR/bookmarks.tsv" ]]; then
  printf 'Kept existing bookmarks: %s\n' "$YT_DIR/bookmarks.tsv"
else
  install -m 0644 "$SOURCE_DIR/bookmarks.tsv" "$YT_DIR/bookmarks.tsv"
  printf 'Seeded bookmarks: %s\n' "$YT_DIR/bookmarks.tsv"
fi

"$BIN_DIR/yt" cats >/dev/null

printf 'Installed: %s\n' "$(mpv --version | head -n 1)"
if command -v yt-dlp >/dev/null 2>&1; then
  printf 'Installed: yt-dlp %s (%s)\n' "$(yt-dlp --version)" "$(command -v yt-dlp)"
else
  printf 'yt-dlp is still missing — run: pipx install yt-dlp\n' >&2
fi
printf 'Console YouTube is ready. Run: yt <query>\n'

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf 'Add to PATH: export PATH="%s/.local/bin:%sPATH"\n' "$HOME" '$' ;;
esac
