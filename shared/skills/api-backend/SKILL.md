---
name: api-backend
description: Design and implement HTTP APIs and backend services — REST/GraphQL design, OpenAPI-first workflows, standard response/error shapes, HTTP status codes, database indexing and query optimization (N+1, covering indexes, connection pooling), authentication/authorization patterns (JWT, OAuth2, bcrypt, rate limiting), and input validation. Use this skill whenever the user is designing or building an API, REST or GraphQL endpoint, web service, database schema, auth flow, or asks how to structure a backend, optimize a slow query, or secure an endpoint.
---

# API & Backend Engineering

## API design — OpenAPI-first

Design the API contract (OpenAPI) *before* writing handlers. It becomes your documentation, your tests, and your shared language across teams.

```yaml
openapi: 3.0.3
info:
  title: User Service API
  version: 1.0.0
paths:
  /users:
    get:
      summary: List users (cursor-based pagination)
      parameters:
        - name: cursor
          in: query
          schema: { type: string }
        - name: limit
          in: query
          schema: { type: integer, default: 20, maximum: 100 }
      responses:
        '200':
          content:
            application/json:
              schema: { $ref: '#/components/schemas/UserListResponse' }
    post:
      summary: Create user
      requestBody:
        required: true
        content:
          application/json:
            schema: { $ref: '#/components/schemas/CreateUserRequest' }
```

**Versioning:** `/v1/` path-based for most; header-based only when you need to serve multiple versions simultaneously.

### Standard response shape

```json
{ "data": { "id": "usr_123" }, "meta": { "requestId": "req_abc", "timestamp": "2026-03-03T09:00:00Z" } }
```

### Standard error shape

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid email format",
    "details": [{ "field": "email", "message": "must be a valid email address" }]
  },
  "meta": { "requestId": "req_abc" }
}
```

Always include a `requestId` so clients can report issues and you can trace the request.

### HTTP status codes

| Code | Use |
|------|-----|
| 200 | Success (GET, PUT, PATCH) |
| 201 | Created (POST) |
| 204 | No Content (DELETE) |
| 400 | Validation error |
| 401 | Authentication required |
| 403 | Permission denied |
| 404 | Not found |
| 409 | Conflict (already exists, state conflict) |
| 422 | Unprocessable (valid syntax, wrong semantics) |
| 429 | Rate limit exceeded |
| 500 | Internal server error |

## Database design & optimization

**Index strategy:**
```sql
-- Single column (equality lookups)
CREATE INDEX idx_users_email ON users(email);
-- Composite (order matters: equality cols first, then range)
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
-- Partial (filtered subset)
CREATE INDEX idx_orders_active ON orders(created_at) WHERE status = 'active';
-- Covering (avoid the table lookup entirely)
CREATE INDEX idx_users_email_name ON users(email) INCLUDE (name);
```

**Diagnose slow queries:** `EXPLAIN ANALYZE <query>`. Look for `Seq Scan` (bad) vs `Index Scan` (good).

**Prevent N+1:**
```python
# BAD: N+1
for user in users:
    orders = db.query(Order, where=user_id=user.id)   # one query per user

