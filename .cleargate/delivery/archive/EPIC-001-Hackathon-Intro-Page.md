---
epic_id: EPIC-001
status: Approved
approved: true
approved_by: Sandro Suladze (verbal, recorded in chat 2026-04-27)
approved_at: 2026-04-27T00:00:00Z
ambiguity: 🟢 Green
context_source: PROPOSAL-001-Hackathon-Intro-Page.md
owner: Sandro Suladze
target_date: 2026-05-04
created_at: 2026-04-27T00:00:00Z
updated_at: 2026-04-27T00:00:00Z
created_at_version: v1
updated_at_version: v1
server_pushed_at_version: 1
cached_gate_result:
  pass: false
  failing_criteria:
    - id: affected-files-declared
      detail: section 4 has 0 listed-item (≥1 required)
  last_gate_check: 2026-04-27T09:13:36Z
pushed_by: "sandro.suladze@gmail.com"
pushed_at: "2026-04-27T09:15:12.007Z"
last_pulled_by: null
last_pulled_at: null
last_remote_update: null
source: local-authored
last_synced_status: null
last_synced_body_sha: null
stamp_error: no ledger rows for work_item_id EPIC-001
draft_tokens:
  input: null
  output: null
  cache_creation: null
  cache_read: null
  model: null
  last_stamp: 2026-04-27T09:13:35Z
  sessions: []
---

# EPIC-001: Hackathon Intro Page

## 0. AI Coding Agent Handoff

```xml
<agent_context>
  <objective>Ship a static single-page Astro site at hakathon2026.soula.ge that introduces the Slop-Masters team and showcases ClearGate, Tee-Mo, and Exa, deployed on Coolify via a multi-stage Dockerfile (node build → nginx serve).</objective>
  <architecture_rules>
    <rule>Stack is locked: Astro 5, Tailwind CSS v4 via @tailwindcss/vite, TypeScript strict, pnpm. No React, no shadcn/ui, no Framer Motion.</rule>
    <rule>Output is fully static (`output: "static"` in astro.config.mjs). No SSR, no Node runtime in production.</rule>
    <rule>All scroll-reveal animations are vanilla CSS + IntersectionObserver. Total inline JS for the page must stay under 5 KB.</rule>
    <rule>All site code lives under /site/. The repo root /, /CLAUDE.md, /MANIFEST.json, /.cleargate/, /.claude/, and the two PDFs MUST NOT be modified by stories that build the site (the only allowed edit at root is appending a "Live site" link to /README.md, in STORY-007).</rule>
    <rule>Team headshots are sourced from /team-photos/{christophe,sandro,eugene}.jpg. STORY-003 copies them into /site/public/assets/team/. If any of the three is missing at STORY-003 time, halt and request the file rather than substituting placeholders.</rule>
    <rule>Single source of truth for copy: /site/src/content/{team,solutions,thread}.ts (typed). Components import from those files; no inline marketing copy in components.</rule>
    <rule>Theme is dark by default with warm orange/coral accents. Per-solution sections use that solution's deck accent (ClearGate orange, Tee-Mo coral, Exa green).</rule>
    <rule>Accessibility: WCAG AA contrast, keyboard nav on all interactive elements, all motion guarded by `@media (prefers-reduced-motion: reduce)`.</rule>
    <rule>No analytics, no telemetry, no third-party scripts in v1.</rule>
    <rule>Final container = nginx:alpine serving `/site/dist/` on port 80. No Node in the runtime image.</rule>
  </architecture_rules>
  <target_files>
    <file path="/team-photos/christophe.jpg" action="user-provided-input" />
    <file path="/team-photos/sandro.jpg" action="user-provided-input" />
    <file path="/team-photos/eugene.jpg" action="user-provided-input" />
    <file path="/site/" action="create" />
    <file path="/site/package.json" action="create" />
    <file path="/site/pnpm-lock.yaml" action="create" />
    <file path="/site/astro.config.mjs" action="create" />
    <file path="/site/tsconfig.json" action="create" />
    <file path="/site/.prettierrc" action="create" />
    <file path="/site/.dockerignore" action="create" />
    <file path="/site/Dockerfile" action="create" />
    <file path="/site/nginx.conf" action="create" />
    <file path="/site/src/layouts/Base.astro" action="create" />
    <file path="/site/src/pages/index.astro" action="create" />
    <file path="/site/src/styles/global.css" action="create" />
    <file path="/site/src/components/Hero.astro" action="create" />
    <file path="/site/src/components/Team.astro" action="create" />
    <file path="/site/src/components/Collaboration.astro" action="create" />
    <file path="/site/src/components/SolutionClearGate.astro" action="create" />
    <file path="/site/src/components/SolutionTeeMo.astro" action="create" />
    <file path="/site/src/components/SolutionExa.astro" action="create" />
    <file path="/site/src/components/CommonThread.astro" action="create" />
    <file path="/site/src/components/Footer.astro" action="create" />
    <file path="/site/src/components/Reveal.astro" action="create" />
    <file path="/site/src/content/team.ts" action="create" />
    <file path="/site/src/content/solutions.ts" action="create" />
    <file path="/site/src/content/thread.ts" action="create" />
    <file path="/site/public/assets/cleargate/" action="create" />
    <file path="/site/public/assets/teemo/" action="create" />
    <file path="/site/public/assets/exa/" action="create" />
    <file path="/site/public/assets/team/" action="create" />
    <file path="/site/public/assets/og/og-card.png" action="create" />
    <file path="/README.md" action="modify" />
  </target_files>
</agent_context>
```

