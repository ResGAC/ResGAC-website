#!/usr/bin/env bash
# Preview locally exactly as GitHub Pages will serve it: static files, no build.
#   bash tools/serve.sh   ->  http://localhost:8000
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
echo "serving $(pwd) at http://localhost:8000  (Ctrl-C to stop)"
python3 -m http.server 8000
