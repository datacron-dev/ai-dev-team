---
name: code-review
description: Review code diffs, pull requests, or code snippets for correctness, style, security, performance, and maintainability. Use this skill whenever the user asks to review code, review a PR, check a diff, look over changes, critique implementation, sanity-check a function, audit for bugs, or asks "does this look right?" Also use when the user pastes a code block and wants feedback, or when providing a code review as part of a broader task like a feature spec.
---

# Code Review

## Review philosophy

A good code review answers three questions in order:

1. **Does it work?** (correctness, edge cases, error handling)
2. **Will it keep working?** (tests, types, maintainability, blast radius)
3. **Would I write it this way?** (idioms, style) — least important

Reviews that lead with style are annoying and miss real bugs. Lead with correctness.

## Review structure — always this order

```
## Summary
1-line: what does this change do?

## Blocking issues (must fix)
- Correctness bugs
- Security vulnerabilities
- Data loss or corruption risks
- Missing error handling on external calls

## Non-blocking suggestions (nice-to-have)
- Style, naming, refactoring opportunities
- Test coverage gaps that aren't critical
- Documentation

## Questions
- Ambiguities I want the author to clarify before merge

## What I liked
- Genuine praise for good decisions (specific, not generic)
```

**Never leave a review with only negatives.** Even a bad PR usually contains one good decision — call it out. Reviews are collaborative, not adversarial.

## Blocking checklist

For every diff, verify:

**Correctness:**
- Do the changed functions handle their edge cases? (empty input, None, negative, boundary)
- Are there off-by-one errors in loops/indices/date ranges?
- Are floating-point comparisons using `math.isclose` or a tolerance, not `==`?
- Is timezone-aware datetime used consistently? (naive vs aware mixing is a top-10 bug source)
- For financial code specifically: are quantities, prices, and currency amounts using `Decimal` (or explicitly-tracked integer cents) instead of `float`?

**Concurrency / async:**
- Any shared mutable state without a lock?
- Any `asyncio` code that calls a blocking function?
- Any race between check-then-act (e.g. `if not exists: create`)?

**Error handling:**
- Are external calls (HTTP, DB, subprocess) wrapped with retry/timeout?
- Are exceptions caught at the right level, or swallowed?
- Does the error path leave the system in a consistent state?

**Security:**
- Any user input flowing into SQL / shell / HTML / eval without escaping?
- Any secrets in code or logs?
- Any deserialization of untrusted data (`pickle`, `yaml.load`)?
- Any file paths built from user input without a whitelist / `Path.resolve()` check?

**Tests:**
- Is there at least one test for the happy path?
- Is there at least one test for the failure path?
- Do the tests actually assert something meaningful, or just call the function?
- Are the tests deterministic? (no wall-clock, no random without seed, no network)

**Data integrity (financial-specific):**
- Any look-ahead bias in signal computation?
- Any use of point-in-time-incorrect data?
- Are trading costs modeled?
- Is there a benchmark comparison?

## Non-blocking checklist

**Naming:**
- Does the name describe what the function returns, not how it works? (`compute_daily_returns` vs `run_calc`)
- Are boolean names positive and question-shaped? (`is_open`, `has_position`)
- Are units in the name when ambiguous? (`price_usd`, `duration_ms`, `weight_bps`)

**Function shape:**
- More than 3 positional args → convert to keyword-only or a dataclass config.
- More than ~40 lines → probably doing more than one thing.
- Nested for-loops → probably worth extracting or vectorizing.

**Idiomatic Python:**
- Dict-mutation-in-loop where a comprehension would do
- Manual index tracking where `enumerate` would do
- `open()` without `with`
- `list()` of `.keys()` / `.values()` when iteration would do

**Docstrings:**
- Public functions: what it does, args, returns, raises.
- No need to document self-evident internals.

## Diff-reading pattern

1. Read the PR description first. If there isn't one, that's the first comment.
2. Read the tests before the implementation — tests document intent.
3. Read the diff in the order the author committed (git log --reverse), not the alphabetized file list. The story matters.
4. For each file, ask: what's the smallest possible change that gets this outcome? Anything beyond that is a candidate for a follow-up PR.
5. Flag scope creep — "this change also refactors X" is worth a `nit` even if the refactor is good, because it makes the PR harder to review and revert.

## Severity levels — use them

- **blocking** — must fix before merge
- **important** — should fix in this PR, but not a hard block
- **nit** — trivial (style, wording); author's discretion
- **question** — I need more info, not a change request
- **praise** — genuinely good, don't skip these

Prefix every comment. This makes it clear to the author what to do.

## Common financial-code bugs to watch for

- Off-by-one on returns: `pct_change()` vs `pct_change().shift(-1)` — very easy to mix up
- Using close-to-close return when open-to-close is what the strategy trades on
- Forward-filling missing prices without gap flag → invisible zero returns
- Percentages vs bps vs fractions inconsistency
- Rolling window that uses `min_periods=1` — early values are noise
- Merging on ticker without handling ticker changes (renames, mergers)
- Timezone: US market closes at 16:00 America/New_York, not 21:00 UTC in summer / 20:00 UTC in winter — always store tz-aware
- Weekend / holiday handling for date arithmetic on trading days (use `pandas_market_calendars`)

## When the answer is "reject and rewrite"

Sometimes the cleanest review is: this approach is wrong; here's a sketch of what would work; happy to pair on it. Do not spend an hour red-lining a design that shouldn't ship. Say so early and offer a synchronous conversation.
