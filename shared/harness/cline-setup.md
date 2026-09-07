# Cline Setup — VS Code + Local Qwen + Mothership

Cline is the recommended VS Code harness for local Qwen + MCP work. This guide gets you from zero to fully wired.

## 1. Install the Extension

In VS Code:
1. Open Extensions panel (`Ctrl+Shift+X`)
2. Search for **Cline** (publisher: `saoudrizwan`)
3. Click Install
4. Reload window if prompted

## 2. Configure the Model Provider

Open Cline (click its icon in the VS Code sidebar), then click the settings gear.

### Option A — vLLM (recommended for GPU inference)

- **API Provider:** OpenAI Compatible
- **Base URL:** `http://localhost:8000/v1`
- **API Key:** anything (vLLM ignores it, but Cline requires a non-empty value — use `local`)
- **Model ID:** whatever model name your vLLM server serves (e.g., `Qwen/Qwen2.5-32B-Instruct`)

### Option B — LM Studio

- **API Provider:** LM Studio
- **Base URL:** `http://localhost:1234/v1`
- **Model:** select from the dropdown (LM Studio must have the model loaded)

## 3. Point Cline at Your MCP Servers

Cline reads MCP config from its own settings file at:
```
~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json
```

You have two clean options:

### Option A — Symlink to ai-dev-team (recommended)

```bash
mkdir -p ~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/
ln -sf ~/ai-dev-team/shared/mcp/mcp.json \
       ~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json
```

Now edits to `~/ai-dev-team/shared/mcp/mcp.json` are immediately visible to Cline. No copy step ever.

### Option B — Copy (if symlinks feel messy)

```bash
mkdir -p ~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/
cp ~/ai-dev-team/shared/mcp/mcp.json \
   ~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json
```

You'd re-copy any time you edit the source.

## 4. Verify VS Code Sees the Env Vars

Cline spawns MCP servers as child processes. Those children inherit env vars from the VS Code process. So VS Code needs to have been launched from a shell where `.env` was loaded.

**Rule of thumb: launch VS Code from a terminal.**

```bash
# From a fresh terminal (which sourced .bashrc, which loaded .env):
code ~/ai-dev-team/projects/financial-terminal
```

**Do NOT launch VS Code from the desktop icon** — it may inherit a login shell environment that hasn't sourced `.bashrc` and won't have your keys.

If you must use the desktop icon, add this to `~/.profile` (which is sourced by graphical logins):
```bash
# .profile — for graphical VS Code launches
if [[ -f "$HOME/ai-dev-team/shared/credentials/.env" ]]; then
    set -a
    source "$HOME/ai-dev-team/shared/credentials/.env"
    set +a
fi
```

Then log out and back in.

## 5. Tell Cline About Your Skills

Cline supports "Custom Instructions" — a global system prompt injected into every conversation. Point it at your ai-dev-team skills.

In Cline settings, set **Custom Instructions** to:

```
You have access to project skills at ~/ai-dev-team/shared/skills/. Before starting any nontrivial task, check that directory and read any SKILL.md files whose descriptions match the current task. Available skills include: adr-system-design, app-release, backtesting, code-review, git-workflow, python-engineering, risk-portfolio-math. Load skills liberally — reading a skill costs almost nothing and produces much better output.

The current project's docs live at ~/ai-dev-team/projects/<current-project>/README.md and its /docs directory. Read those before making architectural changes.

Prefer local tools and MCP servers. Do not suggest cloud APIs unless local options are exhausted.
```

## 6. Verify Everything Works

Open Cline in VS Code, in a new task, type:

```
List the MCP servers you have available and tell me one thing you can do with each.
```

You should see: github, polygon, alpaca_backup, docker, redis (etc.) with one-line descriptions. If you see errors about missing env vars, check step 4.

## 7. First Real Test

```
Read ~/ai-dev-team/projects/financial-terminal/README.md and give me a 3-sentence summary. Then look at the current git status of that repo.
```

This exercises: file reading, project understanding, and the local `git` MCP (or your local git shell — Cline can shell out).

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| MCP server "failed to start" | env var missing at spawn | Launch VS Code from a terminal after `source ~/.bashrc` |
| GitHub MCP hangs on first call | Docker image being pulled | Wait; subsequent calls are fast |
| "Model not found" in Cline | vLLM server not running, or model ID wrong | Check `curl $VLLM_ENDPOINT/models` |
| Cline uses cloud model instead of local | API Provider wrong | Re-check settings; must be "OpenAI Compatible" pointing at localhost |
| Slow first response | vLLM warming up | Normal; subsequent responses are fast |

## What's NOT Recommended

- **Do not** enable Cline's auto-approve for anything writing to disk or executing commands — even with local Qwen, review each tool call the first few weeks so you build intuition for what it wants to do
- **Do not** paste real API keys into Cline's Custom Instructions — those are stored in VS Code settings, not `.env`
