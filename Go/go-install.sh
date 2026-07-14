#!/usr/bin/env bash
set -euo pipefail

# Manual Go installer / updater.
#   GOROOT -> /opt/programming/go   (the toolchain itself, owned by $USER)
#   GOPATH -> $HOME/go              (modules, binaries, caches)
#
# Usage: $0 [version] [arch]
#   version  e.g. 1.26.2   (default: latest stable from go.dev)
#   arch     386|amd64|armv6l|arm64   (default: detected from `uname -m`)
#
# Environment is written to ~/.config/profile.d/go.sh (POSIX) for sh/bash/zsh,
# and to ~/.config/fish/conf.d/go.fish for fish. The script wires whichever
# shells are installed so the paths reach console, GUI and login sessions.

# --- resolve version (default: latest stable) ---------------------------
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Resolving latest Go version..."
  VERSION="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"
fi
VERSION="${VERSION#go}"   # normalize "go1.26.2" -> "1.26.2"

# --- resolve architecture (default: this machine) -----------------------
ARCH="${2:-}"
if [ -z "$ARCH" ]; then
  case "$(uname -m)" in
    x86_64 | amd64)   ARCH=amd64 ;;
    aarch64 | arm64)  ARCH=arm64 ;;
    armv6l)           ARCH=armv6l ;;
    armv7l | armhf)   ARCH=armv6l ;;
    i386 | i686)      ARCH=386 ;;
    *) echo "Unknown arch '$(uname -m)'. Pass it explicitly: $0 <version> <arch>"; exit 1 ;;
  esac
fi
echo "Installing Go $VERSION ($ARCH)"

# --- paths --------------------------------------------------------------
GO_HOME=/opt/programming     # parent dir for the toolchain
GOROOT="$GO_HOME/go"
GOPATH="$HOME/go"
GOCACHE="$HOME/.cache/go-build"
OWNER="$(id -un):$(id -gn)"

ENV_DIR="$HOME/.config/profile.d"
ENV_FILE="$ENV_DIR/go.sh"
TARBALL="go${VERSION}.linux-${ARCH}.tar.gz"

# /opt is conventionally root-owned; use sudo only when we lack write access.
run_root() {
  if [ -w "$(dirname "$GO_HOME")" ] && { [ ! -e "$GO_HOME" ] || [ -w "$GO_HOME" ]; }; then
    "$@"
  else
    sudo "$@"
  fi
}

# --- download + extract the toolchain -----------------------------------
echo "Downloading Go $VERSION ($ARCH)..."
curl -fLo "/tmp/$TARBALL" "https://dl.google.com/go/$TARBALL"

echo "Installing toolchain to $GOROOT..."
run_root mkdir -p "$GO_HOME"
run_root rm -rf "$GOROOT"
run_root tar -C "$GO_HOME" -xzf "/tmp/$TARBALL"
rm -f "/tmp/$TARBALL"

# Keep the toolchain owned by the user (not root), even if sudo did the extract.
echo "Setting ownership of $GO_HOME to $OWNER..."
run_root chown -R "$OWNER" "$GO_HOME"

# --- create GOPATH layout -----------------------------------------------
mkdir -p "$GOPATH/src" "$GOPATH/bin" "$GOPATH/pkg" "$GOCACHE"

# --- write the POSIX environment file (regenerated, never appended) -----
echo "Writing environment to $ENV_FILE..."
mkdir -p "$ENV_DIR"
cat > "$ENV_FILE" <<EOF
# Managed by dotfiles/Go/go-install.sh — regenerated on each install.
export GOROOT=$GOROOT
export GOPATH="\$HOME/go"
export GOMODCACHE="\$GOPATH/pkg/mod"
export GOCACHE="\$HOME/.cache/go-build"
export PATH="\$GOROOT/bin:\$GOPATH/bin:\$PATH"

# Uncomment and set if you use private modules:
# export GOPRIVATE="github.com/yourorg/*"
EOF

# --- wire the shells ----------------------------------------------------
# Idempotent: skip a file that already sources ~/.config/profile.d in any form.
ensure_profile_d() {
  local rc="$1" create="${2:-no}"
  if [ ! -f "$rc" ]; then
    [ "$create" = "create" ] || return 0
    : > "$rc"
  fi
  if grep -q '\.config/profile\.d' "$rc"; then
    echo "  loader already present in $rc"
    return 0
  fi
  echo "  adding profile.d loader to $rc"
  cat >> "$rc" <<'EOF'

# >>> ~/.config/profile.d loader >>>
if [ -d "$HOME/.config/profile.d" ]; then
  for f in "$HOME/.config/profile.d/"*.sh; do
    [ -r "$f" ] && . "$f"
  done
fi
# <<< ~/.config/profile.d loader <<<
EOF
}

echo "Wiring shells to load the Go environment..."

# sh / GUI login session (display managers source ~/.profile via /bin/sh).
ensure_profile_d "$HOME/.profile" create

# bash: interactive (.bashrc) + login (.bash_profile, only if present, since
# its mere existence makes bash ignore .profile for login shells).
if command -v bash >/dev/null 2>&1; then
  ensure_profile_d "$HOME/.bashrc" create
  ensure_profile_d "$HOME/.bash_profile"
fi

# zsh: doesn't read .profile/.bashrc, but can source the POSIX go.sh.
if command -v zsh >/dev/null 2>&1; then
  ensure_profile_d "$HOME/.zshrc"    create   # interactive
  ensure_profile_d "$HOME/.zprofile" create   # login
fi

# fish: own syntax, can't source POSIX rc files. Drop a native auto-loaded
# snippet in conf.d (regenerated each run).
if command -v fish >/dev/null 2>&1 || [ -d "$HOME/.config/fish" ]; then
  fish_dir="$HOME/.config/fish/conf.d"
  mkdir -p "$fish_dir"
  cat > "$fish_dir/go.fish" <<'EOF'
# Managed by dotfiles/Go/go-install.sh — regenerated on each install.
set -gx GOROOT /opt/programming/go
set -gx GOPATH $HOME/go
set -gx GOMODCACHE $GOPATH/pkg/mod
set -gx GOCACHE $HOME/.cache/go-build
fish_add_path $GOROOT/bin $GOPATH/bin
EOF
  echo "  wrote $fish_dir/go.fish"
fi

# --- verify -------------------------------------------------------------
INSTALLED="$("$GOROOT/bin/go" version | awk '{print $3}')"
if [ "$INSTALLED" = "go$VERSION" ]; then
  echo "Go $VERSION installed successfully ($GOROOT)."
else
  echo "WARNING: installed version ($INSTALLED) != requested (go$VERSION)."
fi

echo
echo "Done. Open a new terminal, or run:  source $ENV_FILE"
