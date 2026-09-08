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
# Add your own names/institutions/handles to NEEDLES below. The defaults cover
# the mechanical leaks; only you know the rest.
# ---------------------------------------------------------------------------
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

fail=0
note() { printf '\033[31mLEAK\033[0m  %s\n' "$*"; fail=1; }
ok()   { printf '\033[32m ok \033[0m  %s\n' "$*"; }

# --- 1. Identifying strings in tracked files -------------------------------
# EDIT THIS LIST. Include: every author surname, institution names and their
# abbreviations, lab names, funding-agency grant numbers, internal project
# codenames, personal domains, GitHub handles, and the name of any private
# framework whose name is searchable.
NEEDLES=(
  # 'surname'
  # 'university'
  # 'lab-name'
  # 'grant-number'
  # 'internal-codename'
)
NEEDLES+=( '@gmail' '@.*\.edu' 'orcid' 'acknowledge' 'funded by' 'supported by' 'our previous work' 'our prior work' )

if [ ${#NEEDLES[@]} -gt 0 ]; then
  pattern=$(IFS='|'; echo "${NEEDLES[*]}")
  hits=$(grep -rInE "$pattern" -- . \
        --exclude-dir=.git --exclude-dir=raw_media \
        --exclude=check_anonymity.sh --exclude=MAINTAINER_NOTES.md 2>/dev/null || true)
  if [ -n "$hits" ]; then
    note "identifying strings in tracked files:"; echo "$hits" | sed 's/^/        /'
  else
    ok "no identifying strings matched"
  fi
fi

# --- 2. Git history --------------------------------------------------------
# The commit author is public on GitHub even when the file contents are clean.
if [ -d .git ]; then
  authors=$(git log --format='%an <%ae>%n%cn <%ce>' 2>/dev/null | sort -u)
  bad=$(printf '%s\n' "$authors" | grep -vE '^Anonymous <anonymous@example\.com>$' || true)
  if [ -n "$bad" ]; then
    note "non-anonymous git identities in history:"; printf '%s\n' "$bad" | sed 's/^/        /'
    echo "        fix: git config user.name Anonymous; git config user.email anonymous@example.com"
    echo "        then rewrite existing history, or start a fresh repo with one squashed commit."
  else
    ok "all commits authored by Anonymous"
  fi
fi

# --- 3. Media metadata -----------------------------------------------------
# mp4 containers carry an encoder tag and often a full source path; images
# carry EXIF including camera serial and sometimes GPS.
if command -v exiftool >/dev/null 2>&1; then
  meta=$(exiftool -q -s -Artist -Creator -Author -Software -Encoder -GPSLatitude -Make -Model \
           assets/videos assets/imgs 2>/dev/null | grep -v '^$' || true)
  if [ -n "$meta" ]; then
    note "metadata present in media (run tools/scrub_media.sh):"; echo "$meta" | sed 's/^/        /'
  else
    ok "no identifying media metadata"
  fi
else
  printf '\033[33mskip\033[0m  exiftool not installed -- media metadata unchecked\n'
fi

# --- 4. Absolute paths in HTML/CSS ----------------------------------------
# A stray file:///home/<username>/... in a src= attribute is a direct leak.
paths=$(grep -rInE 'file:///|/home/[a-z0-9_-]+/|/Users/[a-zA-Z0-9._-]+/' -- . \
        --exclude-dir=.git --exclude=check_anonymity.sh 2>/dev/null || true)
if [ -n "$paths" ]; then
  note "absolute local paths:"; echo "$paths" | sed 's/^/        /'
else
  ok "no absolute local paths"
fi

# --- 5. Third-party beacons ------------------------------------------------
beacons=$(grep -rInE 'googletagmanager|google-analytics|gtag\(|plausible\.io|hotjar|clarity\.ms' -- . \
          --exclude-dir=.git --exclude=check_anonymity.sh 2>/dev/null || true)
if [ -n "$beacons" ]; then
  note "analytics/beacon found -- these tie the page to an account:"; echo "$beacons" | sed 's/^/        /'
else
  ok "no analytics beacons"
fi

echo
[ "$fail" -eq 0 ] && echo "PASS -- safe to push." || echo "FAIL -- fix the above before pushing."
exit "$fail"
