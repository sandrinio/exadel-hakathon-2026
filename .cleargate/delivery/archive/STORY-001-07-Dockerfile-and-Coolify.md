---
story_id: STORY-001-07-Dockerfile-and-Coolify
parent_epic_ref: EPIC-001
status: Approved
approved: true
approved_by: Sandro Suladze (verbal, recorded in chat 2026-04-27)
approved_at: 2026-04-27T00:00:00Z
ambiguity: 🟢 Green
context_source: PROPOSAL-001-Hackathon-Intro-Page.md
actor: Developer
complexity_label: L2
parallel_eligible: n
expected_bounce_exposure: med
lane: standard
created_at: 2026-04-27T00:00:00Z
updated_at: 2026-04-27T00:00:00Z
created_at_version: v1
updated_at_version: v1
server_pushed_at_version: 1
cached_gate_result:
  pass: false
  failing_criteria:
    - id: implementation-files-declared
      detail: section 3 has 0 listed-item (≥1 required)
  last_gate_check: 2026-04-27T09:14:52Z
pushed_by: "sandro.suladze@gmail.com"
pushed_at: "2026-04-27T09:16:18.152Z"
last_pulled_by: null
last_pulled_at: null
last_remote_update: null
source: local-authored
last_synced_status: null
last_synced_body_sha: null
stamp_error: no ledger rows for work_item_id STORY-001-07-Dockerfile-and-Coolify
draft_tokens:
  input: null
  output: null
  cache_creation: null
  cache_read: null
  model: null
  last_stamp: 2026-04-27T09:14:51Z
  sessions: []
---

# STORY-001-07: Dockerfile + nginx.conf + Smoke Test + README Live-Site Link
**Complexity:** L2 — packages the static site for Coolify, smoke-tests locally, and adds the live URL to the root README.

## 1. The Spec (The Contract)

### 1.1 User Story
As a Developer, I want a single multi-stage Dockerfile that Coolify can build and run unattended at `hakathon2026.soula.ge`, so that pushing `main` updates the live site without any manual deploy steps.

### 1.2 Detailed Requirements

**`/site/Dockerfile`**

Multi-stage:

```dockerfile
# ── Build stage ──────────────────────────────────────────────────────────────
FROM node:22-alpine AS build
WORKDIR /app

# pnpm via corepack (no global install, deterministic)
RUN corepack enable

# Copy manifest first for layer cache
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy source PDFs (the prebuild hook expects them at ../*.pdf relative to /site)
# In the Docker build context this means we copy them from the repo root.
COPY . .
COPY ../ClearGate_AI_Orchestration.pdf ../Tee-Mo_Sovereign_Intelligence.pdf ./

RUN pnpm build

# ── Runtime stage ────────────────────────────────────────────────────────────
FROM nginx:alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

# nginx:alpine already exposes 80; CMD is the default.
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://localhost/ || exit 1
```

**Important build-context note.** `COPY ../*.pdf` is not legal Docker syntax — the build context only sees files at or below the build root. This story therefore does the build with the **repo root as the build context**, with `-f site/Dockerfile`. Update the Dockerfile accordingly:

```dockerfile
# Final form, expecting build context = repo root, Dockerfile = site/Dockerfile
FROM node:22-alpine AS build
WORKDIR /app
RUN corepack enable
COPY site/package.json site/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY site/ ./
COPY ClearGate_AI_Orchestration.pdf Tee-Mo_Sovereign_Intelligence.pdf ./
RUN pnpm build

FROM nginx:alpine AS runtime
COPY site/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://localhost/ || exit 1
```

The Coolify service must be configured with **build context = repo root** and **Dockerfile = `site/Dockerfile`**. Document this in the README hint added at the bottom of this story.

**`/site/nginx.conf`**

```nginx
server {
  listen 80 default_server;
  server_name _;
  root /usr/share/nginx/html;
  index index.html;

  # Single-page: fall back to index.html for unknown paths (the site has no SPA router,
  # but this prevents 404 on a stale cached deep link)
  location / {
    try_files $uri $uri/ /index.html;
  }

  # Long cache for hashed assets
  location /_astro/ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }

  # Short cache for non-hashed assets
  location /assets/ {
    expires 7d;
    add_header Cache-Control "public";
  }

  # Gzip
  gzip on;
  gzip_types text/css application/javascript image/svg+xml application/xml application/json;
  gzip_min_length 1024;

  # Security
  add_header X-Content-Type-Options "nosniff";
  add_header Referrer-Policy "strict-origin-when-cross-origin";
}
```

