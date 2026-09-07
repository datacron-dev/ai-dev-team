---
name: devops-cicd
description: Set up CI/CD pipelines, containerize apps, and deploy to the cloud — GitHub Actions / CircleCI pipelines, Docker images, Kubernetes operations, Terraform infrastructure-as-code, deployment strategies (blue-green, canary, rolling), monitoring and structured logging. Use this skill whenever the user wants to set up or improve a CI/CD pipeline, write a Dockerfile, deploy to a cloud or Kubernetes cluster, manage infrastructure as code, choose a deployment strategy, or add monitoring/logging to a service.
---

# DevOps & CI/CD

## CI/CD pipeline (GitHub Actions)

A complete pipeline runs tests → security → build → deploy, with each stage gating the next:

```yaml
name: CI/CD Pipeline
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '20'
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: ${{ env.NODE_VERSION }}, cache: 'npm' }
      - run: npm ci
      - run: npm run lint
      - run: npm test -- --coverage

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Dependency audit
        run: npm audit --audit-level=high   # or pip-audit / cargo audit / govulncheck
      - name: Secret scan
        run: gitleaks detect --verbose

  build:
    needs: [test, security]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    outputs:
      image-digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v5
        id: build
        with:
          push: true
          tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy to Kubernetes
        run: |
          kubectl set image deployment/app \
            app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build.outputs.image-digest }}
          kubectl rollout status deployment/app
```

**Principles:**
- Every job that produces an artifact pins the *digest*, not the tag.
- Production deploys require an `environment:` (enforces required reviewers / approvals).
- Keep CI fast — cache dependencies, split test jobs by shard.
- Fail fast: tests before build, security before deploy.

## Docker

**Multi-stage build for Node.js:**
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

FROM node:20-alpine AS runner
WORKDIR /app
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nextjs:nextjs . .
USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
```

**Rules:**
- Run as non-root.
- Multi-stage: keep the runtime image small.
- Layer order by change frequency (deps first, code last) to maximize cache.
- Pin base image versions (or at least major) — don't float `latest` in production.
- Add a `HEALTHCHECK` matching your app's real readiness.

## Kubernetes operations

```bash
kubectl apply -f k8s/                 # apply manifests
kubectl rollout status deployment/app # check rollout
kubectl rollout undo deployment/app   # roll back
kubectl logs -f deployment/app --tail=100
kubectl scale deployment/app --replicas=5
kubectl top pods && kubectl top nodes
```

**Zero-downtime rolling update:**
```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

Always define readiness + liveness probes, and set resource requests/limits.

## Deployment strategies

**Blue-Green** — two identical environments; switch traffic once the new one is healthy. Fast rollback. Costs 2× resources.

**Canary** — route a small % of traffic to the new version, monitor, then ramp:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: app-canary, port: { number: 80 } }
```

**Rolling** — replace pods one at a time (default above). Good for stateless services; not ideal when old+new must coexist (schema migration).

**Choose:** stateless service → rolling or canary. Need instant rollback → blue-green. Zero resource overhead → rolling.

## Terraform

```
infrastructure/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── modules/
│   ├── vpc/
│   ├── eks/
│   └── rds/
└── environments/
    ├── staging/
    └── production/
```

**Example EKS module:**
```hcl
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.eks.id]
  }
  encryption_config {
    provider { key_arn = var.kms_key_arn }
    resources = ["secrets"]
  }
  depends_on = [aws_iam_role_policy_attachment.eks]
}
```

**Rules:**
- `terraform plan` in CI before any `apply`.
- Separate state per environment.
- Version the modules; pin provider versions.
- Never store secrets in Terraform state — use a secrets manager (AWS SM, GCP SM, Vault) and reference by ARN.

## Monitoring & alerting

**Health check endpoint:**
```typescript
app.get('/health', async (req, res) => {
  const checks = await Promise.allSettled([
    db.$queryRaw`SELECT 1`,
    redis.ping(),
  ]);
  const status = checks.every(c => c.status === 'fulfilled') ? 200 : 503;
  res.status(status).json({
    status: status === 200 ? 'healthy' : 'degraded',
    timestamp: new Date().toISOString(),
    checks: {
      database: checks[0].status,
      redis: checks[1].status,
    },
  });
});
```

**Structured logging (pino / structuredlog):**
```typescript
import pino from 'pino';
const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  redact: ['req.headers.authorization', 'body.password'],
});
logger.info({ userId, action: 'createOrder', orderId }, 'Order created');
logger.error({ err, userId, path: req.path }, 'Request failed');
```

**Alert on the four golden signals:** latency, traffic, errors, saturation. Not on every log line.

## Local-only dev environment (Docker Compose, no cloud)

For a local development setup on a single machine (no K8s, no cloud), use Docker Compose as the "infrastructure":

```yaml
# docker-compose.yml
services:
  app:
    build: .
    env_file: .env
    ports:
      - "8000:8000"
    depends_on:
      - db
      - redis
    command: uv run app.main:app   # or: npm run dev
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: app
      POSTGRES_PASSWORD: dev-only
    ports:
      - "5432:5432"
    volumes:
      - dbdata:/var/lib/postgresql/data
  redis:
    image: redis:7
    ports:
      - "6379:6379"
volumes:
  dbdata:
```

**Workflow:**
```bash
docker compose up -d            # start everything
docker compose logs -f app      # tail the app
docker compose ps               # check health
docker compose exec db psql -U app   # inspect the DB
docker compose down             # tear down (add -v to drop volumes)
```

**Rules for local dev:**
- **Use the project's existing run/build/test commands** — detect them from `package.json`, `Makefile`, or `pyproject.toml` (see the `engineering-discovery-and-planning` skill).
- **Env vars live in `.env`** (gitignored). Never hardcode secrets in `docker-compose.yml` or in code.
- **Confirm local build/test/lint parity with any CI config in-repo.** If the repo has a `.github/workflows/ci.yml`, the local commands should produce the same result as CI. You can't assume CI actually runs anywhere — verify locally.
- **Pin image versions** (`postgres:16`, `redis:7`) so the team is on the same major.
- **Add a healthcheck** to services that other services depend on, so `depends_on` waits for readiness, not just container start.
- **Volume for any stateful service** (db, redis) so restarts don't lose dev data — or deliberately don't, for a clean slate.

**When to reach for K8s instead of Compose:** only when you need multi-node scheduling, rolling deploys with zero downtime, or autoscaling. For a single dev machine, Compose is the right tool.

