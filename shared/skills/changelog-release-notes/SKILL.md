---
name: changelog-release-notes
description: Generate changelogs and release notes from git commits, and write project documentation (README, API docs). Use this skill whenever the user asks to create release notes, generate a changelog, summarize commits since the last release, write a weekly product update, draft a README, or document a public API. Also use when preparing a version announcement or translating technical commit messages into user-facing language.
---

# Changelogs & Release Notes

## Changelog from git commits

**Workflow:**
1. Check dependency files for exact versions (`package.json`, `requirements.txt`, `Cargo.toml`).
2. Look up library changelogs for any major upgrades mentioned.
3. Translate technical commits into user-facing language.
4. Filter out internal commits (refactoring, CI, test-only changes).
5. Group by category: Features, Improvements, Fixes, Security.

**Commit category mapping (Conventional Commits):**

| Prefix | Changelog section |
|--------|-------------------|
| `feat:`, `feature:` | New Features |
| `perf:`, `improve:` | Improvements |
| `fix:`, `bugfix:` | Bug Fixes |
| `security:`, `vuln:` | Security |
| `break:`, `BREAKING:` | Breaking Changes |
| `refactor:`, `test:`, `ci:`, `chore:` | (filtered out) |

**Output format:**
```markdown
# Updates — Week of March 3, 2026

## New Features

- **Team Workspaces**: Create separate workspaces for different projects.
  Invite team members and keep everything organized.

- **Keyboard Shortcuts**: Press `?` to see all available shortcuts.

## Improvements

- **Faster Sync**: Files now sync 2× faster across devices.
- **Better Search**: Search now includes file contents, not just titles.

## Bug Fixes

- Fixed issue where large images would not upload.
- Resolved timezone confusion in scheduled posts.

## Security

- Updated dependency to resolve CVE-2026-1234 (high severity).
```

**Tooling:** `git-cliff`, `standard-version`, or `semantic-release` automate this if your commit messages follow Conventional Commits (see the `git-workflow` skill for that discipline).

**Rules:**
- Lead with the most user-visible change.
- One bullet per feature — no walls of text.
- Include a "What to do" section for breaking changes.
- Never blame the author in a public changelog; describe the change, not the person.

## README generation

**Essential sections, in this order:**
```markdown
# Project Name

One-line description of what this does.

## Quick Start
npm install
cp .env.example .env
npm run dev

## Features
- Feature 1 with brief description
- Feature 2 with brief description

## Architecture
Brief description + link to architecture docs / ADRs.

## Development
Prerequisites, setup instructions, commands.

## Testing
How to run tests, coverage requirements.

## Deployment
How to deploy to production.

## Contributing
Branch conventions, PR process, code standards.

## License
MIT / Apache 2.0 / etc.
```

**Rules:**
- Quick Start must work copy-paste. Test it on a clean machine.
- One-line description at the top — this is what people see first.
- Link, don't duplicate: point to ADRs / design docs instead of inlining them.
- Keep it under 2 screens. Push detail into `docs/`.

## API documentation

**JSDoc + OpenAPI for Express (auto-generates spec):**
```typescript
/**
 * @openapi
 * /users/{id}:
 *   get:
 *     summary: Get user by ID
 *     tags: [Users]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string }
 *         description: The user's unique identifier
 *     responses:
 *       200:
 *         description: User found
 *         content:
 *           application/json:
 *             schema: { $ref: '#/components/schemas/User' }
 *       404:
 *         description: User not found
 *       401:
 *         description: Authentication required
 */
app.get('/users/:id', authenticate, async (req, res) => { /* ... */ });
```

**Documentation best practices:**
- [ ] Every public function/method has a docstring
- [ ] All parameters documented with types and constraints
- [ ] Return values and error cases described
- [ ] Code examples for complex functions
- [ ] `CHANGELOG.md` updated with every release
- [ ] `CONTRIBUTING.md` describes the development workflow
- [ ] ADRs in `docs/adr/` (see the `adr-system-design` skill)
- [ ] Runbooks for operations tasks in `docs/runbooks/`

**Where things live:**
```
docs/
├── adr/              # architecture decision records
├── runbooks/         # operational playbooks
├── api/              # OpenAPI specs + examples
└── architecture.md   # system overview + C4 diagrams
```
