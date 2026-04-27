---
story_id: STORY-001-06-Common-Thread-Footer-Polish
parent_epic_ref: EPIC-001
status: Approved
approved: true
approved_by: Sandro Suladze (verbal, recorded in chat 2026-04-27)
approved_at: 2026-04-27T00:00:00Z
ambiguity: 🟢 Green
context_source: PROPOSAL-001-Hackathon-Intro-Page.md
actor: Site Visitor
complexity_label: L2
parallel_eligible: n
expected_bounce_exposure: low
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
  last_gate_check: 2026-04-27T09:14:42Z
pushed_by: "sandro.suladze@gmail.com"
pushed_at: "2026-04-27T09:16:08.545Z"
last_pulled_by: null
last_pulled_at: null
last_remote_update: null
source: local-authored
last_synced_status: null
last_synced_body_sha: null
stamp_error: no ledger rows for work_item_id STORY-001-06-Common-Thread-Footer-Polish
draft_tokens:
  input: null
  output: null
  cache_creation: null
  cache_read: null
  model: null
  last_stamp: 2026-04-27T09:14:41Z
  sessions: []
---

# STORY-001-06: Common Thread + Footer + Mobile Polish + Reduced-Motion Pass
**Complexity:** L2 — closes the page and runs the responsive/a11y sweep across all sections built so far.

## 1. The Spec (The Contract)

### 1.1 User Story
As a Site Visitor, I want a tight closing summary that ties the three solutions together, a useful footer with all references, and a page that works flawlessly at any width and respects my motion preferences — so that the experience feels finished.

### 1.2 Detailed Requirements

**CommonThread.astro**
- Section heading: "The Common Thread".
- One-sentence intro: "Three altitudes, one philosophy: structure beats magic."
- Render a comparison table from `/site/src/content/thread.ts`. Columns: Axis | ClearGate | Tee-Mo | Exa.
- Implementation: a real `<table>` with `<thead>` and `<tbody>`. Mobile fallback (≤ 640px): switch to a per-row card stack via CSS only — `table { display: block; }`, each `<tr>` becomes a card with `<th>`s as inline labels.
- Accent: each solution column header carries its accent color text (`--color-accent-{slug}`).
- Wrap the section header and the table in `<Reveal>` separately.

