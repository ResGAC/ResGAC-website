#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Pre-push anonymity gate.
#
# Greps the tree for strings that would identify the authors, and inspects the
# git history and media metadata -- the three places a double-blind project
# page actually leaks. Exits non-zero if anything is found.
#
#   bash tools/check_anonymity.sh
#
# Only git-TRACKED files are scanned, since only those get published; this
# script excludes itself (its own needle list would match every time).
#
# Add your own names/institutions/handles to NEEDLES below. The defaults cover
# the mechanical leaks; only you know the rest.
# ---------------------------------------------------------------------------
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

fail=0
note() { printf '\033[31mLEAK\033[0m  %s\n' "$*"; fail=1; }
ok()   { printf '\033[32m ok \033[0m  %s\n' "$*"; }
skip() { printf '\033[33mskip\033[0m  %s\n' "$*"; }

SELF="tools/check_anonymity.sh"

# Files that will actually be published, minus this script.
if git rev-parse --git-dir >/dev/null 2>&1; then
  mapfile -t FILES < <(git ls-files | grep -vxF "$SELF")
else
  skip "not a git repo -- scanning the working tree instead"
  mapfile -t FILES < <(find . -type f -not -path './.git/*' -printf '%P\n' | grep -vxF "$SELF")
fi
[ ${#FILES[@]} -eq 0 ] && { echo "no files to scan"; exit 0; }

scan() { # scan <label> <extended-regex> <remedy>
  local hits
  hits=$(grep -InE "$2" "${FILES[@]}" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    note "$1"
    printf '%s\n' "$hits" | sed 's/^/        /'
    [ -n "${3:-}" ] && echo "        fix: $3"
  else
    ok "$1 -- clean"
  fi
}

# --- 1. Identifying strings ------------------------------------------------
# EDIT THIS LIST. Include: every author surname, institution names and their
# abbreviations, lab names, funding-agency grant numbers, internal project
# codenames, personal domains, and GitHub handles.
NEEDLES=(
  # 'surname'
  # 'university'
  # 'lab-name'
  # 'grant-number'
  # 'internal-codename'
)
# Generic patterns that catch the usual mechanical leaks.
NEEDLES+=(
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.(edu|com|org|ac\.[a-z]{2})'
  'orcid'
  'acknowledge?ments?'
  '(funded|supported) by (the |an? )?[A-Z]'
  'our (previous|prior|earlier) (work|paper)'
  'github\.com/[A-Za-z0-9-]+/'
)
pattern=$(IFS='|'; echo "${NEEDLES[*]}")
scan "identifying strings" "$pattern" "remove, or rephrase in the third person"

# --- 2. Absolute local paths -----------------------------------------------
scan "absolute local paths" 'file:///|/home/[a-z0-9_-]+/|/Users/[A-Za-z0-9._-]+/' \
     "use paths relative to the repo root"

# --- 3. Analytics / beacons ------------------------------------------------
scan "analytics beacons" 'googletagmanager|google-analytics|gtag\(|plausible\.io|hotjar|clarity\.ms' \
     "delete -- these tie the page to an account"

# --- 4. Git history --------------------------------------------------------
# The commit author is public on GitHub even when file contents are clean.
if git rev-parse --git-dir >/dev/null 2>&1 && git log -1 >/dev/null 2>&1; then
  bad=$(git log --format='%an <%ae>%n%cn <%ce>' | sort -u \
        | grep -vE '^Anonymous <anonymous@example\.com>$' || true)
  if [ -n "$bad" ]; then
    note "non-anonymous git identities in history"
    printf '%s\n' "$bad" | sed 's/^/        /'
    echo "        fix: git config user.name Anonymous && git config user.email anonymous@example.com"
    echo "             then rm -rf .git and re-commit -- history rewriting is not worth it here"
  else
    ok "git history -- all commits authored by Anonymous"
  fi
else
  skip "no commits yet -- git history unchecked"
fi

# --- 5. Media metadata -----------------------------------------------------
# mp4 containers carry an encoder tag and often a full source path; images
# carry EXIF including camera serial and sometimes GPS; LaTeX PDFs carry
# \author{} even when the visible title block is anonymized.
if command -v exiftool >/dev/null 2>&1; then
  meta=$(exiftool -q -q -s -Artist -Creator -Author -Software -Encoder \
           -GPSLatitude -Make -Model -Title \
           assets/videos assets/imgs assets/pdfs 2>/dev/null | grep -v '^$' || true)
  if [ -n "$meta" ]; then
    note "metadata present in media"
    printf '%s\n' "$meta" | sed 's/^/        /'
    echo "        fix: bash tools/scrub_media.sh"
  else
    ok "media metadata -- clean"
  fi
else
  skip "exiftool not installed -- media metadata UNCHECKED (this is leak #1; install it)"
fi

# --- 6. Unfinished template markers ---------------------------------------
todo=$(grep -InE 'REPLACE' "${FILES[@]}" 2>/dev/null | wc -l)
[ "$todo" -gt 0 ] && skip "$todo REPLACE marker(s) still in the page (not a leak, but not publishable)"

echo
if [ "$fail" -eq 0 ]; then echo "PASS -- safe to push."; else echo "FAIL -- fix the above before pushing."; fi
exit "$fail"
