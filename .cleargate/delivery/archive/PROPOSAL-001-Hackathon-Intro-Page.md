---
proposal_id: "PROP-001"
status: "Approved"
author: "Claude (Opus 4.7) + Sandro Suladze"
approved: true
approved_by: "Sandro Suladze (verbal, recorded in chat 2026-04-27)"
approved_at: "2026-04-27T00:00:00Z"
created_at: "2026-04-27T00:00:00Z"
updated_at: "2026-04-27T00:00:00Z"
created_at_version: "v1"
updated_at_version: "v6-approved"
server_pushed_at_version: 1
draft_tokens:
  input: null
  output: null
  cache_read: null
  cache_creation: null
  model: "claude-opus-4-7"
  sessions: []
cached_gate_result:
  pass: null
  failing_criteria: []
  last_gate_check: null
pushed_by: "sandro.suladze@gmail.com"
pushed_at: "2026-04-27T09:13:08.962Z"
last_pulled_by: null
last_pulled_at: null
last_remote_update: null
source: "local-authored"
last_synced_status: null
last_synced_body_sha: null
---

# PROPOSAL-001: Hackathon Intro Page

## 1. Initiative & Context

### 1.1 Objective
Ship a **sleek, deployable single-page web app** at `hakathon2026.soula.ge` that introduces the Slop-Masters team, tells the collaboration story, and showcases the three Code Fest 2026 solutions (ClearGate, Tee-Mo, Exa) — production-grade design, deck-matched visuals, smooth scroll animations, deployed on Coolify from this git repo.

### 1.2 The "Why"
- **Public-facing showcase, not a repo README.** Judges, Exadel stakeholders, and prospective users land on a polished URL — not a markdown blob in a private repo.
- **Single front door.** Three solutions in three places (two decks here + an external GitHub repo). Visitors get one canonical entry point that frames all three.
- **Deck assets are wasted.** The two NotebookLM decks have 27 polished slides between them. The site uses them as visual narrative, not just text descriptions.
- **Accuracy debt.** The collaboration narrative is currently *inferred* in the v0 README, and the v0 README assigns each solution to a single lead. Both must be corrected: **all three solutions are collectively owned by the team** — there are no per-solution leads. The collab narrative must be replaced with what actually happened before the site goes live.

### 1.3 Out of Scope (explicit)
- Backend, database, auth, user accounts, comments — this is a **static marketing site**.
- CMS, headless data layer — content lives in the repo as TS/MDX.
- Edits to the Exa repo or the source PDFs.
- A "merged" combined-product pitch — the three solutions remain three.
- Multi-page routing — single-page scroll is the deliberate UX.
- Replacing the existing `/README.md` — it stays as the in-repo README; the deployed site is the public-facing artifact.

## 2. Technical Architecture & Constraints

### 2.1 Dependencies
| Layer | Choice | Rationale |
|:---|:---|:---|
| Framework | **Astro 5** (zero-JS by default, static output) | Simplest possible for a content-first single-page site. No app router, no React runtime overhead. |
| Styling | **Tailwind CSS v4** (via `@tailwindcss/vite`) | Fast iteration, design-system-by-default |
| Components | Plain Astro components — no shadcn/ui | Removes a build dependency. The site is content + layout, not interactive UI. |
| Motion | Vanilla CSS animations + IntersectionObserver | Removes Framer Motion + React island complexity. ~30 lines of inline JS. |
| Icons | **lucide** (`lucide-static` SVGs, inlined) | Tree-shaken at build time, no JS bundle |
| Typography | **Geist Sans + Geist Mono** via `@fontsource/geist-sans` + `@fontsource/geist-mono` | Self-hosted, no Google Fonts dependency |
| Container | **Dockerfile**: `node:22-alpine` build → `nginx:alpine` serve `dist/` | Tiny final image (~30 MB), pure static, no Node runtime in production |
| Deployment | **Coolify** (user-managed) | Auto-deploy on push to `main`; DNS for `hakathon2026.soula.ge` already configured |
| Tooling | **pnpm**, **TypeScript (strict)**, **Prettier** | Lean baseline. No ESLint — Astro's TS check + Prettier is enough for a single-page site. |

