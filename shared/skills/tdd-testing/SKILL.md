---
name: tdd-testing
description: Test-driven development and test design — the red-green-refactor cycle, the testing pyramid, coverage targets, and writing meaningful (non-brittle) tests. Use this skill whenever the user wants to write tests, establish a TDD workflow, generate a test suite, set coverage thresholds, write E2E tests (Playwright/Cypress), or asks how to test code without writing brittle, mock-heavy, implementation-detail tests. Also use when reviewing whether a test suite actually tests behavior or just mocks, or when a test is flaky.
---

# TDD & Testing

## The Iron Law of TDD

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
```

Wrote the code before the test? Delete it and start over with TDD. No exceptions without the human's explicit permission. The value of TDD is that you *watch the test fail for the right reason* before writing the code that makes it pass.

## Red-Green-Refactor

**RED — write a failing test.** One behavior, a clear name, tests real code (not mocks).

```python
def test_retries_failed_operations_three_times():
    attempts = 0
    def op():
        nonlocal attempts
        attempts += 1
        if attempts < 3:
            raise RuntimeError("fail")
        return "success"
    assert retry_operation(op) == "success"
    assert attempts == 3
```

**Verify RED — mandatory, never skip.** Run it and confirm it fails for the *expected* reason (feature missing, not a typo or import error).

**GREEN — minimal code to pass.** The simplest code that satisfies the test. No over-engineering, no speculative generality.

**Verify GREEN.** Run it; it passes.

**REFACTOR — clean up while staying green.** Remove duplication, improve names, extract helpers. Do NOT add behavior. Re-run the tests.

### Verification checklist (before calling work complete)

- [ ] Every new function/method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for the expected reason
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass
- [ ] No console errors or warnings
- [ ] Tests use real code (mocks only when unavoidable)
- [ ] Edge cases and error paths covered

### Common rationalizations (all wrong)

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. The test takes 30 seconds. |
| "I'll write tests after" | Tests that pass immediately prove nothing. |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
| "TDD slows me down" | TDD is faster than debugging production. |

## The testing pyramid

```
        /\
       /E2E\          ~10% — few, slow, high confidence
      /------\
     / Integ. \       ~20% — service boundaries, DB queries
    /----------\
   /    Unit    \     ~70% — fast, isolated, many
  /--------------\
```

Weight your effort toward the bottom. E2E tests are expensive and flaky; use them only for the critical paths you can't unit-test.

**Coverage targets:** statements/branches/functions/lines ≥ 80%; critical business logic 100%. Enforce in CI, but treat coverage as a floor, not a goal — 100% coverage of wrong tests is still wrong.

## Writing tests that don't rot

**Prefer behavior queries over implementation details (React Testing Library, in order of preference):**
1. Accessible role: `screen.getByRole('button', { name: /submit/i })`
2. Label text: `screen.getByLabelText(/email address/i)`
3. Placeholder → 4. Text content → 5. Test ID (last resort)

**Async — wait for conditions, never sleep:**
```typescript
await screen.findByText(/loaded successfully/i);   // wait for appear
await waitForElementToBeRemoved(() => screen.queryByText(/loading/i));
await waitFor(() => expect(mockFn).toHaveBeenCalled());
```

**API mocking:** use a library-level mock (MSW / respx / responses) rather than mocking individual functions, so you test the real request/response contract.

### Anti-patterns to reject in review

| Anti-pattern | Problem | Fix |
|-------------|---------|-----|
| Testing mock behavior | Tests the mock, not the code | Use real implementations |
| Testing implementation details | Brittle, breaks on refactor | Test observable behavior |
| `test('it works')` | Vague | `test('returns 401 for expired token')` |
| Multiple assertions, no context | Hard to diagnose | `describe` blocks, one behavior per test |
| Hard-coded sleeps (`setTimeout`) | Flaky | `waitFor` / condition polling |
| Shared mutable test state | Ordering bugs | Reset state in `beforeEach` |
| Tests that assert on internal state | Couples to implementation | Assert on public API / rendered output |

## E2E testing (Playwright)

One test per user journey. Page Object Model for anything shared. Always include:
- A happy path
- The primary failure path (invalid input, empty state)

```typescript
test.describe('Login', () => {
  test('logs in with valid credentials', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('password123');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(page).toHaveURL('/dashboard');
  });
  test('shows error with invalid credentials', async ({ page }) => {
    // ... expect alert containing 'Invalid credentials'
  });
});
```

Use fixtures for authenticated state so every test doesn't re-login:
```typescript
export const test = base.extend({
  authenticatedPage: async ({ page }, use) => {
    // log in once, hand over the page
    await use(page);
  },
});
```

Keep E2E suites small and deterministic — a flaky E2E suite teaches the team to ignore CI.
