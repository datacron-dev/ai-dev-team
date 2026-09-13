#!/usr/bin/env bash
# Serve a graphify knowledge graph INTERACTIVELY in the browser on a local URL.
#
# graphify builds a force-directed graph.html (vis-network; node/link data
# embedded in the file) plus GRAPH_REPORT.md and graph.json under each project's
# graphify-out/. By default graph.html loads vis-network from a CDN (unpkg).
# This script instead VENDORS vis-network locally and inlines it into a copy
# (index.html), so the interactive graph works with NO external network / CDN.
#
# Usage:
#   graphify-view.sh <project_dir>          # serve <project_dir>/graphify-out
#   graphify-view.sh                        # default: projects/financial-terminal
#   PORT=9000 graphify-view.sh <project>    # custom port (default 8000)
#
# URLs (on localhost):
#   http://localhost:<port>/            -> interactive graph (self-contained)
#   http://localhost:<port>/graph.html  -> graphify's original (needs CDN)
#   http://localhost:<port>/GRAPH_REPORT.md
#
# For a *live query* API (not just viewing):
#   graphify-mcp --transport http --host 127.0.0.1 --port 8080  (MCP endpoint)

set -euo pipefail

DEFAULT_PROJECT="/home/ai-dev/dev-team/projects/financial-terminal"
PROJECT="${1:-${DEFAULT_PROJECT}}"
PROJECT="$(cd "${PROJECT}" && pwd)"
PORT="${PORT:-8000}"
OUT="${PROJECT}/graphify-out"
LIBDIR="${HOME}/.local/share/graphify-view"     # persistent vendor location
LIBFILE="${LIBDIR}/vis-network.min.js"
CDN_URL="https://unpkg.com/vis-network@9.1.6/standalone/umd/vis-network.min.js"

if [[ ! -d "${OUT}" || ! -f "${OUT}/graph.json" ]]; then
    echo "graphify-view: no graph found at ${OUT}" >&2
    echo "Build one first:" >&2
    echo "  cd ${PROJECT} && ~/.local/bin/graphify update ${PROJECT}" >&2
    exit 1
fi

# --- 1. Ensure we have a local copy of vis-network -------------------------
ensure_lib() {
    if [[ -s "${LIBFILE}" ]]; then
        echo "Using local vis-network: ${LIBFILE}"
        return 0
    fi
    echo "Fetching vis-network (one-time, ~0.7 MB) to ${LIBFILE}…"
    mkdir -p "${LIBDIR}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "${LIBFILE}" "${CDN_URL}"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "${LIBFILE}" "${CDN_URL}"
    else
        echo "graphify-view: need curl or wget to fetch vis-network." >&2
        return 1
    fi
    [[ -s "${LIBFILE}" ]] || { echo "graphify-view: download failed." >&2; return 1; }
}
ensure_lib

# --- 2. Build a fully self-contained interactive page (index.html) ---------
# Replace the CDN <script src="...unpkg.../vis-network.min.js" ...> with the
# inlined library so the page works with no network access.
build_index() {
    python3 - "${OUT}/graph.html" "${LIBFILE}" "${OUT}/index.html" <<'PY'
import sys, re
src_html, lib, dst = sys.argv[1], sys.argv[2], sys.argv[3]
html = open(src_html, encoding="utf-8").read()
libjs = open(lib, encoding="utf-8").read()
# Match the exact CDN script tag graphify emits (src=...unpkg...vis-network.min.js...)
pattern = re.compile(
    r'<script\s+src="https://unpkg\.com/vis-network@[^"]+"[^>]*>\s*</script>',
    re.S,
)
if not pattern.search(html):
    # Fallback: any script tag whose src contains vis-network (some graphify
    # versions may differ); still inline it.
    pattern = re.compile(r'<script\s+src="[^"]*vis-network[^"]*"[^>]*>\s*</script>', re.S)
if not pattern.search(html):
    sys.exit("graphify-view: could not find the vis-network <script> in graph.html to vendor.")
# Use a lambda so backslashes in the inlined JS are NOT treated as re escapes.
replacement = f'<script>/* vis-network v9.1.6 (vendored, self-contained) */\n{libjs}\n</script>'
html = pattern.sub(lambda _m: replacement, html)
open(dst, "w", encoding="utf-8").write(html)
print(f"  Wrote self-contained interactive page: {dst}")
PY
}
build_index

# NOTE: this script does NOT open a browser. It prints the URL and serves; the
# caller (human or agent) opens the link. This keeps behavior predictable on
# headless/remote boxes and avoids surprise popups.

echo "Serving  ${OUT}  (interactive, self-contained)"
echo "  Graph:  http://localhost:${PORT}/"
echo "  (graph.html also available: http://localhost:${PORT}/graph.html  [needs CDN])"
echo "  Report: http://localhost:${PORT}/GRAPH_REPORT.md"
echo "Open http://localhost:${PORT}/ in your browser. Ctrl-C to stop."
echo ""

# index.html is the self-contained interactive graph.
exec python3 -m http.server "${PORT}" --directory "${OUT}"