### 2.2 System Constraints

| Constraint | Details |
|:---|:---|
| Performance | Lighthouse Performance ≥ 95 on a cold mobile run. Hero LCP < 1.5s. |
| Bundle | First-load JS ≤ 200 KB compressed for the landing route. |
| SEO | Static-rendered hero + per-section metadata; OpenGraph + Twitter card images committed to repo. |
| Accessibility | WCAG AA color contrast; all motion respects `prefers-reduced-motion`; keyboard nav on every interactive surface. |
| Browser support | Latest 2 versions of Chrome / Safari / Firefox / Edge. No IE, no legacy mobile. |
| Single source of truth | All copy lives in `/site/content/` as typed TS/MDX. No duplicate copy in code. |
| Image hosting | Deck slides + team assets committed to `/site/public/assets/`. No external CDN, no hotlinking from the Exa repo. |
| ClearGate scope | Site code + assets + Dockerfile only. No CI workflow, no monitoring, no analytics in v1. |
| Tone | Match the decks' visual register — confident, concrete, deck-grade polish. No generic AI-pastel landing-page tropes. |

### 2.3 Site Structure (sections, in scroll order)

1. **Hero** — team name, tagline ("Three solutions. One thesis."), animated background, CTA scroll-down.
2. **The Team** — three cards (Eugene, Sandro, Christophe), each with role, email, and the solution they led.
3. **How We Collaborated** — narrative paragraph (real story, not inferred) + a small diagram or pull-quote treatment.
4. **The Three Solutions** — three full-width sections, each with its own accent color borrowed from its deck:
   - **ClearGate** (orange/dark) — feature grid, key visuals from the deck (e.g., the four-agent loop diagram, the gates funnel).
   - **Tee-Mo** (coral/light) — Read/Act/Automate triptych, the BYOK trust block, the channel-isolation diagram.
   - **Exa** (green/dark) — features grid, architecture diagram, links to the live GitHub repo.
5. **The Common Thread** — comparison table (Layer / Surface / Knowledge model / Trust model / Status) tying the three together.
6. **Footer** — Code Fest 2026 attribution, links to PDFs and Exa repo, year.

### 2.4 Deployment Flow

```
git push main  ─►  Coolify webhook  ─►  multi-stage Docker build
              ─►  Stage 1: node:22-alpine → pnpm install → astro build → dist/
              ─►  Stage 2: nginx:alpine → COPY dist/ /usr/share/nginx/html
              ─►  container starts on Coolify host (nginx :80)
              ─►  Coolify routes hakathon2026.soula.ge → :80  (DNS already configured)
```
The repo ships only the `Dockerfile` and `nginx.conf`. Coolify-side service config (domain mapping, TLS) is user-managed.

### 2.5 Expected Story Decomposition (informational — finalized in Epic phase)

1. **STORY-01: Bootstrap Astro app** — `pnpm create astro@latest site/`, Tailwind v4 via Vite plugin, Geist fonts, base layout, dark theme tokens.
2. **STORY-02: Content layer + types** — TS content files in `/site/src/content/{team,solutions,thread}.ts`, typed schema. Team narrative + photos slot here.
3. **STORY-03: Asset extraction** — curate ~6–8 deck slides per solution to `/site/public/assets/{cleargate,teemo}/`; produce OG card; copy team JPGs from `/team-photos/` to `/site/public/assets/team/`.
4. **STORY-04: Hero + Team + Collaboration sections** — Astro components, team-photo cards, scroll-reveal CSS via IntersectionObserver.
5. **STORY-05: Three solution sections** — per-solution accent theming, embedded slide visuals, feature grids.
6. **STORY-06: Common Thread + Footer** — comparison table, footer, mobile polish, `prefers-reduced-motion` path.
7. **STORY-07: Dockerfile + Coolify-ready build** — multi-stage Dockerfile (`node:22-alpine` build → `nginx:alpine` serve), `nginx.conf`, README setup notes, local smoke test.

