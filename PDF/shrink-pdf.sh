#!/usr/bin/env bash
set -euo pipefail

# Shrink a PDF with Ghostscript, in place of emailing a 40MB scan.
#
# Usage: shrink-pdf.sh <in.pdf> [out.pdf] [quality]
#   out.pdf   default: <in>-small.pdf
#   quality   screen | ebook | printer | prepress   (default: ebook)

[[ $# -ge 1 ]] || { sed -n '4,9p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

in=$1
out=${2:-${in%.pdf}-small.pdf}
quality=${3:-ebook}

gs -sDEVICE=pdfwrite \
   -dCompatibilityLevel=1.4 \
   -dPDFSETTINGS="/$quality" \
   -dNOPAUSE -dQUIET -dBATCH \
   -sOutputFile="$out" \
   "$in"

printf '%s -> %s (%s)\n' "$(du -h "$in" | cut -f1)" "$out" "$(du -h "$out" | cut -f1)"
