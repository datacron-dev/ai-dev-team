---
name: engineering-memory
description: Maintain a persistent per-project memory ledger (PROJECT_MEMORY.md) so verified context isn't lost between sessions. Use this skill at the start of every working session on a project (read the ledger if it exists) and at the end of every session (update it with newly verified facts). Also use when the user says "where were we?", "remember this", or when you need to recall a decision, command, or recurring issue from a previous session.
---

# Engineering Memory

A single file per project — `PROJECT_MEMORY.md` at the repo root — that records **verified** facts so the next session (or the next engineer) doesn't have to re-derive them.

## When to read

- **Start of every session:** if `PROJECT_MEMORY.md` exists, read it first. It's your orientation.
- **When the user asks** "where were we?" or "what did we decide about X?"
- **Before making a non-trivial decision** that may have been made before.

## When to write

- **End of every session:** append any new verified facts.
- **Immediately when a fact is confirmed** (a command that works, a decision that's made, a bug that's reproduced).
- **When the user explicitly says** "remember this" or "note this down."

## What to record

Only **verified** facts. No speculation, no "I think", no "probably."

### Stack & commands (verify by running)
- Language, framework, major versions
- Build command: `make build` / `npm run build` / `cargo build`
- Test command: `pytest` / `npm test` / `cargo test`
- Lint command: `ruff check` / `npm run lint` / `clippy`
- Run command: `npm run dev` / `uv run main.py`
- How to start local services: `docker compose up` / `make up`

### Architecture decisions (link to ADRs where they exist)
- Data store choice + why
- Service boundaries
- Key API contracts
- Major refactors in progress

### Known recurring issues
- Flaky tests and their cause (if known)
- Environment quirks (timezone, locale, missing deps)
- Workarounds that are in place

### User preferences
- Code style preferences
- Review process
- Deployment cadence
- Things the user explicitly does NOT want

## What NOT to record

- ❌ Speculative claims ("I think the DB is Postgres" — verify first)
- ❌ Ephemeral state (current branch, uncommitted changes — those go in `git status`)
- ❌ Secrets, tokens, credentials
- ❌ Anything already in a tracked file (README, ADR, CONTRIBUTING) — link instead
- ❌ Long code snippets — reference the file/line instead

## File format

```markdown
# PROJECT_MEMORY.md — <project name>

Last updated: YYYY-MM-DD (by: <agent or human>)

## Stack
- <language> <version>, <framework> <version>
- <data store>
- <key third-party services, local or cloud>

## Commands
| Task | Command | Notes |
|------|---------|-------|
| Build | `make build` | |
| Test | `make test` | ~45s, 80% coverage |
| Lint | `make lint` | ruff + mypy |
| Run | `make dev` | port 8000 |
| Services | `docker compose up` | postgres, redis |

## Decisions
- <YYYY-MM-DD>: <decision> — <one-line why>. (ADR-NNNN if applicable)

## Recurring issues
- <issue> — <cause / workaround>. Last seen <date>.

## User preferences
- <preference>
```

Keep it under ~100 lines. If it grows past that, prune stale entries or split into `docs/memory/` with topic files.

## Rules

1. **Verified only.** Every entry must have been observed (command ran, decision made, fact confirmed).
2. **Date-stamped.** Every decision gets a date so you can tell what's stale.
3. **Link, don't duplicate.** If an ADR or design doc exists, link to it.
4. **Prune actively.** If a "recurring issue" hasn't recurred in 3 months, move it to an "archived" section or delete.
5. **Never commit secrets.** If a fact involves a credential, record *that* a credential exists and where, not the value.
6. **Commit the file** to the repo (it's a team asset) unless the user says otherwise.

## Session ritual

**Start:**
```
1. Read PROJECT_MEMORY.md if it exists.
2. Skim the "Commands" and "Recurring issues" sections.
3. Note anything that looks stale (dates > 3 months, broken commands).
```

**End:**
```
1. Did I confirm any new facts? Add them.
2. Did I make a decision? Record it with a date.
3. Did a recurring issue come up? Note it.
4. Did the user express a preference? Add it.
5. Prune anything that's now stale.
6. Commit the file (if the repo is git-tracked).
```
