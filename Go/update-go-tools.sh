#!/usr/bin/env bash
set -euo pipefail

# Update installed Go tools (gopls, dlv, staticcheck, goimports, ...) to
# @latest, rebuilding them with the CURRENT Go toolchain. Run this after a
# major Go upgrade so tools (especially gopls) stay in step.
#
# The list is auto-discovered from $GOPATH/bin via each binary's embedded
# module info (go version -m) — nothing is hardcoded.
#
# golangci-lint is skipped on purpose: it runs from a pinned Docker image in
# generated projects, so bump that version by hand in the Taskfile instead.

BIN_DIR="$(go env GOPATH)/bin"
[ -d "$BIN_DIR" ] || { echo "No $BIN_DIR — nothing to update."; exit 0; }

echo "Updating Go tools in $BIN_DIR (rebuilding with $(go env GOVERSION))..."
echo

shopt -s nullglob
updated=0 skipped=0 failed=0

for bin in "$BIN_DIR"/*; do
  [ -f "$bin" ] && [ -x "$bin" ] || continue
  name="$(basename "$bin")"

  if [ "$name" = "golangci-lint" ]; then
    echo "skip    $name (Dockerized — pin the version by hand)"
    skipped=$((skipped + 1))
    continue
  fi

  pkg="$(go version -m "$bin" 2>/dev/null | awk '$1 == "path" { print $2; exit }')"
  if [ -z "$pkg" ]; then
    echo "skip    $name (no module info)"
    skipped=$((skipped + 1))
    continue
  fi

  printf 'update  %-20s <- %s@latest\n' "$name" "$pkg"
  if go install "$pkg@latest"; then
    updated=$((updated + 1))
  else
    echo "FAIL    $name"
    failed=$((failed + 1))
  fi
done

echo
echo "Done: $updated updated, $skipped skipped, $failed failed."