**`/site/.dockerignore`** (relative to the repo root because that's the build context):
```
**/node_modules
**/.git
**/dist
**/.astro
.cleargate
.claude
.github
team-photos
```

**Smoke test (manual, executed by the Developer agent locally before commit):**
```bash
# From repo root
docker build -t hakathon-site:smoke -f site/Dockerfile .
docker run --rm -p 8080:80 --name hakathon-smoke -d hakathon-site:smoke
sleep 1
curl -sf http://localhost:8080/                              | grep -q "Slop-Masters"
curl -sfI http://localhost:8080/ClearGate_AI_Orchestration.pdf | grep -q "200 OK"
curl -sfI http://localhost:8080/assets/team/sandro.jpg          | grep -q "200 OK"
docker stop hakathon-smoke
docker image inspect hakathon-site:smoke --format '{{.Size}}'   # must be <= 50_000_000
```

**Final image size guard.** `nginx:alpine` is ~50 MB on its own. Allowed total ≤ 50 MB net of base image is unrealistic; the realistic bar is **≤ 80 MB total** for the final image. Update EPIC §3 constraint accordingly during this story (one-line clarification in the Epic, not a re-decomposition).

**Root README link**

Append to `/README.md`:
```markdown

---

🌐 **Live site:** [hakathon2026.soula.ge](https://hakathon2026.soula.ge)
```

This is the single allowed edit outside `/site/` per EPIC-001 §0.

**No `.github/workflows/`, no GitHub Actions**, per the proposal/Epic out-of-scope.

### 1.3 Out of Scope
- Coolify-side configuration (user-managed; we only ship the Dockerfile and document expectations).
- Production Lighthouse audit beyond the smoke test command — final Lighthouse run happens manually against the live URL after Coolify deploys.
- Image registry / CDN.
- TLS termination — Coolify handles this.

## 2. The Truth (Executable Tests)

### 2.1 Acceptance Criteria (Gherkin)

```gherkin
Feature: Dockerfile + Coolify + README

  Scenario: Image builds clean from the repo root
    Given the developer is at the repo root
    When they run `docker build -t hakathon-site:test -f site/Dockerfile .`
    Then exit code is 0
    And the build output contains "Successfully" or equivalent

  Scenario: Image size stays inside the bar
    Given the build succeeded
    When the developer inspects `docker image inspect hakathon-site:test`
    Then the image size is <= 80 MB

  Scenario: Container serves the homepage
    Given the image is built
    When the developer runs the container on :8080 and curls /
    Then HTTP 200 is returned
    And the body contains "Slop-Masters"

  Scenario: Both PDFs are reachable from the running container
    Given the container is running on :8080
    When the developer curls /ClearGate_AI_Orchestration.pdf and /Tee-Mo_Sovereign_Intelligence.pdf
    Then both return HTTP 200 with Content-Type application/pdf

  Scenario: Static assets ship with long-cache headers
    Given the container is running
    When the developer curls -I /_astro/<any-hashed-css-or-js>
    Then the response includes "Cache-Control: public, immutable"

  Scenario: Healthcheck reports healthy
    Given the container has been running for at least 10 seconds
    When the developer runs `docker inspect --format='{{.State.Health.Status}}' hakathon-smoke`
    Then the value is "healthy"

  Scenario: README points at the live site
    Given the story has run
    When the developer reads /README.md
    Then it contains the substring "https://hakathon2026.soula.ge"

  Scenario: ClearGate guarded paths remain untouched
    Given STORY-001-07 has shipped
    When `git diff` against the story's pre-state is inspected
    Then no files under /.cleargate/, /.claude/, /CLAUDE.md, or /MANIFEST.json are modified
    And the only file modified outside /site/ is /README.md
```

### 2.2 Verification Steps (Manual)
- [ ] Run the smoke-test command block from §1.2 verbatim — every step passes.
- [ ] On Coolify, confirm the new service builds with `Dockerfile path = site/Dockerfile, Build context = /` and the public domain `hakathon2026.soula.ge` resolves with TLS.
- [ ] Lighthouse mobile run against `https://hakathon2026.soula.ge` — Performance ≥ 95.

## 3. The Implementation Guide

### 3.1 Context & Files

| Item | Value |
|---|---|
| New Files Needed | Yes |
| Primary File | `/site/Dockerfile` |
| Related Files | `/site/nginx.conf`, `/site/.dockerignore`, `/README.md` |

### 3.2 Technical Logic
1. **Build context = repo root.** This is the only way the prebuild hook (and the Dockerfile's PDF COPY) can reach the two PDF files at the root. Don't try to be cute with symlinks.
2. The prebuild hook from STORY-001-06 (`cp ../*.pdf public/`) works inside the build container because `WORKDIR /app` plus `COPY ClearGate*.pdf ... ./` lands the PDFs at `/app/...` — that is `..` from `/app/public/` after pnpm-build moves into the public-asset-build cycle. If the cp prebuild fails inside the container (e.g. because Astro runs `prebuild` with cwd = `/app` and the PDFs are next to package.json), update the prebuild to `cp ./*.pdf public/` — both forms are acceptable; pick what works in the container.
3. nginx as non-root: `nginx:alpine` already runs the worker process as `nginx`. No further user remapping needed.
4. Healthcheck uses `wget --spider` because alpine's curl is not in the base image.

### 3.3 API Contract
N/A.

## 4. Quality Gates

### 4.1 Minimum Test Expectations

| Test Type | Minimum Count | Notes |
|---|---|---|
| Unit tests | 0 | Infra story |
| Smoke (local Docker) | 1 | The full §1.2 smoke command block exits 0 end to end |
| E2E / acceptance | 8 | One per Gherkin scenario |

### 4.2 Definition of Done (The Gate)
- [ ] All Gherkin scenarios in §2.1 pass.
- [ ] Local smoke command block executes cleanly.
- [ ] Image ≤ 80 MB.
- [ ] Coolify build (or a documented dry-run thereof) is documented in a short note appended to `/site/README.md` if one exists, otherwise inline at the bottom of `/site/Dockerfile` as comments.
- [ ] No file outside `/site/` and `/README.md` is modified.
- [ ] One commit: `feat(site): dockerfile + nginx + readme link for coolify deploy`.

---

## ClearGate Ambiguity Gate (🟢 / 🟡 / 🔴)
**Current Status: 🟢 Green — Ready for Execution**
- [x] Gherkin scenarios cover all detailed requirements in §1.2.
- [x] Implementation Guide gives full Dockerfile + nginx config + smoke command.
- [x] Zero "TBDs" in this document.
