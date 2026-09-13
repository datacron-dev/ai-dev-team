---
name: graphify
description: Answer questions about a codebase's architecture, call relationships, and blast radius using the graphify knowledge graph (MCP tools or CLI). Use whenever the user asks "how does X work", "what calls/uses/imports Y", "trace the flow through Z", "what would break if I change W", "which PRs touch this area", or "where is the logic for V" — especially when a project has a graphify-out/ directory (a built graph.json). Prefer this over re-reading many files or doing broad greps. Do NOT use for a one-off "does symbol X exist" check or when no graph exists and a rebuild is impractical — just grep/read directly instead.
---

# Graphify — query a code knowledge graph

Graphify turns a project into a queryable knowledge graph: nodes are symbols/files, edges are relationships (calls, contains, imports, method, field…), plus Leiden communities. A persistent `graph.json` lives at `<project>/graphify-out/graph.json`. This skill is about **using** that graph to answer codebase questions fast — not about the extraction pipeline.

## When to use (and when not)

**Use** when a question is structural/relational and a project already has (or can cheaply build) a graph:
- "How does X work / where's the logic for X?"
- "What calls / uses / imports / defines Y?"
- "Trace the data flow through Z"
- "What's the blast radius of changing W?" / "which communities does this PR touch?"
- "What are the core abstractions of this codebase?"

**Don't use** for:
- One-off existence checks ("does `foo()` exist?") — just grep.
- Single-file Q&A where you already have the file open.
- Situations where no graph exists **and** a rebuild would be heavy/undesirable for the question's value. (If a graph exists, use it even if slightly stale — see "Keep it fresh".)

## Fast path — graph already built? Use it first

Before anything else, check for `<project>/graphify-out/graph.json` (or `GRAPHIFY_PROJECT_DIR` / `GRAPHIFY_GRAPH_JSON`). If it exists and the question is a natural-language codebase question, **answer it from the graph — do not re-read files or grep first.**

### Preferred: the `graphify` MCP tools (if loaded in the harness)

| Tool | Use it for |
|---|---|
| `query_graph` | Broad "how does X work" — BFS/DFS keyword search over the graph |
| `get_node` | Full detail for one symbol (by label or id) |
| `get_neighbors` | Direct relationships of a node (optionally filtered by relation type, e.g. `call`) |
| `god_nodes` | Most-connected nodes = core abstractions |
| `graph_stats` | Node/edge/community counts + confidence breakdown — sanity check |
| `get_community` | All nodes in a community (by id) |
| `shortest_path` | Path between two concepts (`undirected=true` to ignore direction) |
| `list_prs` / `get_pr_impact` / `triage_prs` | PR review: which open PRs touch this area, blast radius, review order |

**Key gotcha:** the server is started against **one graph.json** (see `shared/mcp/mcp.json` → `graphify.env`). If the question is about a *different* project than the one the server was started with, pass that project's absolute dir as the `project_path` argument to the tool.

### Fallback: the `graphify` CLI (if the MCP server isn't loaded)

```bash
graphify query "<natural-language question>"   # graph search
graphify explain "<symbol>"                    # plain-language explanation + neighbors
graphify path "<A>" "<B>"                      # shortest path between two nodes
```
Pass `--graph <path>` if the graph isn't at the default `./graphify-out/graph.json`.

## No graph yet? Build one (one-time, cheap for code)

```bash
cd <project> && ~/.local/bin/graphify update <project>
```
- Writes `<project>/graphify-out/graph.json` (+ `graph.html`, `GRAPH_REPORT.md`).
- **No LLM / API keys needed for code** — it's pure AST extraction. (Semantic extraction of docs/papers is optional and needs a key.)
- Verify it built: `graphify-out/graph.json` exists and `graph_stats` / `graphify query "anything"` returns node counts.

## Keep it fresh

- **After refactors/deletions:** re-run `graphify update <project>` (add `--force` if the rebuild has fewer nodes than before).
- **Continuous:** `graphify watch <project>` rebuilds on file changes (needs the `watch` extra: `uv tool install 'graphifyy[mcp,watch]'`).
- Stale-but-present is usually still better than nothing; just note the date if it matters.

## Viewing the graph — offer the interactive URL, but only when it's wanted

The user wants an **interactive** graph (pan/zoom/click), not a rendered image. The interactive viewer is:

```bash
shared/mcp/graphify/graphify-view.sh <project_dir>     # -> http://localhost:8000/  (PORT=<p> to change)
```
It serves a **self-contained, interactive** vis-network page at `/` (graphify's `graph.html`, but with `vis-network` vendored/inlined locally — **no CDN, no external network**). It vendors the lib once to `~/.local/share/graphify-view/` (one-time fetch, then reused). Same port also serves `GRAPH_REPORT.md` and `graph.json`. **It does NOT open a browser — it only prints the URL.** Start it in the background (or leave it running) and give the user the URL.

### When to offer the URL — and when NOT to

Offer the URL **only** in these two moments; do not surface it on every graph-related turn:

1. **You asked to view the graph.** The user says something like "show me the graph", "open the knowledge graph", "view the graph". → Start `graphify-view.sh` (if not already running) and hand over the exact URL: `http://localhost:<port>/`.
2. **The graph was just built or updated** by you (a `graphify update` you ran for them). → As the last line of that reply, offer it: e.g. "The graph is up — view it interactively at `http://localhost:<port>/` (run `shared/mcp/graphify/graphify-view.sh <project>` if the server isn't running)."

In all other cases (answering a normal codebase question from the graph), **do not** mention or offer the URL — just answer the question. Silence beats noise.

### If the user is on a remote/other machine

`localhost` only works on the machine running the server. If the user isn't on that box, tell them to open the URL on that host, or to tunnel the port (e.g. `ssh -L 8000:localhost:8000 <host>` then open `http://localhost:8000/`). Never try to open a browser on the remote box.

### Fallback: render to a PNG (only if interactive serving is truly impossible)

```bash
shared/mcp/graphify/render-graph.py <project_dir> [out.png]
```
Reads `graph.json`, draws a force-directed layout (matplotlib) colored by community / sized by degree. Needs a python with `networkx` + `matplotlib` (auto-detects; the financial-terminal venv has both — override with `GRAPHIFY_PY=<python>`). Set `MPLCONFIGDIR` to a writable dir if `~/.config` is read-only.

### Plain-language summary

`GRAPH_REPORT.md` in `graphify-out/` (communities, god nodes, question placeholders) — a useful companion to the interactive graph for large codebases.

## Be honest about confidence

Every edge has a confidence label: `EXTRACTED` (directly from the code), `INFERRED` (inferred by graphify), or `AMBIGUOUS`.
- Cite `EXTRACTED` relationships as fact.
- Flag `INFERRED`/`AMBIGUOUS` ones as "graphify inferred" so the user knows to verify.
- Never present a low-confidence path as certain.

## Output style

- Lead with the direct answer (the path / call chain / blast radius), then the supporting graph evidence.
- Name symbols and files (`src=... loc=L...`) so the user can jump there.
- If the graph answer is thin, say so and offer to verify in the source.
