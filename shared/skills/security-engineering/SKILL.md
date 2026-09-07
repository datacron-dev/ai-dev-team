---
name: security-engineering
description: Secure coding, threat modeling, and security audits — OWASP Top 10 prevention, input validation, authentication/session patterns, cryptographic algorithm selection, secrets management, STRIDE threat modeling, defense-in-depth architecture, and compliance frameworks (SOC 2, GDPR, PCI-DSS, HIPAA). Use this skill whenever the user is implementing security controls, doing a security audit or code review for vulnerabilities, responding to a vulnerability report, designing a secure architecture, choosing crypto or auth patterns, or needs to meet a compliance framework.
---

# Security Engineering

## OWASP Top 10 — prevention focus

| Vulnerability | Prevention |
|--------------|------------|
| A01 Broken Access Control | RBAC, deny by default, validate permissions server-side |
| A02 Cryptographic Failures | TLS 1.3+, AES-256-GCM, secure key management |
| A03 Injection | Parameterized queries, input validation, escape output |
| A04 Insecure Design | Threat modeling, secure design patterns, defense in depth |
| A05 Security Misconfiguration | Hardening guides, remove defaults, disable unused features |
| A06 Vulnerable Components | Dependency scanning, automated updates, SBOM |
| A07 Authentication Failures | MFA, rate limiting, secure password storage |
| A08 Data Integrity Failures | Code signing, integrity checks, secure CI/CD |
| A09 Security Logging Failures | Comprehensive audit logs, SIEM integration |
| A10 SSRF | URL validation, allowlist destinations, network segmentation |

## Secure coding checklist

**Input validation:**
- [ ] All user input validated server-side (never trust the client)
- [ ] Allowlists over denylists
- [ ] Context-appropriate sanitization (HTML, SQL, shell)
- [ ] Parameterized queries — never string-concatenate SQL

**Authentication:**
- [ ] Passwords hashed with Argon2id / bcrypt (min 12 rounds)
- [ ] MFA for sensitive operations
- [ ] Strong password policy (min 12 chars, complexity)
- [ ] Short-lived access tokens (15 min), longer refresh tokens (7 days)

**Session management:**
- [ ] Secure random session IDs (never `Math.random` / `rand`)
- [ ] Cookies: `HttpOnly`, `Secure`, `SameSite=Strict`
- [ ] Session timeout (15 min idle)
- [ ] Token rotation on privilege escalation

**Secrets management:**
- [ ] Environment variables or a dedicated secrets manager
- [ ] Never commit secrets to version control (add a pre-commit secret scanner)
- [ ] Rotate credentials on team member departure
- [ ] `.env.example` with placeholder values only

**Error handling:**
- [ ] Log errors with context (never log secrets or PII)
- [ ] Return generic messages to users
- [ ] Never expose stack traces in production

## Cryptographic algorithm selection

| Use case | Algorithm | Key size |
|----------|-----------|----------|
| Symmetric encryption | AES-256-GCM | 256 bits |
| Password hashing | Argon2id | defaults |
| Message authentication | HMAC-SHA256 | 256 bits |
| Digital signatures | Ed25519 | 256 bits |
| Key exchange | X25519 | 256 bits |
| TLS | TLS 1.3 | — |

```python
import bcrypt
from secrets import token_hex
hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12))
valid = bcrypt.checkpw(password.encode(), hash)
token = token_hex(32)   # cryptographically secure, NOT random.randint
```

## Authentication pattern selection

| Use case | Recommended |
|----------|-------------|
| Web application | OAuth 2.0 + PKCE with OIDC |
| API authentication | JWT (RS256) + short expiration + refresh tokens |
| Service-to-service | mTLS with certificate rotation |
| CLI / automation | API keys with IP allowlisting |
| High security | FIDO2 / WebAuthn hardware keys |

## Threat modeling (STRIDE)

**Workflow:**
1. Define system scope (assets, trust boundaries, data flows).
2. Create a data flow diagram (DFD).
3. Apply STRIDE to each DFD element.
4. Score risks with DREAD (Damage, Reproducibility, Exploitability, Affected users, Detection).
5. Prioritize and define mitigations.

**STRIDE categories:**

| Category | Property | Mitigation focus |
|----------|----------|------------------|
| Spoofing | Authentication | MFA, certificates, strong auth |
| Tampering | Integrity | Signing, checksums, validation |
| Repudiation | Non-repudiation | Audit logs, digital signatures |
| Information Disclosure | Confidentiality | Encryption, access controls |
| Denial of Service | Availability | Rate limiting, redundancy |
| Elevation of Privilege | Authorization | RBAC, least privilege |

**Which STRIDE applies to which DFD element:**

| Element | S | T | R | I | D | E |
|---------|---|---|---|---|---|---|
| External entity | X | | X | | | |
| Process | X | X | X | X | X | X |
| Data store | | X | X | X | X | |
| Data flow | | X | | X | X | |

## Defense in depth

```
Layer 1: PERIMETER    WAF, DDoS mitigation, DNS filtering, rate limiting
Layer 2: NETWORK      Segmentation, IDS/IPS, monitoring, VPN, mTLS
Layer 3: HOST         Endpoint protection, OS hardening, patching, EDR
Layer 4: APPLICATION  Input validation, auth, secure coding, SAST
Layer 5: DATA         Encryption at rest/transit, access controls, DLP, backup
```

**Zero Trust principles:**
- Verify explicitly (authenticate/authorize every request).
- Least privilege (just-in-time, just-enough access).
- Assume breach (segment, monitor, detect lateral movement).

## Compliance frameworks

**SOC 2 Type II (key controls):**
| Control | Category |
|---------|----------|
| CC1 | Control environment (policies, org structure) |
| CC3 | Risk assessment (vuln scanning, threat modeling) |
| CC6 | Logical access (auth, authorization, MFA) |
| CC7 | System operations (monitoring, logging, incident response) |
| CC8 | Change management (CI/CD, code review, deployment controls) |

**GDPR (key articles):**
| Article | Requirement |
|---------|-------------|
| Art 25 | Privacy by design, data minimization |
| Art 32 | Security measures, encryption, pseudonymization |
| Art 33 | Breach notification (72 hours) |
| Art 17 | Right to erasure |
| Art 20 | Data portability (export) |

## Incident response

```
PHASE 1: DETECT & IDENTIFY (0–15 min)
- Alert acknowledged, severity assessed (SEV-1..4)
- Incident commander assigned, comms channel opened

PHASE 2: CONTAIN (15–60 min)
- Affected systems identified, network isolation if needed
- Credentials rotated if compromised, evidence preserved

PHASE 3: ERADICATE (1–4 hours)
- Root cause identified, backdoors/malware removed, patched, hardened

PHASE 4: RECOVER (4–24 hours)
- Restored from clean backup, services online, enhanced monitoring

PHASE 5: POST-INCIDENT (24–72 hours)
- Timeline documented, RCA complete, lessons learned, stakeholder report
```

**Severity levels:**
| Level | Description | Response |
|-------|-------------|----------|
| P1 – Critical | Active breach, data exfiltration | Immediate |
| P2 – High | Confirmed compromise, contained | 1 hour |
| P3 – Medium | Potential compromise, investigating | 4 hours |
| P4 – Low | Suspicious activity, low impact | 24 hours |
