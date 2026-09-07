---
name: safe-refactoring-and-simplification
description: Refactor, clean up, or simplify existing code while preserving behavior — outside of the TDD red-green-refactor cycle. Use this skill when the user asks to clean up code, remove duplication, simplify a function, extract a helper, delete dead code, reduce abstraction, or make a diff more readable. Also use when reviewing a PR that is "just refactoring" and you need to verify behavior is preserved. Do NOT use this for adding new features or fixing bugs — that's TDD territory.
---

# Safe Refactoring & Simplification

Refactoring is a **behavior-preserving** transformation. If the observable behavior changes, it's not a refactor — it's a feature or a bug fix, and it needs tests first (see the `tdd-testing` skill).

## The golden rule

```
BEFORE: tests pass (or build succeeds)
AFTER:  tests pass (or build succeeds), same observable behavior
```

If you can't demonstrate the "before" state, you can't prove the "after" state is safe.

## Step 1 — Establish the baseline

Before touching anything:
1. Run the test suite. Record the result (pass/fail counts, time).
2. If there are no tests, **write a characterization test first** — a test that captures the *current* behavior, even if it's slightly wrong. This is your safety net.
3. Note the public API surface: function signatures, exported types, config keys, CLI flags, HTTP endpoints.

## Step 2 — Plan the refactor

- **One concern per commit.** Don't mix "rename X" with "extract Y" with "delete Z."
- **Smallest possible diff.** A 20-line refactor is easier to review than a 200-line one.
- **Name the transformation:**
  - Extract function / method
  - Inline temporary / function
  - Replace conditional with polymorphism
  - Remove duplication (pull up, template method)
  - Delete dead code
  - Rename for clarity
  - Simplify expression (De Morgan, remove negation, use stdlib)

## Step 3 — Execute in small steps

After **each** step:
- Run the tests / build.
- If anything breaks, **stop and diagnose** before proceeding.
- Keep the diff narrow enough that a reviewer can trace every line.

## Step 4 — Verify the public contract

After the refactor, confirm:
- All exported symbols still exist with the same signatures (or the change is intentional and documented).
- All CLI flags / config keys still work.
- All HTTP endpoints still respond with the same shape.
- All log / metric names that downstream systems depend on are unchanged (or migrated deliberately).

## What to remove

- **Dead code:** functions never called, variables never read, branches never taken.
- **Duplication:** copy-pasted blocks that should be a shared helper.
- **Unnecessary abstraction:** interfaces with one implementation, wrapper classes that add no value, "factory" methods that just `new` a single type.
- **Speculative generality:** parameters, config options, or features added "in case we need them later."
- **Comments that describe the code** (the code should be self-explanatory). Keep only "why" comments.

## What NOT to do

- ❌ **Introduce new behavior** "while you're in there." If you notice a bug, note it and file a separate issue / TDD task.
- ❌ **Refactor across module boundaries** in one go. Refactor within a module first, then expose a cleaner API, then refactor the callers.
- ❌ **Rename public symbols** without a migration path (deprecation alias, semver major bump).
- ❌ **Refactor code you don't understand.** Read it until you can explain what it does, then refactor.
- ❌ **Merge the refactor with a behavior change** in one commit. Reviewers can't tell which lines changed behavior.

## Review checklist (for a "refactor-only" PR)

- [ ] Test suite passes before and after, same count
- [ ] No new public API (or new API is explicitly justified)
- [ ] No deleted tests (unless the test was testing implementation details)
- [ ] Diff is reviewable line-by-line
- [ ] Each commit is a single, named transformation
- [ ] No new dependencies added
- [ ] No new TODOs / FIXMEs introduced
- [ ] Performance is not measurably worse (spot-check if the refactor touched a hot path)

## When to skip this skill

- **The code has no tests and the user wants a quick cleanup.** Write a characterization test first, or get explicit sign-off that behavior preservation isn't required.
- **The "refactor" is actually a rewrite.** If >50% of the lines change, it's a rewrite — use TDD instead.
- **The code is in a hot path with no tests.** Profile first; a "cleaner" version that's 2× slower is not an improvement.
