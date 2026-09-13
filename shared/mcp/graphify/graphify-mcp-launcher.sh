#!/usr/bin/env bash
# Launcher for the Graphify knowledge-graph MCP server (stdio).
#
# What it does:
#   1. Locates the graphify binary (uv tool install path, then uvx as fallback).
#   2. Resolves the knowledge graph to serve:
#        - $GRAPHIFY_GRAPH_JSON  (explicit absolute path to a graph.json)
#        - $GRAPHIFY_PROJECT_DIR/<graphify-out|GRAPHIFY_OUT>/graph.json
#        - default: ./graphify-out/graph.json  (cwd-relative)
#   3. Starts `graphify-mcp` over stdio, passing the resolved graph path.
#
# This matches the mcp.json convention in this folder: the harness spawns this
# script as the "command", and the env vars come from the shell (populated from
# ~/dev-team/shared/credentials/.env via ~/.bashrc). No secrets live here.

set -euo pipefail

# --- 1. Find the binary -----------------------------------------------------
GRAPHIFY_BIN="${HOME}/.local/bin/graphify-mcp"
if [[ ! -x "${GRAPHIFY_BIN}" ]]; then
    # Fallback: run ad hoc via uvx (slower — downloads/installs the [mcp] extra).
    GRAPHIFY_BIN="$(command -v graphify-mcp || true)"
fi
if [[ -z "${GRAPHIFY_BIN}" ]]; then
    echo "graphify-mcp launcher: not found." >&2
    echo "  Install once with:  ~/.local/bin/uv tool install 'graphifyy[mcp]'" >&2
    exit 1
fi

# --- 2. Resolve the graph.json path ----------------------------------------
resolve_graph() {
    # Explicit absolute path wins.
    if [[ -n "${GRAPHIFY_GRAPH_JSON:-}" ]]; then
        if [[ -f "${GRAPHIFY_GRAPH_JSON}" ]]; then echo "${GRAPHIFY_GRAPH_JSON}"; else return 1; fi
    fi

    # Project-dir convention: <project>/<out>/graph.json
    local project="${GRAPHIFY_PROJECT_DIR:-.}"
    local out="${GRAPHIFY_OUT:-graphify-out}"
    if [[ -f "${project}/${out}/graph.json" ]]; then
        echo "$(realpath "${project}/${out}/graph.json")"
        return 0
    fi
    return 1
}

GRAPH_JSON="$(resolve_graph || true)"
if [[ -z "${GRAPH_JSON:-}" ]]; then
    echo "graphify-mcp launcher: no knowledge graph found (looked for \${GRAPHIFY_GRAPH_JSON}, \${GRAPHIFY_PROJECT_DIR}/\${GRAPHIFY_OUT:-graphify-out}/graph.json, ./graphify-out/graph.json)." >&2
    echo "  Build one with:  cd <project> && graphify update <project>   (or point GRAPHIFY_GRAPH_JSON at an existing graph.json)." >&2
    exit 1
fi

# --- 3. Start the stdio MCP server -----------------------------------------
# Exec replaces this process so the harness owns stdin/stdout directly.
exec "${GRAPHIFY_BIN}" "${GRAPH_JSON}"
