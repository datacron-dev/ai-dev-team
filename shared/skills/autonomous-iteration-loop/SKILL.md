---
name: autonomous-iteration-loop
description: Complete a bounded task end-to-end (implement a feature, fix a bug, get tests passing) with a disciplined plan-implement-validate-diagnose cycle and hard stop conditions. Use this skill when the user asks to "just finish it", "get this working", "make the tests pass", or "implement X without checking in at each step." Also use when you're in the middle of a task and need a repeatable loop to converge on a working solution without looping indefinitely.
---

# Autonomous Iteration Loop

A bounded task is one with **verifiable acceptance criteria**. If you can't state the criteria, you can't know when to stop — clarify them first.

## The cycle

```
PLAN → IMPLEMENT → VALIDATE → (pass? DONE : DIAGNOSE → REVISE → IMPLEMENT ...)
```

Each pass through the loop is one iteration. Track the iteration count.

### PLAN
- Restate the acceptance criteria in one line.
- Identify the minimal set of files to touch.
- Choose the validation command(s) that prove success.

### IMPLEMENT
- Make the smallest change that addresses the current hypothesis.
- One logical change per iteration. If you're about to make two unrelated changes, split them.

### VALIDATE
- Run the **real** validation: the actual test suite, the actual build, the actual command the user cares about.
- **Show the output.** No "I think it works" — paste the relevant lines.
- A validation that isn't run is not a validation.

### DIAGNOSE (only on failure)
- Read the failure output carefully — the root cause is usually in the last 20 lines.
- Form one hypothesis.
- Check: is this the *same* failure as last iteration, or a new one?
  - Same → your fix didn't address the root cause. Re-diagnose from scratch.
  - New → you introduced a regression. Back off the last change and re-approach.

### REVISE
- Adjust the plan based on the diagnosis.
- If the plan is wrong (not just the code), re-plan before implementing.

## Stop conditions — non-negotiable

**STOP and report when:**
1. **Acceptance criteria verifiably met** (all tests pass, build succeeds, the command produces the expected output — and you showed the evidence).
2. **3 iterations of the same failure** without progress. The approach is likely wrong; escalate to the user with the evidence.
3. **A new, unrelated failure appears** that expands scope. Report the new failure, don't silently absorb it.
4. **You need a decision the user should make** (architecture choice, tradeoff, ambiguity).
5. **The task is bigger than the session.** Deliver what's done, document what's left.

**Never:**
- Loop indefinitely. There is always a stop condition.
- Claim success without showing the validation output.
- "Fix" a failure by weakening the test.
- Introduce a new, unrelated change to make a failing test pass.

## Reporting format

At the end (success or stop), report:

```
RESULT: <DONE | BLOCKED | PARTIAL>
Iterations: <N>
Evidence:
  <paste the validation output — the last 20-30 lines that prove the state>
What changed:
  <file: what changed, one line each>
What's left (if PARTIAL/BLOCKED):
  <exact next step, or the blocking evidence>
```

## Examples

**Success case (bug fix):**
```
RESULT: DONE
Iterations: 2
Evidence:
  $ pytest tests/test_auth.py -v
  test_refresh_token_rotation PASSED
  test_expired_token_rejected PASSED
  2 passed in 0.42s
What changed:
  auth/tokens.py: rotate refresh token on use (was reusing same token)
What's left: none
```

**Blocked case (repeated failure):**
```
RESULT: BLOCKED
Iterations: 3
Evidence:
  $ cargo test
  test_payment_flow ... FAILED
  panic: assertion failed: balance == expected
  (same panic all 3 iterations)
What changed:
  payments/ledger.rs: added rounding (didn't fix)
What's left:
  Hypothesis: the test fixture is using a stale balance.
  Need: can you confirm the fixture is regenerated before each test?
```

## Relationship to other skills

- **Before starting:** use `engineering-discovery-and-planning` to detect the real stack and validation commands.
- **During the loop:** use `systematic-debugging` for the DIAGNOSE phase when a failure is non-obvious.
- **For TDD work:** the loop is the outer wrapper; each iteration is one red-green-refactor cycle (see `tdd-testing`).
- **At the end:** use `engineering-memory` to record any new verified facts.
