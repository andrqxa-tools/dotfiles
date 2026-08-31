# Flutter / Android toolchain for the mabrook projects.
# Managed by dotfiles/Flutter/setup-android-env.sh (symlinked into
# ~/.config/profile.d/). SDK and FVM cache live under /opt/programming (user-owned,
# alongside flutter/go/deno) since the /data HDD was retired 2026-08-30; the AVD stays
# in ~/.android/avd on the system SSD so the emulator feels responsive.
#
# NOTE: keep these paths in sync with ANDROID_SDK_DIR / FVM_CACHE_PATH defaults
# in dotfiles/Flutter/setup-android-env.sh if you ever relocate them.
# JDK 17 — pinned by minitok_clean (README.md, android/app/build.gradle). Debian 13
# ships no openjdk-17, so Temurin is the source there; Ubuntu keeps the openjdk path.
for _j in /usr/lib/jvm/java-17-openjdk-amd64 /usr/lib/jvm/temurin-17-jdk-amd64; do
    [ -x "$_j/bin/javac" ] && { JAVA_HOME="$_j"; export JAVA_HOME; break; }
done
unset _j

export ANDROID_HOME="/opt/programming/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export FVM_CACHE_PATH="/opt/programming/Android/fvm"

# Flutter SDK lives under the /opt/programming layout (shared with Go); mabrook
# projects pin 3.38.5 via `fvm flutter`, so this bin is only the fallback CLI.
# Prepend each dir once — idempotent across login/non-login/GUI/tmux sourcing.
for _d in \
  "$HOME/.pub-cache/bin" \
  "/opt/programming/flutter/bin" \
  "$ANDROID_HOME/emulator" \
  "$ANDROID_HOME/platform-tools" \
  "$ANDROID_HOME/cmdline-tools/latest/bin" \
  ${JAVA_HOME:+"$JAVA_HOME/bin"}
do
  [ -n "$_d" ] || continue          # empty element in PATH means "current dir"
  case ":$PATH:" in
    *":$_d:"*) ;;
    *) PATH="$_d:$PATH" ;;
  esac
done
export PATH
unset _d
