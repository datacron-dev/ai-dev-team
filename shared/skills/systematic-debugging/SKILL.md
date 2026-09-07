---
name: systematic-debugging
description: Systematic, root-cause debugging — the four-phase process (root cause investigation, pattern analysis, hypothesis & testing, implementation), plus red flags for when to stop and rethink. Use this skill whenever the user is debugging a bug, a failing test, an error message, unexpected behavior, a flaky test, or a performance regression; asks "why is this broken?"; or keeps applying fixes that don't work. Also use when the user is about to apply a "quick fix" without understanding the root cause, or after 2+ failed fix attempts.
---

# Systematic Debugging

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.
```

If you haven't completed Phase 1, you cannot propose a fix. The most expensive bug is the one you "fix" by patching a symptom.

## The four phases

### Phase 1 — Root Cause Investigation

1. **Read the error message carefully.** It usually contains the exact solution — don't scroll past the last line.
2. **Reproduce consistently.** Exact steps, every time. A bug you can't reproduce you can't fix.
3. **Check recent changes.** `git log`, `git diff`, new dependencies, config/env changes. Most bugs are in the last change.
4. **Gather evidence at every boundary in a multi-component system:**
   ```bash
   # Layer 1: environment propagation
   echo "=== env ===" && env | grep MY_VAR || echo "NOT SET"
   # Layer 2: boundary logging
   console.log('[auth] input:', { userId, scope })
   console.log('[auth] token:', token ? 'SET' : 'UNSET')
   # Layer 3: actual data flow
   console.log('[db] result:', JSON.stringify(result, null, 2))
   ```
5. **Trace data flow backward.** Where does the bad value originate? Follow it to the source, not the symptom.

### Phase 2 — Pattern Analysis

- Find a working example of similar code in the codebase.
- Compare working vs. broken code and list every difference.
- Understand the dependencies: config, environment, assumptions the code makes.

### Phase 3 — Hypothesis & Testing

- State the hypothesis: *"I think X is the root cause because Y."*
- Make the **smallest** possible change to test it.
- **One variable at a time.** Never apply multiple fixes simultaneously — you won't know which one worked.
- If it didn't work, form a *new* hypothesis. Don't double down on the first one.

### Phase 4 — Implementation

- Write a failing test that reproduces the bug first (use the `tdd-testing` skill).
- Implement the single fix that addresses the root cause.
- Verify: tests pass, the original issue is gone, no regressions.
- If 3+ fixes have failed: **question the architecture**, not the symptoms.

## Red flags — STOP and return to Phase 1

- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add multiple changes, run the tests"
- "It's probably X, let me fix that"
- "One more fix attempt" (after already trying 2+)
- Each fix reveals a new problem in a different place

**If 3+ fixes have failed:** the architecture is likely wrong. Discuss with the team before attempting more fixes. Patching a fundamentally wrong design just moves the bug.

## Quick reference

| Phase | Key activities | Success criteria |
|-------|---------------|------------------|
| Root cause | Read errors, reproduce, gather evidence | Understand WHAT and WHY |
| Pattern | Find working examples, compare | Identify the differences |
| Hypothesis | Form a theory, test minimally | Confirmed, or a new hypothesis |
| Implementation | Write a failing test, fix, verify | Bug resolved, tests pass |

## Debugging specific categories

**Flaky test:** is it order-dependent? Time-dependent? Concurrency-dependent? Shared state? Run it 10 times to confirm flakiness, then bisect by isolating setup. Never "fix" a flaky test by adding a sleep or re-running it.

**Intermittent / race condition:** add logging around the shared resource, run under load, check for check-then-act patterns, and look for missing locks / atomicity.

**Performance regression:** measure before guessing. Profile (CPU, memory, DB query plans). Find the delta vs. a known-good baseline. "It's slow" without a measurement is not a hypothesis.

**"Works on my machine":** diff the environment. Env vars, dependency versions (`pip freeze` / `npm ls`), timezone, locale, OS-specific behavior, file permissions.

**Data-dependent bugs:** reproduce with the exact data, then shrink it to the minimal failing dataset. The minimal reproducer usually reveals the root cause.