## 3. Scope Impact (Touched Files & Data)

### 3.1 Known Files
- `/README.md` — minor edit at the end: add a "Live site" link to `https://hakathon2026.soula.ge` once deployed. No content changes.

### 3.2 Expected New Entities

```
/team-photos/                           ← user drops 3 JPGs here once
├── christophe.jpg
├── sandro.jpg
└── eugene.jpg

/site/                                  ← Astro app root
├── Dockerfile                          ← multi-stage: node build → nginx serve
├── nginx.conf                          ← static-friendly nginx config
├── .dockerignore
├── package.json, pnpm-lock.yaml
├── tsconfig.json, astro.config.mjs
├── .prettierrc
├── src/
│   ├── layouts/
│   │   └── Base.astro                  ← root layout, fonts, metadata
│   ├── pages/
│   │   └── index.astro                 ← single-page composition
│   ├── styles/
│   │   └── global.css                  ← Tailwind v4 + theme tokens
│   ├── components/
│   │   ├── Hero.astro
│   │   ├── Team.astro
│   │   ├── Collaboration.astro
│   │   ├── SolutionClearGate.astro
│   │   ├── SolutionTeeMo.astro
│   │   ├── SolutionExa.astro
│   │   ├── CommonThread.astro
│   │   ├── Footer.astro
│   │   └── Reveal.astro                ← IntersectionObserver scroll-reveal
│   └── content/
│       ├── team.ts                     ← typed team data
│       ├── solutions.ts                ← typed per-solution feature copy
│       └── thread.ts                   ← comparison-table data
└── public/
    └── assets/
        ├── cleargate/*.jpg             ← curated deck slides
        ├── teemo/*.jpg                 ← curated deck slides
        ├── exa/*.{jpg,png}             ← copies of relevant Exa repo images
        ├── og/og-card.png              ← OpenGraph share card
        └── team/                       ← copied from /team-photos/ at STORY-03
            ├── christophe.jpg
            ├── sandro.jpg
            └── eugene.jpg
```

### 3.3 What Does NOT Change
- `/CLAUDE.md`, `/.cleargate/`, `/.claude/` — untouched.
- `/MANIFEST.json` — untouched.
- The two PDFs at the repo root — untouched, treated as read-only sources.

---

## 🔒 Approval Gate

**Vibe Coder:** review this proposal. If the architecture and scope are correct, change `approved: false` → `approved: true` in the YAML frontmatter. Only then is the AI authorized to decompose this into an Epic + Stories and proceed.

**Resolved (recorded for the audit trail):**
- ✅ **Ownership.** All three solutions are collectively owned by the team. No per-solution leads.
- ✅ **Team photos.** Provided. User must drop the three JPGs at `/team-photos/{christophe,sandro,eugene}.jpg` once before STORY-03.
- ✅ **Tech stack.** Astro 5 + Tailwind v4 + vanilla CSS reveal animations + Dockerfile (`node:22-alpine` build → `nginx:alpine` serve). No React, no shadcn/ui, no Framer Motion.
- ✅ **Visual direction.** Dark theme with warm orange/coral accents echoing the decks. Per-solution sections use that solution's deck accent.
- ✅ **Coolify build target.** Dockerfile (multi-stage, static nginx serve). No env vars baked in.
- ✅ **Analytics.** None in v1.
- ✅ **DNS.** `hakathon2026.soula.ge` already points at the Coolify host.

**Soft items — fillable during execution, not blocking approval:**

1. **Collaboration narrative.** If not provided by STORY-02 start, the "How We Collaborated" section ships with a generic placeholder; user can swap copy in any time before deploy.