**Footer.astro**
- Three columns on desktop (`md:grid-cols-3`), single column on mobile.
- Column 1: "Slop-Masters" wordmark + "Exadel Code Fest 2026" eyebrow + the year (`new Date().getFullYear()` rendered at build time via Astro frontmatter).
- Column 2: "Read the decks" — anchor links to:
  - `/ClearGate_AI_Orchestration.pdf` (this repo's root)
  - `/Tee-Mo_Sovereign_Intelligence.pdf` (this repo's root)
  - `https://github.com/eugene-burachevskiy/exa-slack-agent` (Exa repo)
  Astro `output: "static"` won't serve files from outside `/site/`, so STORY-001-06 must also `cp` (or symlink) the two root PDFs into `/site/public/` so `/ClearGate_AI_Orchestration.pdf` resolves on the deployed site. Add the copy to the `pnpm build` script as a `prebuild` hook (`"prebuild": "cp ../*.pdf public/"`) — keeps the source PDFs at the repo root untouched.
- Column 3: "Reach out" — three `mailto:` anchors (the three team emails).
- Below the columns: a thin top-border separator, then a centered subline: "Built with passion at Exadel Code Fest 2026." in muted text.
- No social icons, no newsletter, no external "powered by" badge.

**Mobile polish (sweep)**
- Test at 375 px (iPhone SE), 414 px (iPhone Pro Max), 768 px (tablet), 1024 px and 1440 px (desktop).
- Adjust hero typography to scale down via `clamp()` so the H1 fits without overflow at 375 px.
- Solution-section asymmetric grid collapses to single column at < 768 px.
- Bullet cards stack at < 768 px with comfortable line-height.
- All horizontal padding from a single CSS var `--gutter: clamp(1rem, 4vw, 2.5rem)` applied to section containers.

**Reduced-motion pass (audit)**
- Walk every component and confirm:
  - `<Reveal>` shows content immediately when reduced-motion is set (already STORY-001-04, re-verify).
  - Hero scroll-indicator pulse is disabled.
  - Any other transitions (hover scale on solution cards, etc.) are also gated by the `@media (prefers-reduced-motion)` block in `global.css`.

**A11y pass (audit)**
- Every interactive element has a visible focus ring (Tailwind's default ring, themed via `--accent` where context permits).
- All images have non-empty `alt` attributes.
- Headings form a sensible outline: `<h1>` (Hero only), `<h2>` (each section), `<h3>` (bullet card titles).
- Color contrast at AA: muted text vs dark bg is at least 4.5:1.

### 1.3 Out of Scope
- Dockerfile and deploy (STORY-001-07).
- A separate "/about" or "/contact" route.
- Cookie banner — no cookies are set.
- Print stylesheet.

## 2. The Truth (Executable Tests)

### 2.1 Acceptance Criteria (Gherkin)

```gherkin
Feature: Common Thread + Footer + Polish

  Scenario: Common Thread renders the five locked rows
    Given the page is loaded
    When the visitor counts the data rows in the Common Thread `<tbody>`
    Then exactly 5 rows exist
    And the first column values in order are "Layer", "Surface", "Knowledge model", "Trust model", "Status"

  Scenario: Footer surfaces all references
    Given the page is loaded
    When the visitor inspects the footer
    Then it contains an `<a>` with href "/ClearGate_AI_Orchestration.pdf"
    And an `<a>` with href "/Tee-Mo_Sovereign_Intelligence.pdf"
    And an `<a>` with href "https://github.com/eugene-burachevskiy/exa-slack-agent"
    And three mailto: links matching the three team emails

  Scenario: Both PDFs are reachable on the deployed bundle
    Given `pnpm build` has run
    When the developer lists /site/dist/
    Then both PDFs exist at /site/dist/ClearGate_AI_Orchestration.pdf and /site/dist/Tee-Mo_Sovereign_Intelligence.pdf

  Scenario: Layout is intact at 375px
    Given the dev server is running
    When the page is rendered at 375x812 viewport
    Then no element produces horizontal scroll on `<body>`
    And all section headings and bullet cards are fully visible without clipping

  Scenario: Reduced motion disables every animation
    Given the OS sets `prefers-reduced-motion: reduce`
    When the page loads and the visitor scrolls to each section
    Then no element is in opacity 0 at any point
    And the hero scroll indicator does not pulse
    And no `transition` style fires on any element

  Scenario: Headings form a valid outline
    Given the page is loaded
    When a screen-reader / Lighthouse audit walks the heading order
    Then exactly one <h1> exists (Hero)
    And every <h3> is preceded by a <h2> in the document order
```

### 2.2 Verification Steps (Manual)
- [ ] Test the page at 375, 414, 768, 1024, 1440 viewport widths in Chrome DevTools.
- [ ] Tab through the entire page from address bar — focus order is logical, no traps.
- [ ] Run Lighthouse mobile — A11y ≥ 95, Best Practices ≥ 95, SEO ≥ 95.
- [ ] Re-run with `prefers-reduced-motion` toggled — visual diff: no transitions at all.

## 3. The Implementation Guide

### 3.1 Context & Files

| Item | Value |
|---|---|
| New Files Needed | Yes |
| Primary File | `/site/src/components/CommonThread.astro` |
| Related Files | `/site/src/components/Footer.astro`, `/site/src/pages/index.astro`, `/site/src/styles/global.css`, `/site/package.json` (prebuild hook) |

### 3.2 Technical Logic
1. The PDF copy step is the only build-time file-system action. Add `"prebuild": "cp ../ClearGate_AI_Orchestration.pdf ../Tee-Mo_Sovereign_Intelligence.pdf public/"` to `package.json` scripts. Add `*.pdf` to `/site/.gitignore` so the copies aren't double-committed inside `/site/public/`.
2. The mobile-fallback table layout is pure CSS — use `display: block` on `table`, `thead`, `tbody`, `tr`, `td` at the breakpoint, then render `<th>` labels as `::before` content via a `data-label` attribute on each `<td>`. Or simpler: render cards at < 640px with markup duplicated. Use whichever ends up cleaner; either is acceptable.
3. The reduced-motion sweep is mostly a re-audit — the bulk of the gating is already in `global.css` from STORY-001-04. New animations introduced in this story (hero pulse, hover scales) get added to the same `@media (prefers-reduced-motion: reduce)` block.

### 3.3 API Contract
N/A.

## 4. Quality Gates

### 4.1 Minimum Test Expectations

| Test Type | Minimum Count | Notes |
|---|---|---|
| Unit tests | 0 | UI is the test |
| E2E / acceptance | 6 | One per Gherkin scenario |
| Lighthouse | 1 | A11y / BestPractices / SEO each ≥ 95 |

### 4.2 Definition of Done (The Gate)
- [ ] All Gherkin scenarios in §2.1 pass.
- [ ] Lighthouse mobile A11y ≥ 95, Best Practices ≥ 95, SEO ≥ 95 (Performance verified separately in STORY-001-07 against the Docker image).
- [ ] No horizontal scroll at any tested viewport.
- [ ] No file outside `/site/src/components/`, `/site/src/pages/index.astro`, `/site/src/styles/global.css`, `/site/package.json`, `/site/.gitignore` is modified.
- [ ] One commit: `feat(site): common thread + footer + responsive/a11y polish`.

---

## ClearGate Ambiguity Gate (🟢 / 🟡 / 🔴)
**Current Status: 🟢 Green — Ready for Execution**
- [x] Gherkin scenarios cover all detailed requirements in §1.2.
- [x] Implementation Guide names exact prebuild hook and CSS strategy.
- [x] Zero "TBDs" in this document.
