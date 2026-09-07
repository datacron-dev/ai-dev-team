---
name: git-workflow
description: Git branching, commit hygiene, PR structure, semantic versioning, and rebase/merge workflows. Use this skill whenever the user asks about git strategy, branch naming, commit messages, how to structure a PR, resolving merge conflicts, rebasing, cherry-picking, tagging releases, semantic versioning, or has a git question about the "right way" to do something. Also use when writing or reviewing commit messages, or when planning a series of commits to structure a large change.
---

# Git Workflow

## Branching model — trunk-based, small PRs

Default to **trunk-based development**:
- `main` is always deployable.
- Feature branches are short-lived (hours to a couple days, not weeks).
- Merge to `main` via PR with review + CI green.
- Deploy from `main` continuously (or on release tags).

Skip GitFlow's `develop`/`release`/`hotfix` unless you have a specific reason (multi-version support, mobile app-store release trains). For a solo dev on a trading terminal, trunk-based is the right default.

## Branch naming

`<type>/<short-description>[-<issue>]`

- `feat/add-alpaca-broker-adapter-42`
- `fix/backtest-lookahead-bug`
- `refactor/extract-signal-engine`
- `chore/upgrade-pandas-2`
- `docs/adr-postgres-decision`

Lowercase, hyphens. Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`.

## Commit messages — Conventional Commits, with room to breathe

```
<type>(<scope>): <subject>

<body — the WHY, not the WHAT. Wrap at 72 chars.>

<footer — refs, breaking changes>
```

**Types:** `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `build`, `ci`.

**Subject rules:**
- Imperative mood: "add X" not "added X" or "adds X"
- No trailing period
- ≤ 72 characters
- If you can't summarize in 72 chars, the commit is probably too big

**Body rules (optional but usually worth writing):**
- Explain **why** the change was made, not what the diff shows
- Reference the issue / ADR / doc that motivated it
- Note anything non-obvious: side effects, migration steps, rollback plan

**Footer:**
```
Refs: #42
Closes: #43
BREAKING CHANGE: renamed StrategyConfig.risk_pct → risk_bps (multiply old values by 100)
```

## Good vs bad examples

**Bad:**
```
updates
```
```
fix stuff
```
```
WIP
```

**Good:**
```
fix(backtest): shift signal by 1 bar to eliminate look-ahead

The signal was being computed and executed on the same bar's close,
which produced impossible fills at prices only known post-hoc. Now
signal[t] executes at open[t+1]. This reduces the SMA(20,50) crossover
backtest Sharpe from 2.4 (fake) to 0.6 (real).

Refs: #47
```

## Commit sizing

Rule of thumb: **one logical change per commit.** A reviewer should be able to describe each commit in one clause.

- Refactoring + behavior change in one commit → split them.
- Formatting + logic in one commit → split them.
- Multiple bug fixes in one commit → split them.

The exception is small, mechanical changes bundled with a rename/refactor — those belong together.

## Rebase vs merge

**Rebase** (my default for feature branches):
- Keeps history linear and readable
- Rewrites commits — never rebase a branch other people are working on
- Use `git rebase -i main` to squash/reorder/reword before opening a PR
- `git config pull.rebase true` — never accidentally create merge commits from `git pull`

**Merge** (only for integration):
- Preserves history exactly as it happened
- Use for merging PRs into `main` (--squash or --no-ff, depending on your team's convention)
- For a solo dev: `--squash` produces a clean `main`; feature branch history is lost. `--no-ff` preserves the branch structure. Either is fine — pick one and stick with it.

## PR structure

**Title:** same rules as a commit subject. `feat(broker): add Alpaca paper-trading adapter`

**Description template:**
```markdown
## What
1-2 sentences on what this changes.

## Why
Link to issue/ADR/discussion. If none exists, explain the motivation.

## How
Notable implementation choices, especially anything a reviewer might question.

## Testing
- How I tested this
- Screenshots / logs if UI or output changed

## Risk
- What breaks if this is wrong
- Rollback plan
```

**PR size:** aim for < 400 lines of diff. Larger PRs get worse reviews and hide bugs. If a change is inherently large:
- Split into a stacked series of PRs
- Or land it behind a feature flag in small increments

## Semantic versioning

`MAJOR.MINOR.PATCH`:
- **MAJOR** — incompatible API change (rename, removal, contract change)
- **MINOR** — backward-compatible new feature
- **PATCH** — backward-compatible bug fix

Pre-1.0 (`0.x.y`):
- Anything goes; bump MINOR for features, PATCH for fixes, but don't treat 0.x as stable.
- Bump to 1.0 when the public API is stable and you're willing to commit to compatibility.

Tag every release: `git tag -a v0.4.2 -m "Release 0.4.2"` then `git push --tags`.

Generate changelogs from Conventional Commits with `git-cliff` or `standard-version` — free with the discipline of good commit messages.

## Rescuing yourself from bad situations

**"I committed to the wrong branch"**
```
git log --oneline -1                    # note the SHA
git reset --hard HEAD~1                  # remove commit from current branch
git checkout right-branch
git cherry-pick <SHA>
```

**"I need to unmerge / undo a merge to main"**
```
git revert -m 1 <merge-commit-SHA>       # creates a revert commit, safe
# NOT git reset --hard on main — that rewrites public history
```

**"I want to squash the last N commits"**
```
git rebase -i HEAD~N
# mark all but the first as 'squash' or 'fixup'
```

**"I need to fix the last commit without a new commit"**
```
git commit --amend --no-edit             # add staged changes to last commit
git commit --amend                       # also edit message
# only if the commit hasn't been pushed
```

**"I want to see what I'm about to push"**
```
git log --oneline origin/main..HEAD
git diff origin/main..HEAD
```

## Hygiene — automate these

- `.gitignore` covers `.venv/`, `__pycache__/`, `.env`, `*.pyc`, `.DS_Store`, editor swap files, and any file with secrets.
- Pre-commit hooks (`pre-commit` framework) to run `ruff`, `mypy`, and simple secret-scanning before every commit. One `pre-commit install` per repo.
- Commit lint (commitlint) enforced in CI if you want conventional commits guaranteed.

## Rules I don't break

- Never `git push --force` to a shared branch. Use `--force-with-lease` on your own feature branch only.
- Never commit secrets. If you do, rotate the secret — filtering history doesn't help if the value already leaked.
- Never rebase `main`.
- Never mix unrelated changes in a PR.
