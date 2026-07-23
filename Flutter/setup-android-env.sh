#!/usr/bin/env bash
#
# setup-android-env.sh
# ---------------------------------------------------------------------------
# Устанавливает всё, чего НЕ хватает для сборки/запуска Flutter-проектов
# mabrook (minitok_clean, wallet-front/example) под Android на этой машине.
#
# Что уже есть на машине (проверено):
#   * Flutter 3.41.6 в /opt/programming/flutter  (проекты пинят 3.38.5 через FVM)
#   * OpenJDK 21 — но это JRE, без javac (для Gradle нужен полноценный JDK 17)
#
# Чего НЕ хватает и что доставит этот скрипт:
#   1. JDK 17         (Gradle/Kotlin toolchain проекта завязан на Java 17)
#   2. Android SDK    (cmdline-tools, platform-tools/adb, platforms 35+36,
#                      build-tools, NDK 28.2.13676358) — сейчас отсутствует
#                      Ставится на /data (HDD, 363G): системный SSD (/) почти забит.
#   3. FVM + Flutter 3.38.5 (версия, запинованная в .fvmrc обоих проектов)
#   4. (опц.) эмулятор: system image API 34 + готовый AVD
#
# Требования проектов (minitok_clean/README.md, android/app/build.gradle):
#   compileSdk 36 · targetSdk 35 · minSdk 26 · NDK 28.2.13676358 · Java 17
#
# Использование:
#   ./setup-android-env.sh            # JDK17 + Android SDK + FVM/Flutter
#   ./setup-android-env.sh --emulator # то же + system image и AVD
#   ./setup-android-env.sh --no-fvm   # пропустить установку FVM/Flutter
#
# Скрипт идемпотентен: повторный запуск ничего не ломает.
# Рассчитан на Ubuntu 24.04 (apt). Использует sudo только для apt-пакетов.
# ---------------------------------------------------------------------------
set -euo pipefail

# ----------------------------- настройки -----------------------------------
# Системный SSD (/) мал — свободно ~28G. Крупняк SDK (NDK ~2.5G, платформы,
# образ эмулятора) кладём на /data (HDD, но 363G свободно). $HOME тоже на /,
# поэтому дефолт $HOME/Android/Sdk забил бы SSD. Переопределить: ANDROID_SDK_DIR=...
ANDROID_SDK_DIR="${ANDROID_SDK_DIR:-/data/Android/Sdk}"
# Каждая версия Flutter в FVM ~1.7G — тоже уводим на /data. Сам бинарь fvm
# (несколько МБ) остаётся в ~/.pub-cache, это не критично для места.
export FVM_CACHE_PATH="${FVM_CACHE_PATH:-/data/Android/fvm}"
CMDLINE_TOOLS_ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

# Версии из minitok_clean/android/app/build.gradle
PLATFORM_PRIMARY="platforms;android-36"   # compileSdk 36
PLATFORM_TARGET="platforms;android-35"    # targetSdk 35
BUILD_TOOLS_1="build-tools;36.0.0"
BUILD_TOOLS_2="build-tools;35.0.0"
NDK_VERSION="28.2.13676358"

# Версия Flutter, запинованная в .fvmrc
FLUTTER_PINNED="3.38.5"

# Эмулятор (используется только с флагом --emulator)
EMULATOR_IMAGE="system-images;android-34;google_apis;x86_64"
AVD_NAME="mabrook_api34"

INSTALL_EMULATOR=false
INSTALL_FVM=true

for arg in "$@"; do
  case "$arg" in
    --emulator) INSTALL_EMULATOR=true ;;
    --no-fvm)   INSTALL_FVM=false ;;
    -h|--help)  grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный аргумент: $arg (см. --help)"; exit 1 ;;
  esac
done

