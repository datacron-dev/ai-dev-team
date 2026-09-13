# MCP Server Configuration — Financial Terminal

This folder pre-stages the MCP servers that don't already exist as Perplexity native connectors. Native Perplexity connectors handle the majority — install these only for the gaps.

## Layout

```
shared/mcp/
├── mcp.json                 # MCP server definitions (merge into ~/.claude.json / ~/.cursor/mcp.json)
├── README.md                # this file
├── bin/
│   └── install-on-dgx.sh    # one-time cache pre-warm so first invocation is fast
└── graphify/                # Graphify knowledge-graph tooling (MCP launcher + viewer + render)
    ├── graphify-mcp-launcher.sh   # stdio MCP server launcher (referenced by mcp.json)
    ├── graphify-view.sh           # serve the interactive graph on a localhost URL
    └── render-graph.py           # headless PNG fallback (matplotlib)
```

## Native Perplexity connectors (no local install needed)

Connect these directly in Perplexity — no MCP config required. When you next chat with me in Perplexity, say "connect X" and I'll trigger the auth flow.

| Service | Perplexity connector | Purpose |
|---|---|---|
| GitHub | `github_mcp_direct` | PRs, issues, code search |
| Linear | `linear_native` | Issue tracking |
| Notion | `notion_mcp` | Docs |
| Slack | `slack_direct` | Team comms |
| Atlassian | `atlassian` | Jira / Confluence / Bitbucket |
| Sentry | `sentry` | Error tracking |
| Datadog | `datadog` | Observability |
| Stripe | `stripe` (+ `stripe_sandbox`) | Payments |
| PostgreSQL | `postgresql__pipedream` | Database |
| Alpaca | `alpaca__pipedream` | Broker (stocks, ETFs, options, crypto) |
| AWS | `aws__pipedream` | Cloud infra |
| Cloudflare | `cloudflare_api_key__pipedream` | CDN/edge |
| Render | `render` | App hosting |
| Neon | `neon` | Serverless Postgres |

## MCP servers for Claude Code / Cursor (this folder)

For services without a Perplexity connector, or that you want available in Claude Code / Cursor / Codex directly.

### Files

- **`mcp.json`** — merge into `~/.claude.json` (`mcpServers` key) or drop into `~/.cursor/mcp.json`. Secrets are read from the shell env (populated from `~/dev-team/shared/credentials/.env`), never stored here.
- **`bin/install-on-dgx.sh`** — one-time cache pre-warm so first invocation is fast.

### Setup

```bash
bash ~/dev-team/shared/mcp/bin/install-on-dgx.sh
```

Then merge `mcp.json` into your Claude Code / Cursor config. See `~/dev-team/shared/credentials/CREDENTIALS.md` for exactly which keys to get and where (they live in `.env`, not `mcp.json`).

### What's included

| Server | Why local, not Perplexity |
|---|---|
| GitHub | Official MCP server (repos, PRs, issues, code search) |
| Polygon.io | Market data — no native connector |
| Alpaca (backup) | Optional — use Perplexity connector for me, MCP for Claude Code |
| Redis | No native connector |
| Docker | Local daemon ops |
| Playwright | Browser automation you drive locally |
| Graphify | Query a local code knowledge graph (no native connector) |

## Graphify — code knowledge graph

Graphify turns a folder of code into a queryable knowledge graph (nodes = symbols/files, edges = calls/contains/imports, plus Leiden communities). The MCP server (`graphify-mcp`) exposes graph-query tools so you can answer "what calls `execute()`?", "what's the blast radius of this PR?", etc., without re-reading the whole repo.

- **Server command** (in `mcp.json` → `graphify`): `~/dev-team/shared/mcp/graphify/graphify-mcp-launcher.sh`
- **Binary**: `~/.local/bin/graphify-mcp` (installed via `uv tool install 'graphifyy[mcp]'`). The `[mcp]` extra pulls `mcp` + `starlette` + `uvicorn` — **the plain `graphifyy` install is missing it, so the server won't start**. Re-install with the extra if you ever reinstall.
- **Per-project graph**: the server serves one `graph.json` at a time, located at `<project>/graphify-out/graph.json`. The launcher resolves it from (in priority order):
  1. `GRAPHIFY_GRAPH_JSON` — explicit path to a `graph.json`
  2. `GRAPHIFY_PROJECT_DIR`/`$GRAPHIFY_OUT`/`graph.json` (defaults to `graphify-out`)
  3. `./graphify-out/graph.json` (cwd-relative)
- **Build a graph first** (one-time, per project, no LLM/keys needed for code extraction):
  ```bash
  cd <project> && graphify update <project>
  ```
  This writes `<project>/graphify-out/graph.json`. Re-run `graphify update` after big changes, or run `graphify watch <project>` to rebuild on edit.

The `graphify` entry in `mcp.json` currently points at `projects/financial-terminal`. To serve a different project, edit the `GRAPHIFY_PROJECT_DIR` (or `GRAPHIFY_GRAPH_JSON`) in that entry's `env` block. No API key is required.

**Tools exposed:** `query_graph`, `get_node`, `get_neighbors`, `get_community`, `god_nodes`, `graph_stats`, `shortest_path`, `list_prs`, `get_pr_impact`, `triage_prs`.

> **HTTP transport (optional, for shared deployments):** `graphify-mcp --transport http --host 127.0.0.1 --port 8080` (protect with `GRAPHIFY_API_KEY`). The stdio launcher above is the default for per-developer harnesses.

### Viewing the knowledge graph interactively in a browser

`graphify update <project>` writes three artifacts into `<project>/graphify-out/`:
- **`graph.html`** — force-directed graph (vis-network; node/link data embedded, JS lib from a CDN)
- **`GRAPH_REPORT.md`** — plain-language summary (communities, god nodes, question placeholders)
- **`graph.json`** — the raw GraphRAG-ready graph

The **interactive viewer** serves it on a localhost URL, **fully self-contained** (vis-network vendored locally — no CDN / external network needed):
```bash
shared/mcp/graphify/graphify-view.sh <project_dir>            # -> http://localhost:8000/
PORT=9000 shared/mcp/graphify/graphify-view.sh <project_dir>  # custom port
```
- Serves `http://localhost:<port>/` — the interactive graph (pan / zoom / click / expand). It vendors `vis-network` once to `~/.local/share/graphify-view/` (single-time fetch from unpkg, then reused) and inlines it into a generated `index.html`.
- Same port also serves `graph.html` (original, needs CDN), `GRAPH_REPORT.md`, and `graph.json`.
- Runs in the foreground (`Ctrl-C` to stop) and **prints the URL only** (it does not open a browser). If you're on a remote box, open the URL on that host or tunnel the port (`ssh -L 8000:localhost:8000 <host>`).

**Headless image fallback** (only if interactive serving isn't possible): `shared/mcp/graphify/render-graph.py <project_dir>` renders a PNG via matplotlib.