# GOOD: batch / eager load
orders = db.query(Order, where=user_id__in=[u.id for u in users])
```

**Connection pooling:** pool size ≈ `(2 × CPU cores) + 1` for a single instance. For serverless, use a managed pooler (PgBouncer, RDS Proxy, Supabase pooler) — a fresh connection per function invocation will exhaust the DB.

**Query optimization patterns:**
- Use `EXISTS` instead of `IN` for large subqueries.
- Avoid functions on indexed columns: `WHERE created_at >= '2026-01-01'` not `WHERE YEAR(created_at) = 2026`.
- Prefer covering indexes for hot queries.
- Paginate with keyset (cursor) for large datasets, not `LIMIT/OFFSET`.

## Authentication & authorization

**Password hashing:**
```python
import bcrypt
hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12))
ok   = bcrypt.checkpw(password.encode(), stored_hash)
```
Use Argon2id where available — it's the current recommendation. Never MD5/SHA-1/SHA-256 for passwords.

**JWT configuration:**
```python
JWT = {
    "secret": os.environ["JWT_SECRET"],   # from env, never hardcoded
    "expires_in": 900,                    # 15 min access tokens
    "algorithm": "RS256",                # asymmetric, so only you can sign
}
```
Short-lived access tokens (≤ 15 min) + longer refresh tokens (≤ 7 days). Rotate refresh tokens on use.

**Rate limiting:**
```python
from express_rate_limit import rate_limit   # or flask-limiter / slowapi
api_limiter = rate_limit(window=900, max=100)
```

**Input validation:** validate at the boundary, with a schema (Zod / pydantic / marshmallow). Reject anything that doesn't match. Never trust client input — validate server-side, on every request.

```python
from pydantic import BaseModel, EmailStr, Field
class CreateUser(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=12)
```

## Security hardening

- **Headers** (Helmet or equivalent): CSP, HSTS, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`.
- **CORS:** explicit origin allowlist, `credentials: true` only when needed. Never `*` with credentials.
- **TLS:** TLS 1.2+ everywhere, 1.3 preferred.
- **Least privilege:** the service account / DB user gets only the grants it needs.

## Performance targets (defaults)

| Metric | Target |
|--------|--------|
| P50 latency | < 50 ms |
| P95 latency | < 200 ms |
| P99 latency | < 500 ms |
| Error rate | < 0.1% |
| Throughput | > 500 req/s per instance |

Tune these to your actual SLA — a checkout API has tighter targets than an internal admin tool.

## Lightweight server-side use cases

For webhooks, form backends, and small tools, you don't need a full framework:

```python
import sqlite3, json, hmac, hashlib

def verify_signature(payload: bytes, signature: str, secret: str) -> bool:
    expected = 'sha256=' + hmac.new(
        secret.encode(), payload, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)

def get_db():
    db = sqlite3.connect('data.db')
    db.row_factory = sqlite3.Row
    return db
```

Use SQLite for anything < ~10k concurrent readers and no need for cross-machine writes. Graduate to Postgres when you need concurrent writes, complex queries, or multiple app instances.

## Local database workflow (no managed cloud DB)

When working against a locally running database (SQLite, local Postgres in Docker, etc.) rather than a managed service:

**1. Inspect the actual schema first.** Never assume columns or types.
```bash
# SQLite
sqlite3 data.db ".schema"
sqlite3 data.db "PRAGMA table_info(users);"

# Postgres (local)
psql $DATABASE_URL -c "\dt"
psql $DATABASE_URL -c "\d users"
```

**2. Write reversible migrations.** Every migration should have a corresponding down-migration or a clear rollback path.
```
migrations/
├── 001_create_users.sql        # up
├── 001_create_users.down.sql   # down (DROP TABLE)
├── 002_add_orders.sql
└── 002_add_orders.down.sql
```

**3. No destructive operations without explicit confirmation.**
- `DROP TABLE`, `TRUNCATE`, `ALTER TABLE ... DROP COLUMN` → stop and ask.
- `DELETE` without a `WHERE` → stop and ask.
- Any migration that alters data in place (not just schema) → stop and ask.

**4. Parameterized queries, always.** No string-concatenated SQL. No f-string / template SQL with user input.

**5. Test against the local instance and show the output.**
```bash
# Apply a migration
psql $DATABASE_URL -f migrations/002_add_orders.sql
# Verify
psql $DATABASE_URL -c "SELECT count(*) FROM orders;"
```
Paste the real output. "I ran the migration" is not evidence; the `CREATE TABLE` / row count is.

**6. Local Postgres in Docker (typical setup):**
```yaml
# docker-compose.yml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: app
      POSTGRES_PASSWORD: dev-only-not-a-secret
    ports:
      - "5432:5432"
    volumes:
      - dbdata:/var/lib/postgresql/data
volumes:
  dbdata:
```

**7. Version-pin the local DB** (in Docker Compose or a `.tool-versions` file) so the team and CI use the same major version.

