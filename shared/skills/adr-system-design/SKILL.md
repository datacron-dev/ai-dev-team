---
name: adr-system-design
description: Document architectural decisions and design systems using ADRs (Architecture Decision Records), C4 diagrams, sequence diagrams, and capacity planning. Use this skill whenever the user is making a non-trivial technology or design decision, wants to record why a choice was made, is picking between technologies, wants to plan capacity or scaling for a system, or asks to sketch a system design. Also use when reviewing a system for maintainability, or when asked to help think through tradeoffs on an architecture question.
---

# ADRs and System Design

## When to write an ADR

An Architecture Decision Record is a short document explaining a decision, its context, and its consequences. Write one when a decision:

- Is hard to reverse (data model, cloud provider, language, framework)
- Affects multiple parts of the system
- Involves a real tradeoff between viable options
- Would surprise a future engineer if unexplained

Do NOT write an ADR for:
- Reversible defaults (linter choice, formatter)
- Obvious wins (adding pytest to a Python project)
- Things covered by existing conventions

Every ADR you write earns its place by being useful in 2 years when someone asks "why is it like this?"

## ADR template — use this exact structure

```markdown
# ADR-NNNN: <Short title, imperative form>

**Status:** Proposed | Accepted | Deprecated | Superseded by ADR-XXXX
**Date:** YYYY-MM-DD
**Deciders:** Kevin, ...

## Context
What forces are at play? What problem are we solving? Include enough
background that a future reader (or a new hire) understands why this
was on the table at all. 1–3 paragraphs.

## Decision
We will <verb> <object>.
Be specific. Name the technology, pattern, or approach chosen.

## Alternatives considered
- **Option A:** <name> — <why we didn't pick it>
- **Option B:** <name> — <why we didn't pick it>
- **Option C (chosen):** <name> — <why we picked it>

## Consequences
### Positive
- Concrete benefits enabled by this decision.
### Negative
- Real costs / tradeoffs — be honest.
### Neutral
- Things that will change but aren't inherently better or worse.

## Follow-ups
- <Tasks that need to happen because of this decision>
```

## ADR numbering and storage

- Store in `docs/adr/` (or `docs/decisions/`) at project root.
- Filename: `NNNN-short-slug.md` — e.g. `0007-use-postgres-for-strategy-metadata.md`.
- Number sequentially, never renumber. Deprecated ADRs stay in the file tree.
- Update superseding ADR to reference the one it replaces, and vice versa.

## The C4 model — pick the right level

Level 1 — **System context.** One diagram showing your system as a box and every external system/user it touches. Draw first, share widely.

Level 2 — **Containers.** Zoom into your system. Each "container" is an independently deployable unit (a web app, a background worker, a database). Show how they communicate.

Level 3 — **Components.** Zoom into one container. Show its major internal components. Only draw this for containers people will actively work on.

Level 4 — **Code.** Class diagrams. Rarely worth drawing by hand; let the IDE / doc generator handle it.

For most projects, Level 1 + Level 2 is enough. If you catch yourself drawing Level 4, ask whether that time would be better spent writing the code.

## Sequence diagrams — when to use them

Use for anything with 3+ actors and ordering that matters:
- Auth flows
- Distributed transactions
- Async job pipelines
- Retry / failure scenarios

Prefer Mermaid over PlantUML or Lucid — Mermaid renders in GitHub, GitLab, Notion, and most docs viewers with zero setup.

```
sequenceDiagram
    participant U as User
    participant W as Web
    participant Q as Queue
    participant B as Broker

    U->>W: submit order
    W->>Q: enqueue order (correlation_id=X)
    W-->>U: 202 Accepted
    Q->>B: place order (X)
    B-->>Q: fill / reject
    Q->>W: update order status
    U->>W: poll status → filled
```

## Capacity planning — the back-of-envelope

Before picking infrastructure, do this math:

1. **Peak QPS.** What's the highest sustained requests-per-second you expect? (Not average — peak.)
2. **Latency budget.** How fast does each request need to be? (p50, p95, p99 targets.)
3. **Data volume.** How many bytes/rows/records per day? Per year? Growth curve?
4. **Cost ceiling.** What's the monthly budget? Halve it — you'll overrun.

For financial data specifically:
- Market data ingestion: how many symbols × how many bars/day = rows/day. 500 symbols × 1-min bars for US session = ~200k rows/day.
- Backtest storage: keep raw ticks in cold storage (S3/Parquet), aggregated bars in Postgres/Timescale.
- Live-order latency: colocate with broker if HFT-adjacent; otherwise anywhere with < 50ms to broker API is fine.

## Design review checklist

When reviewing a proposed design:

- **What breaks first?** Identify the bottleneck. Is it CPU, memory, network, DB IOPS, or a specific external API rate limit?
- **What happens on failure?** Is there a retry? Is it idempotent? Does partial failure leave inconsistent state?
- **How do you observe it?** Structured logs, metrics, traces — are they wired in from day 1?
- **How do you turn it off?** Feature flag, kill switch, rollback path. If there's no way to disable it without a code push, that's a smell.
- **What's the migration path?** Existing data / users / integrations — how do they move to the new thing?
- **Blast radius.** If this component is buggy, what else stops working? Minimize blast radius through isolation (separate service, separate DB, circuit breakers).

## Design docs vs ADRs — different things

- **Design doc:** forward-looking, proposing an approach, often several pages, includes alternatives and open questions. Written *before* building.
- **ADR:** backward-looking, recording the decision made, short (1–2 pages), immutable once accepted. Written *when the decision is finalized*.

A design doc often produces one or more ADRs as its output.

## Common tradeoffs and my defaults

| Choice | Default | Justification |
|---|---|---|
| Monolith vs microservices | Monolith until pain | Microservices are a scaling optimization, not a starting point |
| Sync vs async DB | Async | Free concurrency for I/O-bound web apps |
| REST vs gRPC | REST for external, gRPC for internal | Ecosystem breadth vs perf/typing |
| Postgres vs specialized DB | Postgres | It's shockingly good at everything until you're at real scale |
| Redis vs in-process cache | In-process until multi-instance | Fewer moving parts |
| Kafka vs Postgres LISTEN/NOTIFY | Postgres pub/sub until >1k msg/sec | Same reason |
| ORM vs raw SQL | Query builder (SQLAlchemy Core, sqlc) | ORMs hide the query; raw SQL hides the schema |
