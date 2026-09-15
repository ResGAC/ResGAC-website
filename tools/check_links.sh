#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Report local references in the HTML that point at files which do not exist.
#
#   bash tools/check_links.sh
#
# A missing video renders as a silent black box on GitHub Pages -- no error,
# no console warning for a casual viewer. This is the check that catches it
# before a reviewer does.
# ---------------------------------------------------------------------------
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

missing=0
grep -ohE '(src|href|poster)="[^"]*"' -- *.html \
  | sed 's/.*="//; s/"$//' \
  | grep -vE '^(https?:|mailto:|#|$)' \
  | sed 's/[?#].*$//' \
  | sort -u \
  | while read -r ref; do
      [ -z "$ref" ] && continue
      if [ -e "$ref" ]; then
        printf '\033[32m ok \033[0m  %s\n' "$ref"
      else
        printf '\033[31mmiss\033[0m  %s\n' "$ref"
        missing=1
      fi
    done

# The loop runs in a subshell, so re-count for the exit status.
n=$(grep -ohE '(src|href|poster)="[^"]*"' -- *.html \
    | sed 's/.*="//; s/"$//; s/[?#].*$//' \
    | grep -vE '^(https?:|mailto:|$)' | sort -u \
    | while read -r r; do [ -n "$r" ] && [ ! -e "$r" ] && echo x; done | wc -l)

echo
if [ "$n" -eq 0 ]; then
  echo "PASS -- every local reference resolves."
else
  echo "$n missing local reference(s) -- these render as blank boxes."
fi
exit $(( n > 0 ))
