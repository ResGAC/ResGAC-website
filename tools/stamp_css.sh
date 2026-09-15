#!/usr/bin/env bash
# Stamp the stylesheet link with a hash of its contents: style.css?v=<hash>.
#
#   bash tools/stamp_css.sh
#
# GitHub Pages lets browsers cache CSS for ~10 minutes, so after a push a
# visitor can get the new HTML with the old stylesheet -- the layout then looks
# broken in ways the repo does not. A changed ?v= makes the browser fetch the
# new file. Run this after any edit to assets/css/style.css, before committing.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
v=$(sha1sum assets/css/style.css | cut -c1-8)
for f in index.html details.html; do
  sed -i -E "s#assets/css/style\.css(\?v=[0-9a-f]+)?\"#assets/css/style.css?v=${v}\"#" "$f"
done
grep -H -o 'assets/css/style\.css?v=[0-9a-f]*' index.html details.html
