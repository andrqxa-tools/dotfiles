# Flutter / Android toolchain for the mabrook projects.
# Managed by dotfiles/Flutter/setup-android-env.sh (symlinked into
# ~/.config/profile.d/). The heavy SDK and the FVM version cache live on /data
# (HDD, 363G) because the system SSD (/) is small; only the emulator AVD stays
# on the SSD (~/.android/avd) so the emulator itself feels responsive.
#
# NOTE: keep these paths in sync with ANDROID_SDK_DIR / FVM_CACHE_PATH defaults
# in dotfiles/Flutter/setup-android-env.sh if you ever relocate them.
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
export ANDROID_HOME="/data/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export FVM_CACHE_PATH="/data/Android/fvm"

# Flutter SDK lives under the /opt/programming layout (shared with Go); mabrook
# projects pin 3.38.5 via `fvm flutter`, so this bin is only the fallback CLI.
# Prepend each dir once — idempotent across login/non-login/GUI/tmux sourcing.
for _d in \
  "$HOME/.pub-cache/bin" \
  "/opt/programming/flutter/bin" \
  "$ANDROID_HOME/emulator" \
  "$ANDROID_HOME/platform-tools" \
  "$ANDROID_HOME/cmdline-tools/latest/bin" \
  "$JAVA_HOME/bin"
do
  case ":$PATH:" in
    *":$_d:"*) ;;
    *) PATH="$_d:$PATH" ;;
  esac
done
export PATH
unset _d
