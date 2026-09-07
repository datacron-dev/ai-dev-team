---
name: offline-local-guardrails
description: Enforces offline-only, local-first operation on this machine (DGX box, local-model-only development). Use this skill at the start of any engineering task on this machine, and consult it whenever a workflow would normally reach for web search, live documentation, cloud deployment, external APIs, or package installation. Also use when the user asks to look up library versions, API docs, CVEs, or "the latest" on a package, or when a workflow from another skill suggests a cloud/CI/K8s step that is not available offline.
---

# Offline-Local Guardrails

This machine is offline and runs local models only. The following constraints apply to **every** engineering task here.

## Hard constraints

- **No web search.** No live documentation lookups, no Stack Overflow, no "latest version" checks.
- **No cloud deployment.** No Vercel, no AWS/GCP/Azure, no Kubernetes in the cloud, no GitHub Actions running remotely.
- **No external API calls** that require the network (except where the user has explicitly approved a specific call).
- **No package installs without explicit user approval.** `pip install`, `npm install`, `uv add`, `cargo add`, `go get` all require the user's OK first, because they may hit the network.
- **No "I checked the latest docs" claims** unless a local source was actually consulted.

## Substitution table

When another skill suggests a cloud/remote workflow, use the local equivalent:

| Cloud/remote workflow | Local equivalent on this machine |
|-----------------------|----------------------------------|
| Kubernetes / EKS / GKE | Docker Compose (single-node, `docker compose up`) |
| GitHub Actions / CircleCI CI | Local shell script that runs the same lint/test/build steps |
| Managed Postgres (RDS, Supabase, Neon) | Local Postgres in a Docker container, or SQLite |
| Managed Redis / Cloud cache | Local Redis in a Docker container, or in-process cache |
| Managed object storage (S3, GCS) | Local filesystem or MinIO in Docker |
| Managed message queue (SQS, Pub/Sub) | Local Redis Streams, or SQLite-backed queue |
| Cloud secrets manager (AWS SM, Vault cloud) | `.env` file (gitignored) or `direnv` |
| Cloud log aggregation (Datadog, CloudWatch) | `docker compose logs` or `journalctl` |
| Remote monitoring / APM | Local Prometheus + Grafana in Docker, or skip |
| Web-based deployment (Vercel, Netlify) | `docker compose` + reverse proxy (Caddy/nginx) on the local LAN |
| Live doc / library lookup | Local sources only (see below) |

## Offline dependency & docs lookup

When you need to know about a library, package, or API:

1. **Installed metadata first.** Read the local install:
   - Python: `pip show <pkg>`, `python -c "import <pkg>; print(<pkg>.__file__)"`, then read the source / type stubs in site-packages.
   - Node: `npm ls <pkg>`, then read `node_modules/<pkg>/package.json` and the `.d.ts` files.
   - Rust: `cargo metadata`, then read the vendored source in `~/.cargo/registry/`.
   - Go: `go list -m all`, then read the module cache in `~/go/pkg/mod/`.
2. **Lockfiles and manifests.** `package.json`, `Cargo.lock`, `go.sum`, `uv.lock`, `poetry.lock` tell you the exact pinned versions.
3. **Vendored docs.** Many projects carry a `docs/` folder or `README` inside the package. Check it.
4. **If the answer isn't available locally, say so.** State plainly: "I can't verify the latest version / CVE status offline; please confirm." Never fabricate a version number, an API signature, or a CVE ID.

## What to never claim

- ❌ "I deployed to the cloud."
- ❌ "I ran the security scan in CI."
- ❌ "I checked the latest docs for X."
- ❌ "The CVE database shows Y."

Only claim what actually ran locally and whose output you observed. If a step is skipped because it's offline-incompatible, say so explicitly and propose the local alternative.

## What's still allowed

- Reading and writing local files.
- Running local build/test/lint commands.
- Docker / Docker Compose on the local daemon.
- Git (local repo operations; pushing to a remote requires network and user approval).
- Local databases (SQLite, local Postgres, local Redis).
- Local model inference (any LLM / embedding model that runs on this box).