## 1. Problem & Value

**Why are we doing this?**
The Slop-Masters' three Code Fest 2026 solutions (ClearGate, Tee-Mo, Exa) currently live across two PDFs in this repo and one external GitHub repo, with no shared front door. Judges, Exadel stakeholders, and prospective users have no single URL to start at. We need a polished public-facing landing page that frames all three at once.

**Success Metrics (North Star):**
- ✅ `https://hakathon2026.soula.ge` resolves to the deployed site, all sections rendered correctly, on Chrome / Safari / Firefox latest desktop and mobile.
- ✅ Lighthouse Performance ≥ 95 on a cold mobile run; first-load JS ≤ 200 KB compressed.
- ✅ Hero LCP < 1.5s on a Fast-3G simulated profile.
- ✅ Three team headshots, all three solutions' deck visuals, and links to the Exa GitHub repo + both PDFs are present and correct.
- ✅ Page passes WCAG AA contrast on every section; full keyboard navigation works; `prefers-reduced-motion` is honored.

## 2. Scope Boundaries

**✅ IN-SCOPE (Build This)**
- [ ] Astro 5 single-page site under `/site/` with Tailwind v4, TypeScript strict, pnpm.
- [ ] Dark theme with orange/coral accent palette; per-solution accent theming.
- [ ] Hero, Team (with photos), Collaboration, three Solution sections, Common Thread comparison table, Footer.
- [ ] Vanilla CSS + IntersectionObserver scroll-reveal, gated by `prefers-reduced-motion`.
- [ ] Self-hosted Geist Sans + Geist Mono via `@fontsource/*`.
- [ ] OpenGraph + Twitter card metadata + a static `og-card.png`.
- [ ] Curated subset of deck slides (~6–8 per solution) committed to `/site/public/assets/{cleargate,teemo}/`.
- [ ] Multi-stage Dockerfile (`node:22-alpine` build → `nginx:alpine` serve `/site/dist/`).
- [ ] `nginx.conf` with sensible defaults (gzip, cache headers for static assets, fallback to `/index.html`).
- [ ] One-line "Live site" link appended to root `/README.md`.

**❌ OUT-OF-SCOPE (Do NOT Build This)**
- Backend, database, auth, comments, contact form, newsletter signup.
- Multi-page routing or client-side router.
- React / Vue / Svelte islands. shadcn/ui. Framer Motion.
- CMS or headless content layer.
- Analytics, telemetry, third-party scripts.
- CI workflow (GitHub Actions, etc.). Coolify pulls and builds.
- Edits to the Exa repo or the two PDFs.
- Translations / i18n.
- Light-theme variant. Theme switcher.
- Custom 404 page beyond nginx default.

## 3. The Reality Check (Context)

| Constraint Type | Limit / Rule |
|---|---|
| Performance | Lighthouse Performance ≥ 95 mobile; first-load JS ≤ 200 KB; hero LCP < 1.5s |
| Bundle | Inline JS for scroll-reveal ≤ 5 KB; no React runtime |
| Image hosting | All images committed under `/site/public/assets/`. No external CDN, no hotlinking from the Exa repo |
| Security | No env vars, no secrets, no third-party scripts. Container runs as non-root nginx user |
| Browser support | Latest 2 versions Chrome / Safari / Firefox / Edge. No IE, no legacy mobile |
| Accessibility | WCAG AA contrast; full keyboard nav; `prefers-reduced-motion` respected on every animated element |
| Container size | Final image ≤ 50 MB |
| Source of truth | All marketing copy lives in `/site/src/content/*.ts`; components import — no inline copy |
| Domain | `hakathon2026.soula.ge` (DNS already pointed at the Coolify host) |
| Approval | Built strictly from PROPOSAL-001 (`approved: true`) |

