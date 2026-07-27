#!/usr/bin/env bash
#
# setup-android-env.sh
# ---------------------------------------------------------------------------
# Installs everything that is MISSING to build/run the mabrook Flutter projects
# (minitok_clean, wallet-front/example) for Android on this machine.
#
# Already present on the machine (verified):
#   * Flutter 3.41.6 in /opt/programming/flutter (projects pin 3.38.5 via FVM)
#   * OpenJDK 21 — but that is a JRE, no javac (Gradle needs a full JDK 17)
#
# What is missing and what this script installs:
#   1. JDK 17         (the project's Gradle/Kotlin toolchain targets Java 17)
#   2. Android SDK    (cmdline-tools, platform-tools/adb, platforms 35+36,
#                      build-tools, NDK 28.2.13676358) — currently absent.
#                      Installed on /data (HDD, 363G): the system SSD (/) is
#                      nearly full.
#   3. FVM + Flutter 3.38.5 (the version pinned in .fvmrc of both projects)
#   4. (opt.) emulator: system image API 34 + a ready-to-use AVD
#
# Project requirements (minitok_clean/README.md, android/app/build.gradle):
#   compileSdk 36 · targetSdk 35 · minSdk 26 · NDK 28.2.13676358 · Java 17
#
# Usage:
#   ./setup-android-env.sh            # JDK17 + Android SDK + FVM/Flutter
#   ./setup-android-env.sh --emulator # same + system image and AVD
#   ./setup-android-env.sh --no-fvm   # skip the FVM/Flutter step
#
# RUN AS YOUR NORMAL USER, NOT under sudo — the script calls sudo itself where
# it is needed. Under root $HOME becomes /root: the env symlink,
# ~/.pub-cache/bin/fvm and the AVD all land in /root, while the SDK and the FVM
# cache end up root-owned (git then complains "detected dubious ownership" and
# Gradle/fvm cannot write into them).
#
# The script is idempotent: re-running it breaks nothing. If an earlier run did
# go through sudo, the SDK/FVM-cache ownership is repaired automatically.
# Targets Ubuntu 24.04 (apt). Uses sudo only for apt packages.
# ---------------------------------------------------------------------------
set -euo pipefail

# ------------------------------ settings ------------------------------------
# The system SSD (/) is small — ~28G free. The bulky SDK parts (NDK ~2.5G,
# platforms, emulator image) go to /data (HDD, but 363G free). $HOME is on /
# too, so the default $HOME/Android/Sdk would fill the SSD.
# Override with: ANDROID_SDK_DIR=...
ANDROID_SDK_DIR="${ANDROID_SDK_DIR:-/data/Android/Sdk}"
# Each Flutter version in FVM is ~1.7G — moved to /data as well. The fvm binary
# itself (a few MB) stays in ~/.pub-cache, which is not a space concern.
export FVM_CACHE_PATH="${FVM_CACHE_PATH:-/data/Android/fvm}"
CMDLINE_TOOLS_ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

# Versions taken from minitok_clean/android/app/build.gradle
PLATFORM_PRIMARY="platforms;android-36"   # compileSdk 36
PLATFORM_TARGET="platforms;android-35"    # targetSdk 35
BUILD_TOOLS_1="build-tools;36.0.0"
BUILD_TOOLS_2="build-tools;35.0.0"
NDK_VERSION="28.2.13676358"

# Flutter version pinned in .fvmrc
FLUTTER_PINNED="3.38.5"

# Emulator (only used with the --emulator flag)
EMULATOR_IMAGE="system-images;android-34;google_apis;x86_64"
AVD_NAME="mabrook_api34"

INSTALL_EMULATOR=false
INSTALL_FVM=true

for arg in "$@"; do
  case "$arg" in
    --emulator) INSTALL_EMULATOR=true ;;
    --no-fvm)   INSTALL_FVM=false ;;
    -h|--help)  grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $arg (see --help)"; exit 1 ;;
  esac
done

log()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
err()  { printf '\n\033[1;31m[ERROR] %s\033[0m\n' "$*" >&2; }
ok()   { printf '\033[1;32m[ok] %s\033[0m\n' "$*"; }

