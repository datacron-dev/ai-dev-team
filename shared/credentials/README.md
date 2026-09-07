# Credentials

## Setup

```bash
cp .env.template .env
chmod 600 .env
# edit .env: replace each PUT_*_HERE placeholder with your real key
```

## Files here

- **`.env.template`** — checked-in template with `PUT_*_HERE` placeholders, no real secrets
- **`.env`** — YOUR real keys, gitignored, chmod 600, NEVER commit
- **`CREDENTIALS.md`** — checklist of which keys to get, from where, and where they're used

## How tools consume this

Point every tool at `~/ai-dev-team/shared/credentials/.env`:

**MCP config** — reference variables directly, e.g.
```json
"env": { "POLYGON_API_KEY": "${POLYGON_API_KEY}" }
```
and source the env before starting your harness.

**Shell profile** — add to `~/.bashrc` or `~/.zshrc`:
```bash
set -a
source ~/ai-dev-team/shared/credentials/.env
set +a
```

That auto-exports every variable when a shell opens. Restart your terminal or run `source ~/.bashrc`.

**Python scripts** — use `python-dotenv`:
```python
from dotenv import load_dotenv
load_dotenv("~/ai-dev-team/shared/credentials/.env")
```

## If a key leaks

1. Immediately rotate it on the provider's dashboard
2. Update `.env`
3. Restart any long-running processes (LM Studio, vLLM, MCP servers) so they pick up the new value