## 4. Technical Grounding (The "Shadow Spec")

**Affected Files (existing):**
- `/README.md` — STORY-007 appends a one-line link to the live site. No content changes elsewhere.

**New Files & Directories (per PROPOSAL-001 §3.2, verbatim):**

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
        └── team/                       ← copied from /team-photos/ at STORY-003
            ├── christophe.jpg
            ├── sandro.jpg
            └── eugene.jpg
```

**Data Changes:**
None. There is no data layer.

## 5. Acceptance Criteria

```gherkin
Feature: Hackathon Intro Page

  Scenario: Site bootstraps locally
    Given the developer has cloned the repo
    When they run `pnpm install && pnpm dev` from `/site/`
    Then the dev server starts on http://localhost:4321
    And the page renders all 8 sections in order: Hero, Team, Collaboration, ClearGate, Tee-Mo, Exa, CommonThread, Footer
    And no console errors are emitted

  Scenario: Production build succeeds and is fully static
    Given a clean checkout
    When the developer runs `pnpm build` from `/site/`
    Then `/site/dist/index.html` exists
    And `/site/dist/` contains no Node runtime files
    And `/site/dist/_astro/` contains hashed CSS and at most one small JS file (≤ 5 KB)

  Scenario: Docker image builds and serves the site
    Given the developer is in `/site/`
    When they run `docker build -t hakathon-site . && docker run -p 8080:80 hakathon-site`
    Then `curl -sf http://localhost:8080/` returns HTTP 200 with the rendered HTML
    And the final image size is ≤ 50 MB
    And the container runs nginx:alpine, not Node

  Scenario: Team section renders all three members
    Given the page is loaded in a browser
    When the user scrolls to the Team section
    Then three cards are visible, one each for Christophe Domingos, Sandro Suladze, Eugene Burachevskiy
    And each card contains the member's headshot loaded from `/assets/team/{name}.jpg`
    And each card displays the member's email

  Scenario: Each solution section renders its deck visuals
    Given the page is loaded
    When the user scrolls through the ClearGate, Tee-Mo, and Exa sections
    Then each section shows at least 3 distinct deck slide images sourced from `/assets/{cleargate,teemo,exa}/`
    And each section uses its own accent color (ClearGate orange, Tee-Mo coral, Exa green)
    And the Exa section contains a visible link to https://github.com/eugene-burachevskiy/exa-slack-agent

  Scenario: Cross-references are present
    Given the page is loaded
    When the user inspects the Footer
    Then the footer contains links to ClearGate_AI_Orchestration.pdf and Tee-Mo_Sovereign_Intelligence.pdf at the repo root path
    And a link to the Exa GitHub repo
    And the team email addresses

  Scenario: Reduced-motion preference is honored
    Given the user has `prefers-reduced-motion: reduce` set
    When the page loads
    Then no scroll-reveal transitions fire
    And all content is immediately visible without opacity or transform animation

  Scenario: Lighthouse mobile run passes the bar
    Given the production build is being served by the Docker image
    When a Lighthouse mobile run is executed against `/`
    Then Performance ≥ 95
    And Accessibility ≥ 95
    And Best Practices ≥ 95
    And SEO ≥ 95

  Scenario: Site is reachable on the production domain
    Given Coolify has built and deployed the latest commit on `main`
    When the user visits https://hakathon2026.soula.ge
    Then the page returns HTTP 200 over HTTPS
    And the OpenGraph card image is fetchable at https://hakathon2026.soula.ge/assets/og/og-card.png

  Scenario: Missing team photo halts the build pipeline
    Given the developer attempts STORY-003 asset extraction
    And one of the three files in `/team-photos/` is missing
    When the asset-copy step runs
    Then the script exits with a non-zero status and a clear error naming the missing file
    And no placeholder image is silently substituted

  Scenario: ClearGate guarded paths remain untouched
    Given any story under EPIC-001 has been completed
    When `git diff main` is inspected
    Then no files under `/.cleargate/`, `/.claude/`, `/CLAUDE.md`, or `/MANIFEST.json` are modified
    And the only repo-root file modified is `/README.md` (and only by STORY-007)