# ---------------------------- 0. refuse to run as root ----------------------
# Half of the steps write into $HOME (env symlink, ~/.pub-cache/bin/fvm,
# ~/.android/avd), and sudo replaces $HOME with /root — under root the script
# would "successfully" configure the wrong user and leave the SDK root-owned.
# Checked before anything is touched.
ensure_not_root() {
  [ "${EUID:-$(id -u)}" -ne 0 ] && return
  err "Started as root (sudo). Don't — the script calls sudo itself where needed."
  cat >&2 <<'EOF'
  Under sudo the following breaks:
    * env symlink goes to /root/.config/profile.d/ instead of your $HOME
    * fvm is installed into /root/.pub-cache/bin (never on your PATH)
    * the AVD is created in /root/.android/avd (the emulator won't find it)
    * SDK and FVM cache become root-owned -> git "dubious ownership",
      Gradle cannot write

  Run it without sudo:
    ./setup-android-env.sh
EOF
  # SUDO_USER tells us who invoked sudo — mention it unless that was root too.
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
    printf '\n  I.e.: sudo -u %s ./setup-android-env.sh  (or just drop the sudo)\n' "$SUDO_USER" >&2
  fi
  exit 1
}

# -------------- 0.5 repair ownership left behind by a sudo run --------------
# One-shot self-heal for machines where the script was already run through
# sudo: chown -R the SDK and the FVM cache. Without it `fvm flutter` dies with
# "detected dubious ownership" (git refuses a repo owned by someone else), and
# sdkmanager/Gradle cannot write into the SDK. The directories may not exist
# yet — that is fine.
fix_ownership() {
  local d owner fixed=false
  for d in "$ANDROID_SDK_DIR" "$FVM_CACHE_PATH"; do
    [ -e "$d" ] || continue
    owner="$(stat -c '%U' "$d")"
    [ "$owner" = "$(id -un)" ] && continue
    log "$d is owned by $owner, not $(id -un) (leftovers from a sudo run)"
    warn "Repairing: sudo chown -R $(id -un):$(id -gn) $d"
    sudo chown -R "$(id -un):$(id -gn)" "$d"
    fixed=true
  done
  [ "$fixed" = true ] && ok "Ownership repaired"
  return 0
}

# --------------------------- 1. JDK 17 --------------------------------------
install_jdk17() {
  log "JDK 17"
  if [ -x /usr/lib/jvm/java-17-openjdk-amd64/bin/javac ]; then
    ok "JDK 17 already installed"
    return
  fi
  warn "Only JRE 21 found (no javac). Installing openjdk-17-jdk..."
  sudo apt-get update -y
  sudo apt-get install -y openjdk-17-jdk
  ok "JDK 17 installed"
}

# ------------------------ 2. system dependencies ----------------------------
install_deps() {
  log "System utilities (curl, unzip, git)"
  sudo apt-get update -y
  sudo apt-get install -y curl unzip zip git
}

# --------------------- 3. Android SDK (cmdline-tools) -----------------------
install_android_sdk() {
  log "Android SDK -> $ANDROID_SDK_DIR"
  local latest_dir="$ANDROID_SDK_DIR/cmdline-tools/latest"

  if [ ! -x "$latest_dir/bin/sdkmanager" ]; then
    warn "cmdline-tools not found — downloading..."
    mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
    local tmp
    tmp="$(mktemp -d)"
    curl -fL "$CMDLINE_TOOLS_ZIP_URL" -o "$tmp/cmdline-tools.zip"
    unzip -q "$tmp/cmdline-tools.zip" -d "$tmp"
    # the archive unpacks into a "cmdline-tools" directory — move it into latest/
    rm -rf "$latest_dir"
    mkdir -p "$latest_dir"
    mv "$tmp/cmdline-tools/"* "$latest_dir/"
    rm -rf "$tmp"
    ok "cmdline-tools installed"
  else
    ok "cmdline-tools already in place"
  fi

  export ANDROID_HOME="$ANDROID_SDK_DIR"
  export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
  export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
  local sdkmanager="$latest_dir/bin/sdkmanager"

  log "Accepting Android SDK licenses"
  yes | "$sdkmanager" --sdk_root="$ANDROID_SDK_DIR" --licenses >/dev/null || true

  log "Installing SDK components (takes a while, NDK is ~2.5 GB)"
  local pkgs=(
    "platform-tools"
    "cmdline-tools;latest"
    "$PLATFORM_PRIMARY"
    "$PLATFORM_TARGET"
    "$BUILD_TOOLS_1"
    "$BUILD_TOOLS_2"
    "ndk;$NDK_VERSION"
  )
  if [ "$INSTALL_EMULATOR" = true ]; then
    pkgs+=("emulator" "$EMULATOR_IMAGE")
  fi
  "$sdkmanager" --sdk_root="$ANDROID_SDK_DIR" "${pkgs[@]}"
  ok "SDK components installed"
}

# ------------------------ 4. environment variables --------------------------
# The env lives in the dotfiles repo itself (Shell/profile.d/flutter.sh) and is
# symlinked into ~/.config/profile.d/, from where .bashrc/.profile/.bash_profile
# load it (the loader block is already there). That way the config travels to
# another machine together with the repo.
setup_env() {
  log "Wiring env through ~/.config/profile.d (dotfiles)"
  local repo_root env_src env_dst self
  # readlink -f: the script may be invoked through a symlink (e.g. from a
  # project directory) — BASH_SOURCE then points at the symlink, while we need
  # the real path inside dotfiles.
  self="$(readlink -f "${BASH_SOURCE[0]}")"
  repo_root="$(cd "$(dirname "$self")/.." && pwd)"
  env_src="$repo_root/Shell/profile.d/flutter.sh"
  env_dst="$HOME/.config/profile.d/flutter.sh"
  if [ ! -f "$env_src" ]; then
    warn "$env_src not found — the script must live in dotfiles/Flutter/. Env not wired."
    return
  fi
  mkdir -p "$HOME/.config/profile.d"
  ln -sfn "$env_src" "$env_dst"
  ok "Symlink: $env_dst -> $env_src"
  warn "Apply now: source '$env_dst'  (or log out and back in)"
}

# -------------------------- 5. FVM + Flutter 3.38.5 -------------------------
install_fvm() {
  [ "$INSTALL_FVM" = true ] || { warn "Skipping FVM (--no-fvm)"; return; }
  log "FVM + Flutter $FLUTTER_PINNED"
  export PATH="/opt/programming/flutter/bin:$HOME/.pub-cache/bin:$PATH"
  if ! command -v fvm >/dev/null 2>&1; then
    dart pub global activate fvm
  fi
  local fvm_bin="$HOME/.pub-cache/bin/fvm"
  "$fvm_bin" install "$FLUTTER_PINNED"
  ok "Flutter $FLUTTER_PINNED installed through FVM"
  warn "In a project directory use: fvm use $FLUTTER_PINNED, then fvm flutter ..."
}

# --------------------- 5.5 KVM (emulator acceleration) ----------------------
ensure_kvm() {
  [ "$INSTALL_EMULATOR" = true ] || return
  log "Checking KVM (hardware acceleration for the emulator)"
  if [ ! -e /dev/kvm ]; then
    warn "/dev/kvm is missing — enable virtualization (SVM/AMD-V) in the BIOS, otherwise the emulator will be painfully slow."
    return
  fi
  if id -nG "$USER" | tr ' ' '\n' | grep -qx kvm; then
    ok "User is already in the kvm group"
  else
    warn "User is not in the kvm group — adding (needs sudo)..."
    sudo usermod -aG kvm "$USER"
    warn "Done. LOG OUT AND BACK IN (or reboot) — otherwise the kvm group is not picked up and the emulator won't start accelerated."
  fi
}

# ---------------------------- 6. AVD (emulator) -----------------------------
# The AVD (the running emulator's image) is deliberately left in ~/.android/avd
# on the SSD — it is what determines how smooth the emulator feels; the SDK
# itself still lives on /data (HDD).
create_avd() {
  [ "$INSTALL_EMULATOR" = true ] || return
  log "Creating AVD '$AVD_NAME'"
  local avdmanager="$ANDROID_SDK_DIR/cmdline-tools/latest/bin/avdmanager"
  if "$avdmanager" list avd 2>/dev/null | grep -q "$AVD_NAME"; then
    ok "AVD '$AVD_NAME' already exists"
  else
    echo "no" | "$avdmanager" create avd -n "$AVD_NAME" -k "$EMULATOR_IMAGE" --device "pixel_6"
    ok "AVD created. Start it with: emulator -avd $AVD_NAME"
  fi
}

# ------------------------------ 7. flutter doctor ---------------------------
finalize() {
  log "flutter config + doctor"
  export PATH="/opt/programming/flutter/bin:$PATH"
  export ANDROID_HOME="$ANDROID_SDK_DIR"
  flutter config --android-sdk "$ANDROID_SDK_DIR" >/dev/null 2>&1 || true
  yes | flutter doctor --android-licenses >/dev/null 2>&1 || true
  flutter doctor -v || true
}

main() {
  ensure_not_root
  fix_ownership
  install_deps
  install_jdk17
  install_android_sdk
  setup_env
  install_fvm
  ensure_kvm
  create_avd
  finalize
  log "Done."
  echo "Next:"
  echo "  1) source ~/.config/profile.d/flutter.sh   # or log out and back in, to pick up the env"
  echo "  2) cd wallet-front && flutter pub get"
  echo "  3) cd example && flutter pub get && flutter run   # run the example"
  echo
  echo "Building for Android needs the env/ files (env-dev.json) — get them from the team."
}

main "$@"
