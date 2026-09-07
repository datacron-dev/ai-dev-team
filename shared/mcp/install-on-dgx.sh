#!/usr/bin/env bash
# Pre-install MCP server packages on the DGX so the first invocation is fast.
# Safe to re-run. Reads no secrets; just warms caches.

set -euo pipefail

UV="${HOME}/.local/bin/uv"
UVX="${HOME}/.local/bin/uvx"

if [[ ! -x "${UVX}" ]]; then
    echo "installing uv…"
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

echo "==> Pre-warming npm packages"
npx -y kubernetes-mcp-server@latest --help >/dev/null 2>&1 || true
npx -y @playwright/mcp@latest --help >/dev/null 2>&1 || true

echo "==> Pre-warming uv-installed servers (may take a few minutes on first run)"
"${UVX}" --help >/dev/null

# These packages will be cached under ~/.cache/uv after first run
for pkg in \
    "pagerduty-mcp-server" \
    "docker-mcp"
do
    echo "  → ${pkg}"
    "${UVX}" --from "${pkg}" --help >/dev/null 2>&1 || echo "    (skipped — invoke manually)"
done

# Git-based servers — clone to uv cache
for repo in \
    "git+https://github.com/redis/mcp-redis.git" \
    "git+https://github.com/polygon-io/mcp_polygon" \
    "git+https://github.com/alpacahq/alpaca-mcp-server"
do
    echo "  → ${repo}"
    "${UVX}" --from "${repo}" --help >/dev/null 2>&1 || echo "    (skipped — invoke manually)"
done

echo ""
echo "==> Done. MCP packages cached."
echo "Now: fill in API keys in ~/.config/claude-code/mcp.json (or ~/.claude.json 'mcpServers' block)."
