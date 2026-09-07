# ai-dev-team — Local AI Dev Team Layout for DGX

A drop-in folder layout for running an **AI-assisted dev team on a DGX** using a **local model** (Qwen via vLLM, or LM Studio) with **Perplexity Portable Computer** as an optional fallback. Clone it, point your coding harness at the shared skills + MCP servers, and start working.

The whole idea: **one shared toolkit, many projects.** Everything reusable lives once under `shared/`; your projects live under `projects/` and pull from `shared/` as needed — no per-project duplication.

> **Local-first.** The default is to run everything on your own GPU for free. Cloud/Perplexity is fallback only — see [`shared/routing-guide.md`](shared/routing-guide.md) for when to escalate.

---

## What's in this repo

```
ai-dev-team/
├── README.md              ← you are here
├── shared/                ← team-wide toolkit (the reusable part)
│   ├── skills/            ← 15 reusable engineering skills
│   ├── mcp/               ← MCP server config + install helper
│   ├── credentials/       ← .env template + key checklist (secrets never checked in)
│   ├── harness/           ← Cline setup guide + MCP smoke-test prompt
│   ├── bin/               ← ms-status pre-flight checker
│   └── templates/         ← boilerplate for new projects and new skills
├── scripts/               ← the two launch/bridge scripts
│   ├── mothership-launch.sh
│   └── cline_vllm_proxy.py
└── projects/              ← your projects go here (empty in this repo)
```

### `shared/skills/` — the reusable skills

Each skill is a folder with a `SKILL.md` the model reads before doing a matching task. These are the team's "how we do things" library:

| Skill | What it does |
|---|---|
| `adr-system-design` | Record architecture decisions (ADRs, C4, sequence diagrams, capacity planning) |
| `api-backend` | Design/build REST & GraphQL APIs, auth, DB indexing, validation |
| `app-release` | Package & distribute Python desktop apps (AppImage, PyInstaller, Docker) |
| `autonomous-iteration-loop` | Drive a bounded task to done with a plan-implement-validate loop |
| `backtesting` | Build & evaluate trading-strategy backtests (vectorbt, Backtrader, pandas) |
| `changelog-release-notes` | Turn git history into changelogs & release notes |
| `code-review` | Review diffs/PRs for correctness, security, performance |
| `devops-cicd` | CI/CD, Docker, Kubernetes, Terraform, deploy strategies |
| `engineering-discovery-and-planning` | Inspect the repo and plan before writing code |
| `engineering-memory` | Keep a per-project memory ledger across sessions |
| `frontend-react` | React & Next.js components, App Router, Tailwind, a11y |
| `git-workflow` | Branching, commit hygiene, PRs, semver, rebase/merge |
| `offline-local-guardrails` | Enforce offline/local-first operation on this machine |
| `python-engineering` | Modern Python: uv, ruff, mypy, pytest, packaging, types |
| `risk-portfolio-math` | Sharpe/VaR/Kelly/position sizing, portfolio optimization |
| `safe-refactoring-and-simplification` | Refactor/simplify while preserving behavior |
| `security-engineering` | OWASP, threat modeling, secrets, compliance |
| `systematic-debugging` | Root-cause debugging in four phases |
| `tdd-testing` | Test-driven development, meaningful non-brittle tests |

### `shared/mcp/` — MCP servers

- **`mcp.json`** — drop-in config for Cline / Claude Code / Cursor. Reads secrets from the shell env (populated from `credentials/.env`), so you never store keys in the file.
- **`install-on-dgx.sh`** — warms package caches (installs `uv` if missing) so first MCP call is fast.
- Ships: `github` (Docker), `polygon`, `alpaca_backup`, `redis`, `docker`, `playwright`. See `shared/mcp/README.md` for the full key wiring.

### `shared/credentials/` — secrets, kept out of git

- **`.env.template`** — checked in, with `PUT_*_HERE` placeholders.
- **`.env`** — *your* real keys. **Never committed** (gitignored), chmod 600.
- **`CREDENTIALS.md`** — which key to get, from where, and where it's used.

### `shared/harness/` — getting a harness wired

- **`cline-setup.md`** — step-by-step Cline (VS Code) + local Qwen + this MCP config.
- **`mcp-smoke-test.md`** — a prompt you paste into Cline to verify every MCP server responds.

### `shared/bin/ms-status` — pre-flight check

