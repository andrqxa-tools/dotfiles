#!/usr/bin/env bash
set -euo pipefail

# Deno installer / updater (single static binary, no vendor install script).
#   runtime -> /opt/programming/deno/bin/deno   (owned by $USER)
#   env     -> ~/.config/profile.d/deno.sh      (symlink into this repo)
#
# Usage: $0 [version] [arch] [--force]
#   version  e.g. 2.9.4 or v2.9.4   (default: latest from dl.deno.land)
#   arch     amd64|arm64            (default: detected from `uname -m`)
#   --force  re-download even when that version is already installed
#
# Why deno is here at all: yt-dlp needs a JavaScript runtime to decipher
# YouTube signatures, and deno is the only runtime it enables by default.
# Without it `yt-dlp -F` returns a truncated format list and warns
# "No supported JavaScript runtime could be found". See dotfiles/YouTube.

usage() {
  sed -n '4,16p' "$0" | sed 's/^# \{0,1\}//'
}

FORCE=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --force|-f) FORCE=true ;;
    *) ARGS+=("$arg") ;;
  esac
done
set -- ${ARGS[@]+"${ARGS[@]}"}

# --- resolve version (default: latest) ----------------------------------
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Resolving latest Deno version..."
  VERSION="$(curl -fsSL 'https://dl.deno.land/release-latest.txt' | head -n1)"
fi
VERSION="v${VERSION#v}"   # normalize "2.9.4" -> "v2.9.4"

# --- resolve architecture (default: this machine) -----------------------
ARCH="${2:-}"
if [ -z "$ARCH" ]; then
  case "$(uname -m)" in
    x86_64 | amd64)  ARCH=amd64 ;;
    aarch64 | arm64) ARCH=arm64 ;;
    *) echo "Unknown arch '$(uname -m)'. Pass it explicitly: $0 <version> <arch>"; exit 1 ;;
  esac
fi
case "$ARCH" in
  amd64) TARGET=x86_64-unknown-linux-gnu ;;
  arm64) TARGET=aarch64-unknown-linux-gnu ;;
  *) echo "Unsupported arch '$ARCH' (use amd64 or arm64)."; exit 1 ;;
esac

echo "Installing Deno $VERSION ($ARCH)"

# --- paths --------------------------------------------------------------
DENO_HOME=/opt/programming/deno      # the runtime itself
DENO_BIN="$DENO_HOME/bin/deno"
OWNER="$(id -un):$(id -gn)"
ARCHIVE="deno-${TARGET}.zip"
URL="https://dl.deno.land/release/${VERSION}/${ARCHIVE}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# /opt is conventionally root-owned; use sudo only when we lack write access.
run_root() {
  if [ -w "$(dirname "$DENO_HOME")" ] && { [ ! -e "$DENO_HOME" ] || [ -w "$DENO_HOME" ]; }; then
    "$@"
  else
    sudo "$@"
  fi
}

# --- skip a no-op reinstall (the env wiring below still runs) -----------
NEED_INSTALL=true
if [ -x "$DENO_BIN" ]; then
  CURRENT="v$("$DENO_BIN" --version | awk 'NR==1 {print $2}')"
  if [ "$CURRENT" = "$VERSION" ] && [ "$FORCE" = false ]; then
    echo "Deno $VERSION is already installed at $DENO_BIN (--force to re-download)."
    NEED_INSTALL=false
  fi
fi

# --- download + extract -------------------------------------------------
if [ "$NEED_INSTALL" = true ]; then
  command -v unzip >/dev/null 2>&1 || {
    echo "unzip is required but not installed (apt install unzip)." >&2
    exit 1
  }

  echo "Downloading $URL..."
  curl -fLo "$TMP/$ARCHIVE" "$URL"

  echo "Installing runtime to $DENO_BIN..."
  unzip -o -q "$TMP/$ARCHIVE" -d "$TMP"
  run_root mkdir -p "$DENO_HOME/bin"
  run_root install -m 0755 "$TMP/deno" "$DENO_BIN"
  run_root chown -R "$OWNER" "$DENO_HOME"
fi

# --- environment --------------------------------------------------------
# The env file lives in the repo (Shell/profile.d/deno.sh) and is symlinked
# into ~/.config/profile.d/, where .bashrc/.profile load it. readlink -f: the
# script may be invoked through a symlink, and we need the real repo path.
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
ENV_SRC="$REPO_ROOT/Shell/profile.d/deno.sh"
ENV_DST="$HOME/.config/profile.d/deno.sh"

if [ -f "$ENV_SRC" ]; then
  mkdir -p "$HOME/.config/profile.d"
  ln -sfn "$ENV_SRC" "$ENV_DST"
  echo "Symlink: $ENV_DST -> $ENV_SRC"
else
  echo "WARNING: $ENV_SRC not found — the script must live in dotfiles/Deno/." >&2
  echo "         Env not wired; add /opt/programming/deno/bin to PATH yourself." >&2
fi

# fish can't source POSIX rc files — drop a native auto-loaded snippet.
if command -v fish >/dev/null 2>&1 || [ -d "$HOME/.config/fish" ]; then
  FISH_DIR="$HOME/.config/fish/conf.d"
  mkdir -p "$FISH_DIR"
  cat > "$FISH_DIR/deno.fish" <<'EOF'
# Managed by dotfiles/Deno/deno-install.sh — regenerated on each install.
set -gx DENO_INSTALL_ROOT $HOME/.deno
set -gx DENO_DIR $HOME/.cache/deno
fish_add_path $DENO_INSTALL_ROOT/bin /opt/programming/deno/bin
EOF
  echo "Wrote $FISH_DIR/deno.fish"
fi

# An earlier manual install may have left a symlink in ~/.local/bin; that dir is
# ahead of /opt/programming/deno/bin on PATH, so drop it to keep one source.
STALE="$HOME/.local/bin/deno"
if [ -L "$STALE" ] && [ "$(readlink -f "$STALE")" = "$(readlink -f "$DENO_BIN")" ]; then
  rm -f "$STALE"
  echo "Removed redundant symlink: $STALE"
fi

# --- verify -------------------------------------------------------------
INSTALLED="v$("$DENO_BIN" --version | awk 'NR==1 {print $2}')"
if [ "$INSTALLED" = "$VERSION" ]; then
  echo "Deno $VERSION installed successfully ($DENO_BIN)."
else
  echo "WARNING: installed version ($INSTALLED) != requested ($VERSION)."
fi

if command -v yt-dlp >/dev/null 2>&1; then
  echo "yt-dlp will now use deno for YouTube signature deciphering."
fi

echo
echo "Done. Open a new terminal, or run:  source $ENV_DST"
