# MCP Smoke Test — Run in Cline

Paste this exact prompt into a fresh Cline task. It exercises every MCP server
with a read-only call so you catch silent failures before they matter mid-work.

---

## Prompt

```
I want to smoke-test all my MCP servers. For EACH server in my mcp.json,
make ONE small read-only call and report a table with columns:

| Server | Tool Called | Status | Response Time | Notes |

Requirements:
- Read-only calls ONLY — no writes, no order placement, no state changes
- Test in this order: github, polygon, alpaca_backup, docker, redis, playwright
- If a server fails, capture the actual error message
- If a server needs a resource I don't have (e.g. no local Redis), mark it
  "N/A — no backing service" rather than reporting failure
- Do NOT retry a failed server more than once

Suggested calls per server:
- github: list my repos, limit 3
- polygon: get ticker details for AAPL
- alpaca_backup: get account info (paper endpoint)
- docker: list running containers
- redis: PING command
- playwright: list available browsers (or launch about:blank and close it)

After the table, give me a bullet summary of:
1. Servers that are healthy and ready to use
2. Servers that failed and need debugging
3. Servers I should consider removing from mcp.json because I don't
   have the backing service

Do NOT make any writes, order placements, or state changes anywhere.
```

---

## What to Look For

**Expected results:**

| Server | Should succeed? | If it fails, likely cause |
|---|---|---|
| github | ✓ Yes | PAT missing/invalid, Docker daemon down |
| polygon | ✓ Yes | POLYGON_API_KEY missing/invalid |
| alpaca_backup | ✓ Yes | ALPACA_* keys missing/invalid, wrong endpoint |
| docker | ✓ Yes | Docker daemon not running |
| redis | ⚠ Depends | Redis server not running (`redis-cli ping` on host to verify) |
| playwright | ✓ Yes (first run slow) | Browsers not installed — first run will download ~300MB |

**Red flags:**
- github fails with "authentication" → PAT scope wrong, regenerate with fine-grained perms from cline-setup guide
- alpaca_backup shows a live account balance (not paper) → `PAPER=True` not being read; check env inheritance
- Any server hangs >30s → likely env var missing; server is waiting for input

## After the Test

Report back to me:
1. The full table Cline produced
2. Whether any server surprised you (unexpected success/failure)
3. Which servers you want to remove from mcp.json (if any turned out N/A)

Then I'll tighten up mcp.json and move to Tier 2 based on what you're
about to build.