Runs a quick health check before a work session: `.env` present & 600, keys set, vLLM up, bridge active, Docker & `uvx` available, skills present. Exit 0 = go, 1 = fix something.

### `shared/templates/` — start new things fast

- **`new-project/`** — scaffold a new project under `projects/`.
- **`new-skill/`** — scaffold a new reusable skill under `shared/skills/`.

---

## Getting started (DGX)

1. **Clone**
   ```bash
   git clone <this-repo> ~/ai-dev-team
   ```
2. **Set up credentials**
   ```bash
   cd ~/ai-dev-team
   cp shared/credentials/.env.template shared/credentials/.env
   chmod 600 shared/credentials/.env
   $EDITOR shared/credentials/.env   # replace each PUT_*_HERE with a real key
   ```
   Add the shell-integration block to `~/.bashrc` (see `shared/credentials/CREDENTIALS.md`), then `source ~/.bashrc`.
3. **Point your local model** — run vLLM (or LM Studio) and make sure `VLLM_ENDPOINT` / `LOCAL_MODEL` in `.env` match.
4. **Wire your harness** — follow `shared/harness/cline-setup.md` (Cline recommended). Symlink `shared/mcp/mcp.json` into Cline's settings and set its Custom Instructions to point at `shared/skills/`.
5. **Warm MCP caches (optional but recommended)**
   ```bash
   bash ~/ai-dev-team/shared/mcp/install-on-dgx.sh
   ```
6. **Smoke-test** — run `shared/bin/ms-status`, then paste the prompt from `shared/harness/mcp-smoke-test.md` into Cline.
7. **Add a project**
   ```bash
   cp -r shared/templates/new-project projects/<your-project>
   cd projects/<your-project>
   ```

---

## The two scripts — and whether you need them

Both scripts live in `scripts/`. Most users only need the first step below and can skip the rest.

### 1. `cline_vllm_proxy.py` — the bridge (only if you use Portable Computer's *dynamic* vLLM port)

Perplexity Portable Computer can run vLLM in a Docker container that maps to a **random host port each restart**. This stdlib-only proxy listens on a **fixed** port (`127.0.0.1:8012` by default), forwards each request to the current vLLM container port, and re-discovers it when it changes — so Cline can point at one stable URL forever. It preserves SSE streaming.

```bash
# see the current vLLM port / model / suggested Cline config:
python3 scripts/cline_vllm_proxy.py show

# run it in the foreground:
python3 scripts/cline_vllm_proxy.py

# or in the background:
nohup python3 scripts/cline_vllm_proxy.py > logs/cline-vllm-bridge.log 2>&1 &
```

**When you can skip it:** if your vLLM already serves on a fixed port (e.g. `http://localhost:8000/v1`), just point Cline at that directly — no bridge needed. The bridge is purely for the dynamic-port case.

### 2. `mothership-launch.sh` — service manager

A small service supervisor that can start/stop/status the bridge (and any service you add to its `SERVICES` array). It auto-detects the ai-dev-team root as the parent of `scripts/`, so it works wherever the repo is cloned.

```bash
scripts/mothership-launch.sh status    # one-line status of all services
scripts/mothership-launch.sh start vllm-bridge
scripts/mothership-launch.sh stop vllm-bridge
scripts/mothership-launch.sh           # interactive menu
```

It can manage services two ways:
- **systemd user unit** — the default for the bridge (`cline-vllm-bridge.service`), so it survives reboots; or
- **pidfile** — for anything you add to `SERVICES`.

> **Do you need to deploy these at all?** No, not for most setups. If you run vLLM on a stable port, you can skip both scripts entirely and point Cline straight at vLLM. Use the bridge only when your vLLM port changes (Portable Computer dynamic container), and use the launch script only if you want a supervised/restartable service.

---

## Core principles

- **Default to `shared/`.** Anything that could help more than one project belongs in `shared/skills/`. A project folder is only for code that's tied to that project's schema/setup.
- **No duplication.** Skills are read from `shared/skills/` by every project — one authoritative location. Your harness points there directly.
- **Local-first.** The local model handles the vast majority of dev work at zero external cost. Escalate to Perplexity only when a skill says so (`shared/routing-guide.md`).
- **Secrets in one place.** All API keys live in `shared/credentials/.env` (gitignored). Every tool reads from there.

---

## Repo hygiene

`shared/credentials/.env` and all `projects/` contents are gitignored. Only the toolkit ships. This repo intentionally contains **no real secrets** and **no project code** — it's the layout, not your work.
