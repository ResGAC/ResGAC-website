#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Strip identifying metadata from videos and images, in place.
#
#   bash tools/scrub_media.sh
#
# mp4 files carry an encoder tag, creation timestamp, and -- when exported from
# an editor -- frequently the absolute source path, which contains a username.
# Images carry EXIF: camera serial, software, sometimes GPS coordinates of the
# lab. Run this on every file before committing it.
#
# Requires ffmpeg (video) and exiftool (images).
# ---------------------------------------------------------------------------
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

if command -v ffmpeg >/dev/null 2>&1; then
  shopt -s nullglob
  for f in assets/videos/*.mp4 assets/videos/*.webm; do
    tmp="${f%.*}.scrubbed.${f##*.}"
    # -map_metadata -1 drops all container metadata; -c copy avoids re-encoding
    # (no quality loss, near-instant). -movflags +faststart puts the index at
    # the front so the video starts playing before it fully downloads.
    ffmpeg -nostdin -loglevel error -y -i "$f" \
      -map_metadata -1 -map_chapters -1 -c copy -movflags +faststart "$tmp"
    mv -f "$tmp" "$f"
    echo "scrubbed  $f"
  done
else
  echo "ffmpeg not found -- videos NOT scrubbed" >&2
fi

if command -v exiftool >/dev/null 2>&1; then
  if compgen -G "assets/imgs/*" > /dev/null; then
    exiftool -q -overwrite_original -all= assets/imgs/*
    echo "scrubbed  assets/imgs/*"
  fi
else
  echo "exiftool not found -- images NOT scrubbed" >&2
fi

# PDFs embed the producing application, and LaTeX PDFs embed the author from
# \author{} in the document metadata even when the visible title block is
# anonymized. This is the single most common leak on anonymous project pages.
if command -v exiftool >/dev/null 2>&1 && compgen -G "assets/pdfs/*.pdf" > /dev/null; then
  echo
  echo "PDF metadata (check Author/Creator/Title by hand):"
  exiftool -s -Author -Creator -Producer -Title assets/pdfs/*.pdf
  echo "  strip with: exiftool -overwrite_original -Author= -Creator= -Title= assets/pdfs/*.pdf"
fi
