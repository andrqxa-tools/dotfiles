#!/usr/bin/env bash
# _devsession.sh — спільні хелпери для aidev/godev: підбір УНІКАЛЬНОГО імені
# tmux-сесії, щоб один і той самий скрипт можна було запускати в кількох
# екземплярах (різні проєкти або кілька сесій на один проєкт).
#
# Sourced, not executed.

# ds_slug <path> -> безпечний для tmux суфікс з basename каталогу
# (tmux не любить '.' та ':' в іменах сесій).
ds_slug() {
  local s
  s="$(basename -- "$1")"
  s="${s//[^A-Za-z0-9_-]/-}"     # все інше -> '-'
  s="${s##-}"; s="${s%%-}"
  [ -n "$s" ] || s="root"
  printf '%s' "$s"
}

ds_session_exists() { tmux has-session -t "=$1" 2>/dev/null; }

# ds_session_attached <name> -> 0, якщо до сесії вже підключений клієнт
ds_session_attached() {
  local n
  n="$(tmux display-message -p -t "=$1" '#{session_attached}' 2>/dev/null || echo 0)"
  [ "${n:-0}" -gt 0 ]
}

# ds_pick_session <prefix> <root> [force_new]
#   Друкує ім'я сесії:
#     <prefix>-<slug>            — якщо вільне, або якщо сесія існує але
#                                  до неї ніхто не підключений (перевикористання)
#     <prefix>-<slug>-2, -3, ... — якщо сесія вже відкрита в іншому терміналі,
#                                  або force_new=1
ds_pick_session() {
  local prefix="$1" root="$2" force_new="${3:-0}"
  local base i name
  base="${prefix}-$(ds_slug "$root")"

  if [ "$force_new" != "1" ]; then
    if ! ds_session_exists "$base" || ! ds_session_attached "$base"; then
      printf '%s' "$base"; return 0
    fi
  fi

  for i in $(seq 2 99); do
    name="${base}-${i}"
    if ! ds_session_exists "$name"; then
      printf '%s' "$name"; return 0
    fi
    if [ "$force_new" != "1" ] && ! ds_session_attached "$name"; then
      printf '%s' "$name"; return 0
    fi
  done

  printf '%s-%s' "$base" "$$"
}
