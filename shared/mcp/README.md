# MCP Server Configuration — ai-dev-team

This folder pre-stages the MCP servers that don't already exist as Perplexity native connectors. Native Perplexity connectors handle the majority — install these only for the gaps.

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

## MCP servers for Cline / Claude Code / Cursor (this folder)

For services without a Perplexity connector, or that you want available in your harness directly.

### Files

- **`mcp.json`** — drop-in config. For Cline, symlink it into Cline's settings folder (see `shared/harness/cline-setup.md`). For Claude Code, merge the `mcpServers` key into `~/.claude.json`.
- **`install-on-dgx.sh`** — pre-warms package caches so first invocation is fast.

### Setup on your DGX

```bash
# 1. Warm the caches (installs uv if missing, pre-fetches packages). Safe to re-run.
bash ~/ai-dev-team/shared/mcp/install-on-dgx.sh

# 2. Put your API keys in the env file, then load them.
cp ~/ai-dev-team/shared/credentials/.env.template ~/ai-dev-team/shared/credentials/.env
chmod 600 ~/ai-dev-team/shared/credentials/.env
$EDITOR ~/ai-dev-team/shared/credentials/.env
set -a; source ~/ai-dev-team/shared/credentials/.env; set +a
```

### Which servers need keys (and how to wire them)

`mcp.json` reads secrets from the **shell environment**, not from the file. After you fill `.env`, add an `env` block to each keyed server so it pulls the value from env (this is what keeps `.env` the single place you edit). Replace the placeholders in the comments below with your real keys in `.env` — never paste real keys into `mcp.json`:

```json
"polygon": {
  "command": "uvx",
  "args": ["--from", "git+https://github.com/polygon-io/mcp_polygon", "mcp_polygon"],
  "env": { "POLYGON_API_KEY": "${POLYGON_API_KEY}" }
}
```

| Server | Env var it needs | Source of the key |
|---|---|---|
| `github` | `GITHUB_PERSONAL_ACCESS_TOKEN` | fine-grained PAT (GitHub → settings → PATs) |
| `polygon` | `POLYGON_API_KEY` | https://polygon.io/dashboard/api-keys |
| `alpaca_backup` | `ALPACA_API_KEY`, `ALPACA_SECRET_KEY`, `PAPER` | https://app.alpaca.markets (paper dashboard) |
| `redis` | `REDIS_URL` | local default `redis://localhost:6379` works |
| `docker` | none | uses local Docker daemon |
| `playwright` | none | downloads browsers on first run |

See `../credentials/CREDENTIALS.md` for the full key-by-key checklist.

### What's included

| Server | Why local, not Perplexity |
|---|---|
| Redis | No native connector |
| Docker | Local daemon ops |
| Playwright | Browser automation you drive locally |
| Polygon.io | Market data — no native connector |
| Alpaca (backup) | Optional — use Perplexity connector in Perplexity, MCP in your local harness |