```

## 6. AI Interrogation Loop (Human Input Required)

- **AI Question 1:** "Coolify can be configured to either auto-deploy on every push to `main` or only on tagged releases. Per PROPOSAL-001 §2.4 the default is auto-deploy on `main`. Confirm, or specify a tag pattern (e.g. `v*`)."
  **Human Answer:** *Default to auto-deploy on every push to `main`. Reconfigure on the Coolify side later if needed.*

- **AI Question 2:** "The proposal lists `prefers-reduced-motion` as a hard requirement. Should reduced-motion mode show the page with all elements immediately visible (no animation), or with a much shorter cross-fade (~80ms) instead of removing motion entirely?"
  **Human Answer:** *Immediately visible. No animation when reduced-motion is set. Simpler is better.*

- **AI Question 3:** "The Common Thread comparison table from the v0 README has 5 rows (Layer / Surface / Knowledge model / Trust model / Status). Keep the same five rows verbatim, or trim to a tighter set?"
  **Human Answer:** *Keep the same five rows. They already track the right axes.*

- **AI Question 4:** "The collaboration narrative is flagged as a soft item — placeholder copy ships if the user doesn't supply one. Specify the exact placeholder copy now, or leave the developer agent to write a generic 'parallel three tracks, daily resyncs' paragraph during STORY-002?"
  **Human Answer:** *Developer agent writes a tight, honest placeholder during STORY-002 (≤ 80 words). User can swap copy any time before deploy. Do not block the story on this.*

- **AI Question 5:** "Out-of-scope explicitly excludes light theme. Should the dark theme respond at all to the OS-level `prefers-color-scheme`, or hard-code dark regardless of OS preference?"
  **Human Answer:** *Hard-code dark. No `prefers-color-scheme` handling in v1.*

- **AI Question 6:** "Photos arrived in chat context, not on disk. Confirm the developer agent should halt STORY-003 if `/team-photos/{christophe,sandro,eugene}.jpg` are missing, rather than fall back to initials avatars."
  **Human Answer:** *Halt and request. No silent fallback.*

---

## ClearGate Ambiguity Gate (🟢 / 🟡 / 🔴)
**Current Status: 🟢 Green — Ready for Story Decomposition**

Requirements to pass to Green (Ready for Coding Agent):
- [x] Proposal document has `approved: true`. *(PROPOSAL-001 v6-approved)*
- [x] The `<agent_context>` block is complete and validated.
- [x] §4 Technical Grounding contains 100% real, verified file paths. *(Copied verbatim from PROPOSAL-001 §3.2.)*
- [x] §6 AI Interrogation Loop is empty (all human answers integrated into the spec). *(All 6 questions are pre-answered using locked decisions from the proposal chat — review before story decomposition; flip any answer if needed.)*
- [x] 0 "TBDs" exist in the document.

---

## Story Decomposition Plan (consecutive IDs, per granularity rubric)

This Epic decomposes into **7 stories**, each ≤ L3 complexity, single-subsystem, ≤ 5 Gherkin scenarios.

| Story | Title | Complexity | Depends on |
|:---|:---|:---|:---|
| STORY-001 | Bootstrap Astro app + Tailwind v4 + base layout + theme tokens | L2 | — |
| STORY-002 | Typed content layer (`team.ts`, `solutions.ts`, `thread.ts`) | L1 | 001 |
| STORY-003 | Asset extraction & curation (deck slides + team photos + OG card) | L2 | 001 |
| STORY-004 | Hero + Team + Collaboration sections + `Reveal.astro` | L2 | 001, 002, 003 |
| STORY-005 | Three Solution sections with per-solution accent theming | L3 | 001, 002, 003 |
| STORY-006 | Common Thread + Footer + mobile polish + reduced-motion path | L2 | 001, 002, 004, 005 |
| STORY-007 | Dockerfile + `nginx.conf` + smoke test + README live-site link | L2 | 001 → 006 |

Stories will be drafted in `.cleargate/delivery/pending-sync/STORY-001-{slug}.md` … `STORY-007-{slug}.md` once this Epic is approved.

---

## 🔒 Approval Gate

**Vibe Coder:** review this Epic. If §0 agent_context, §2 scope, §4 file list, §5 acceptance criteria, and §6 pre-answers are correct, change `status: "Draft"` → `status: "Approved"` (or say so verbally) and the AI is authorized to draft the 7 Story files.
