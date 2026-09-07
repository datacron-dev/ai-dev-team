---
name: engineering-discovery-and-planning
description: Inspect the actual repository and produce a short plan before starting any coding task, feature, or bug fix. Use this skill whenever the user asks to implement a feature, fix a bug, add a test, or make a change — before writing any code. Also use when picking up an unfamiliar codebase, when the stack or build tool is unclear, or when the user says "figure out what needs to change." Never assume the stack, build commands, or test runner — detect them from the repo.
---

# Engineering Discovery & Planning

Before editing code, understand the repo. Assumptions are the source of most wasted work.

## Step 1 — Detect the real stack

Read the manifests and config files that actually exist. Don't guess.

| File | Tells you |
|------|-----------|
| `package.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb` | Node stack, scripts, deps |
| `pyproject.toml`, `requirements.txt`, `uv.lock`, `Pipfile` | Python stack, deps, tooling |
| `Cargo.toml`, `Cargo.lock` | Rust stack, features |
| `go.mod`, `go.sum` | Go stack, module deps |
| `Makefile`, `justfile`, `Taskfile.yml` | Build/automation entry points |
| `tsconfig.json` | TypeScript config, strictness |
| `Dockerfile`, `docker-compose.yml` | Containerized services |
| `.github/workflows/*.yml` | CI steps (mirror them locally) |
| `README.md`, `CONTRIBUTING.md` | Author-intended workflow |
| `.env.example` | Required env vars |

## Step 2 — Find the real build/test/lint/run commands

Don't assume. Look in this order:
1. `package.json` → `scripts` block (`dev`, `build`, `test`, `lint`, `typecheck`).
2. `pyproject.toml` → `[tool.pytest]`, `[tool.ruff]`, or a `Makefile`.
3. `Makefile` / `justfile` → named targets.
4. `.github/workflows/` → the commands CI actually runs.
5. `README.md` → "Quick start" section.

Run the **test command once** before making changes to confirm the baseline is green (or to record what's already failing).

## Step 3 — Confirm scope with the user

Before editing, restate:
- **What** you're going to change (files, functions).
- **Why** (the acceptance criteria or the bug you're fixing).
- **How** you'll validate (which test, which command, what output).

If any of these is ambiguous, ask. A 30-second clarification now beats an hour of rework.

## Step 4 — Output a brief plan

Format:

```
PLAN
-----
Goal: <one sentence>
Files to touch:
  - <path> — <what changes>
  - <path> — <what changes>
Approach: <2-4 sentences on the strategy>
Validation:
  - Run: <command>
  - Expected: <observable output / test result>
Risks / open questions:
  - <anything you're not sure about>
```

Keep it to ~15 lines. If the plan is longer than that, the task is probably too big — split it.

## Anti-patterns to avoid

- **Assuming the test runner.** A Python repo might use `pytest`, `tox`, or `make test`. Check.
- **Assuming the dev server port.** Read the config, don't guess `:3000`.
- **Skipping the baseline test run.** You won't know if you broke something or it was already broken.
- **Planning in code.** The plan is prose + a file list, not pseudocode.
- **Skipping the "why."** A plan without the acceptance criteria can't be validated.

## When to skip this skill

- Trivial one-line change with a clear, obvious location (e.g. fixing a typo in a string).
- The user has already given you the exact plan and just wants execution.
- You're in the middle of an established workflow where the stack is already known from earlier in the session.
