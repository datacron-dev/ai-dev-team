# Credentials Checklist — ai-dev-team

Single source of truth for all API keys is `~/ai-dev-team/shared/credentials/.env`. Every tool reads from there via shell env vars.

## Quick Start

```bash
# One-time setup
cp ~/ai-dev-team/shared/credentials/.env.template ~/ai-dev-team/shared/credentials/.env
chmod 600 ~/ai-dev-team/shared/credentials/.env
$EDITOR ~/ai-dev-team/shared/credentials/.env
#   -> replace each PUT_*_HERE placeholder with your real key.
#   -> leave anything you don't use as the placeholder or blank.

# After editing, load the env:
set -a; source ~/ai-dev-team/shared/credentials/.env; set +a

# Verify (these two have defaults — should print immediately):
echo "VLLM=$VLLM_ENDPOINT"      # http://localhost:8000/v1
echo "MODEL=$LOCAL_MODEL"        # Qwen/Qwen2.5-32B-Instruct
```

**If a value still reads as `PUT_*_HERE` or prints blank:** the variable is loaded but you haven't pasted the real key yet. Not a bug — edit `.env`.

## Part 1 — What Goes in `.env` (the DGX-side keys)

Each row is one line in `~/ai-dev-team/shared/credentials/.env`. Fill only what you'll actually use — leave the rest as placeholders or blank.

| Variable | Get it from | Used by | Priority |
|---|---|---|---|
| `GITHUB_PERSONAL_ACCESS_TOKEN` | Fine-grained PAT: GitHub → settings → developer settings → personal access tokens. Scopes: read repos, PRs, issues, actions. | GitHub MCP server | High |
| `POLYGON_API_KEY` | https://polygon.io/dashboard/api-keys (free tier OK to start) | Polygon MCP server | High — market data |
| `ALPACA_API_KEY` | https://app.alpaca.markets/paper/dashboard/overview → "View API Keys" | Alpaca MCP server | High — broker |
| `ALPACA_SECRET_KEY` | Same page as above | Alpaca MCP server | High — broker |
| `PAPER` | Set to `True` (already default) | Alpaca MCP server | High — safety |
| `REDIS_URL` | Default `redis://localhost:6379` works if Redis runs locally | Redis MCP server | Optional |
| `PAGERDUTY_API_KEY` | https://app.pagerduty.com/ (only if you use PagerDuty) | PagerDuty MCP (if added) | Optional |
| `VLLM_ENDPOINT` | Your vLLM server (default `http://localhost:8000/v1`) | Local harness | Set by default |
| `LMSTUDIO_ENDPOINT` | Your LM Studio server (default `http://localhost:1234/v1`) | Local harness | Set by default |
| `LOCAL_MODEL` | Whichever Qwen model you serve (e.g., `Qwen/Qwen2.5-32B-Instruct`) | Local harness | Set by default |
| `ANTHROPIC_API_KEY` | https://console.anthropic.com/ (only if you want cloud Claude fallback) | Local harness override | Optional |
| `OPENAI_API_KEY` | https://platform.openai.com/ (only if you want cloud GPT fallback) | Local harness override | Optional |

**How each tool reads them:**

- Your shell auto-loads them from `.env` via a block in `~/.bashrc` (add it once — see below) — no manual `source .env` needed
- MCP servers pick them up from the shell env when your harness spawns them
- Python scripts can use `python-dotenv` to load explicitly

**Never referenced by `.env`:** Docker MCP (uses local daemon), Playwright MCP (standalone, downloads browsers on first run).

### Auto-load `.env` in every shell (one-time)

Add this to `~/.bashrc` (or `~/.zshrc`):

```bash
# === ai-dev-team shell integration ===
if [[ -f "$HOME/ai-dev-team/shared/credentials/.env" ]]; then
    set -a
    source "$HOME/ai-dev-team/shared/credentials/.env"
    set +a
fi
```

Then `source ~/.bashrc`.

## Part 2 — Perplexity Native Connectors (browser OAuth, no keys)

For each of these, open a Perplexity session and say **"connect X"**. I'll trigger the OAuth flow and you approve in your browser. Zero keys to manage in `.env`, zero paste steps.

**Priority (do first — biggest quality-of-life boost):**
- [ ] **GitHub** — for PRs, issues, code search
- [ ] **Alpaca** — trading + market data (paper account). Live in Perplexity alongside your local Alpaca MCP.
- [ ] **Linear** or **Atlassian** (Jira) — pick one for ticket tracking
- [ ] **Sentry** — error tracking
- [ ] **PostgreSQL** — connect to your project DB

**Standard:**
- [ ] **Notion** — if you use it for docs
- [ ] **Slack** — if you have a workspace
- [ ] **Datadog** — if you have observability set up
- [ ] **Stripe / Stripe Sandbox** — if building anything paid

**Cloud infra (as needed):**
- [ ] **AWS** — if deploying to AWS
- [ ] **Cloudflare** — if using their CDN / Workers
- [ ] **Render** or **Neon** — if using either

## Part 3 — Wiring `.env` Into Your Local Harness MCP Config

`~/ai-dev-team/shared/mcp/mcp.json` reads secrets from the shell env, not from the file. After you fill `.env`, add an `env` block to each keyed server so the value comes from env — this is what keeps `.env` the *only* place you ever edit for key rotation.

Example (Polygon):

```json
"polygon": {
  "command": "uvx",
  "args": ["--from", "git+https://github.com/polygon-io/mcp_polygon", "mcp_polygon"],
  "env": {
    "POLYGON_API_KEY": "${POLYGON_API_KEY}"
  }
}
```

Same pattern for `github`, `alpaca_backup`, `redis`. Never paste real keys into `mcp.json`.

## Part 4 — Verify Each Piece

**Shell integration loaded:**
```bash
echo "VLLM=$VLLM_ENDPOINT"       # should be http://localhost:8000/v1
echo "MODEL=$LOCAL_MODEL"         # should be Qwen/Qwen2.5-32B-Instruct
```
If these are blank or read as `PUT_*_HERE`, `~/.bashrc` didn't load `.env` or you haven't filled it. Fix:
```bash
grep -c "ai-dev-team shell integration" ~/.bashrc   # should be 1
source ~/.bashrc                                     # re-source
```

**A specific key is set (without exposing the value):**
```bash
[ -n "$POLYGON_API_KEY" ] && echo "POLYGON: set" || echo "POLYGON: EMPTY"
[ -n "$ALPACA_API_KEY"  ] && echo "ALPACA:  set" || echo "ALPACA:  EMPTY"
```

**Polygon MCP responds:**
```bash
uvx --from git+https://github.com/polygon-io/mcp_polygon mcp_polygon --help
```

**Alpaca MCP responds (paper):**
```bash
uvx --from git+https://github.com/alpacahq/alpaca-mcp-server alpaca-mcp-server --help
```

## File Locations Reference

| What | Where |
|---|---|
| Secrets (real values) | `~/ai-dev-team/shared/credentials/.env` — chmod 600, gitignored |
| Template (checked in) | `~/ai-dev-team/shared/credentials/.env.template` |
| This checklist | `~/ai-dev-team/shared/credentials/CREDENTIALS.md` |
| MCP server config | `~/ai-dev-team/shared/mcp/mcp.json` |
| Shell integration | Block in `~/.bashrc` starting with `# === ai-dev-team shell integration ===` |
