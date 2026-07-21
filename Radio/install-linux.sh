#!/usr/bin/env bash
set -euo pipefail

# Install mpv/fzf and deploy the console radio files for the current user.
# Usage: ./install-linux.sh [--skip-packages]

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
RADIO_DIR="$CONFIG_HOME/radio"
BIN_DIR="$HOME/.local/bin"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SKIP_PACKAGES=false

usage() {
  cat <<'EOF'
Usage: ./install-linux.sh [--skip-packages]

Installs mpv and fzf using the system package manager, then deploys:
  ~/.local/bin/radio
  ~/.config/radio/stations.tsv
  ~/.config/radio/mpv.conf
  ~/.config/radio/radio.m3u

Options:
  --skip-packages  do not invoke the system package manager
  -h, --help       show this help
EOF
}

while (($#)); do
  case "$1" in
    --skip-packages) SKIP_PACKAGES=true ;;
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

install_packages() {
  local -a packages=()

  command -v mpv >/dev/null 2>&1 || packages+=(mpv)
  command -v fzf >/dev/null 2>&1 || packages+=(fzf)
  ((${#packages[@]})) || {
    printf 'mpv and fzf are already installed.\n'
    return
  }

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
    printf 'Unsupported package manager. Install mpv and fzf manually.\n' >&2
    exit 1
  fi
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
fi

command -v mpv >/dev/null 2>&1 || {
  printf 'mpv is not installed. Re-run without --skip-packages.\n' >&2
  exit 1
}

mkdir -p "$BIN_DIR" "$RADIO_DIR"

backup_if_changed "$SOURCE_DIR/radio" "$BIN_DIR/radio"
backup_if_changed "$SOURCE_DIR/stations.tsv" "$RADIO_DIR/stations.tsv"
backup_if_changed "$SOURCE_DIR/mpv.conf" "$RADIO_DIR/mpv.conf"

install -m 0755 "$SOURCE_DIR/radio" "$BIN_DIR/radio"
install -m 0644 "$SOURCE_DIR/stations.tsv" "$RADIO_DIR/stations.tsv"
install -m 0644 "$SOURCE_DIR/mpv.conf" "$RADIO_DIR/mpv.conf"

"$BIN_DIR/radio" m3u "$RADIO_DIR/radio.m3u"
chmod 0644 "$RADIO_DIR/radio.m3u"

"$BIN_DIR/radio" genres >/dev/null
printf 'Installed: %s\n' "$(mpv --version | head -n 1)"
printf 'Console radio is ready. Run: radio\n'

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf 'Add to PATH: export PATH="%s/.local/bin:%sPATH"\n' "$HOME" '$' ;;
esac