log()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m[ok] %s\033[0m\n' "$*"; }

# --------------------------- 1. JDK 17 --------------------------------------
install_jdk17() {
  log "JDK 17"
  if [ -x /usr/lib/jvm/java-17-openjdk-amd64/bin/javac ]; then
    ok "JDK 17 уже установлен"
    return
  fi
  warn "Найден только JRE 21 (без javac). Ставлю openjdk-17-jdk..."
  sudo apt-get update -y
  sudo apt-get install -y openjdk-17-jdk
  ok "JDK 17 установлен"
}

# ---------------------- 2. системные зависимости ----------------------------
install_deps() {
  log "Системные утилиты (curl, unzip, git)"
  sudo apt-get update -y
  sudo apt-get install -y curl unzip zip git
}

# --------------------- 3. Android SDK (cmdline-tools) -----------------------
install_android_sdk() {
  log "Android SDK -> $ANDROID_SDK_DIR"
  local latest_dir="$ANDROID_SDK_DIR/cmdline-tools/latest"

  if [ ! -x "$latest_dir/bin/sdkmanager" ]; then
    warn "cmdline-tools не найдены — скачиваю..."
    mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
    local tmp
    tmp="$(mktemp -d)"
    curl -fL "$CMDLINE_TOOLS_ZIP_URL" -o "$tmp/cmdline-tools.zip"
    unzip -q "$tmp/cmdline-tools.zip" -d "$tmp"
    # архив распаковывается в каталог "cmdline-tools" — переносим в latest/
    rm -rf "$latest_dir"
    mkdir -p "$latest_dir"
    mv "$tmp/cmdline-tools/"* "$latest_dir/"
    rm -rf "$tmp"
    ok "cmdline-tools установлены"
  else
    ok "cmdline-tools уже на месте"
  fi

  export ANDROID_HOME="$ANDROID_SDK_DIR"
  export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
  export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
  local sdkmanager="$latest_dir/bin/sdkmanager"

  log "Принимаю лицензии Android SDK"
  yes | "$sdkmanager" --sdk_root="$ANDROID_SDK_DIR" --licenses >/dev/null || true

  log "Устанавливаю SDK-компоненты (это займёт время, NDK ~2.5 ГБ)"
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
  ok "SDK-компоненты установлены"
}

# ------------------------ 4. переменные окружения ---------------------------
# env хранится в самом dotfiles-репо (Shell/profile.d/flutter.sh) и симлинкается
# в ~/.config/profile.d/, откуда его грузят .bashrc/.profile/.bash_profile
# (loader-блок уже есть). Так конфиг переносится на другую машину вместе с репо.
setup_env() {
  log "Подключаю env через ~/.config/profile.d (dotfiles)"
  local repo_root env_src env_dst self
  # readlink -f: скрипт может вызываться через симлинк (напр. из каталога проекта) —
  # BASH_SOURCE тогда указывает на симлинк, а нам нужен реальный путь в dotfiles.
  self="$(readlink -f "${BASH_SOURCE[0]}")"
  repo_root="$(cd "$(dirname "$self")/.." && pwd)"
  env_src="$repo_root/Shell/profile.d/flutter.sh"
  env_dst="$HOME/.config/profile.d/flutter.sh"
  if [ ! -f "$env_src" ]; then
    warn "Не найден $env_src — скрипт должен лежать в dotfiles/Flutter/. env не подключён."
    return
  fi
  mkdir -p "$HOME/.config/profile.d"
  ln -sfn "$env_src" "$env_dst"
  ok "Симлинк: $env_dst -> $env_src"
  warn "Применить сейчас: source '$env_dst'  (или перелогинься)"
}

# -------------------------- 5. FVM + Flutter 3.38.5 -------------------------
install_fvm() {
  [ "$INSTALL_FVM" = true ] || { warn "Пропускаю FVM (--no-fvm)"; return; }
  log "FVM + Flutter $FLUTTER_PINNED"
  export PATH="/opt/programming/flutter/bin:$HOME/.pub-cache/bin:$PATH"
  if ! command -v fvm >/dev/null 2>&1; then
    dart pub global activate fvm
  fi
  local fvm_bin="$HOME/.pub-cache/bin/fvm"
  "$fvm_bin" install "$FLUTTER_PINNED"
  ok "Flutter $FLUTTER_PINNED установлен через FVM"
  warn "В каталоге проекта используйте: fvm use $FLUTTER_PINNED, затем fvm flutter ..."
}

# ---------------------- 5.5 KVM (ускорение эмулятора) -----------------------
ensure_kvm() {
  [ "$INSTALL_EMULATOR" = true ] || return
  log "Проверяю KVM (аппаратное ускорение эмулятора)"
  if [ ! -e /dev/kvm ]; then
    warn "/dev/kvm нет — включи виртуализацию (SVM/AMD-V) в BIOS, иначе эмулятор будет крайне медленным."
    return
  fi
  if id -nG "$USER" | tr ' ' '\n' | grep -qx kvm; then
    ok "Пользователь уже в группе kvm"
  else
    warn "Пользователь не в группе kvm — добавляю (нужен sudo)..."
    sudo usermod -aG kvm "$USER"
    warn "Готово. ПЕРЕЛОГИНЬСЯ (или reboot) — иначе группа kvm не подхватится и эмулятор не стартует аппаратно."
  fi
}

# ---------------------------- 6. AVD (эмулятор) -----------------------------
# AVD (образ работающего эмулятора) намеренно оставляем в ~/.android/avd на SSD —
# именно он определяет плавность эмулятора; сам SDK при этом лежит на /data (HDD).
create_avd() {
  [ "$INSTALL_EMULATOR" = true ] || return
  log "Создаю AVD '$AVD_NAME'"
  local avdmanager="$ANDROID_SDK_DIR/cmdline-tools/latest/bin/avdmanager"
  if "$avdmanager" list avd 2>/dev/null | grep -q "$AVD_NAME"; then
    ok "AVD '$AVD_NAME' уже существует"
  else
    echo "no" | "$avdmanager" create avd -n "$AVD_NAME" -k "$EMULATOR_IMAGE" --device "pixel_6"
    ok "AVD создан. Запуск: emulator -avd $AVD_NAME"
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
  install_deps
  install_jdk17
  install_android_sdk
  setup_env
  install_fvm
  ensure_kvm
  create_avd
  finalize
  log "Готово."
  echo "Дальше:"
  echo "  1) source ~/.config/profile.d/flutter.sh   # или перелогинься — подхватить env"
  echo "  2) cd wallet-front && flutter pub get"
  echo "  3) cd example && flutter pub get && flutter run   # запуск примера"
  echo
  echo "Для сборки под Android нужен файл env/ (env-dev.json) — взять у команды."
}

main "$@"
