---
story_id: STORY-001-05-Solution-Sections
parent_epic_ref: EPIC-001
status: Approved
approved: true
approved_by: Sandro Suladze (verbal, recorded in chat 2026-04-27)
approved_at: 2026-04-27T00:00:00Z
ambiguity: 🟢 Green
context_source: PROPOSAL-001-Hackathon-Intro-Page.md
actor: Site Visitor
complexity_label: L3
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
  last_gate_check: 2026-04-27T09:14:32Z
pushed_by: "sandro.suladze@gmail.com"
pushed_at: "2026-04-27T09:15:59.110Z"
last_pulled_by: null
last_pulled_at: null
last_remote_update: null
source: local-authored
last_synced_status: null
last_synced_body_sha: null
stamp_error: no ledger rows for work_item_id STORY-001-05-Solution-Sections
draft_tokens:
  input: null
  output: null
  cache_creation: null
  cache_read: null
  model: null
  last_stamp: 2026-04-27T09:14:31Z
  sessions: []
---

# STORY-001-05: Three Solution Sections (ClearGate, Tee-Mo, Exa)
**Complexity:** L3 — three full-width sections with shared layout primitives, per-solution accent theming, and embedded deck visuals.

## 1. The Spec (The Contract)

### 1.1 User Story
As a Site Visitor scrolling past the team and collaboration intro, I want each of the three solutions presented in its own visually distinct section — with its deck's accent color, real slide imagery, a tight feature grid, and a clear next step (PDF or repo) — so that I can grasp all three at a glance and dig into the one I care about.

### 1.2 Detailed Requirements

**Shared section primitive (inline, not a separate file)**
Each solution component (`SolutionClearGate.astro`, `SolutionTeeMo.astro`, `SolutionExa.astro`) is a thin shell that imports its solution entry from `/site/src/content/solutions.ts` and renders the same internal structure:

```
<section data-section="solution-{id}" data-accent="{accent}">
  <header>
    <p class="eyebrow">Solution {n} of 3</p>
    <h2>{name}</h2>
    <p class="tagline">{tagline}</p>
  </header>
  <div class="pitch">{pitch — 1 paragraph}</div>
  <ul class="bullets">{bullets — 5–6 cards, each title + body}</ul>
  <figure class="visuals">{visuals — 3–6 embedded images, asymmetric grid}</figure>
  {cta if present — link button}
</section>
```

**Per-solution accent theming**
- Each section sets `data-accent="cleargate" | "teemo" | "exa"` on its `<section>` root.
- `global.css` defines:
  ```css
  [data-accent="cleargate"] { --accent: var(--color-accent-cleargate); }
  [data-accent="teemo"]     { --accent: var(--color-accent-teemo); }
  [data-accent="exa"]       { --accent: var(--color-accent-exa); }
  ```
- The eyebrow, the bullet-card title underline, the visuals figure caption, and the CTA button all use `color: var(--accent)` or `border-color: var(--accent)`.
- The section background gets a faint accent-tinted gradient (e.g. `radial-gradient(at top right, color-mix(in srgb, var(--accent) 8%, transparent), transparent 60%)`).

**Bullet grid**
- 2-column grid on desktop (`md:grid-cols-2 gap-6`), single column on mobile.
- Each card: `<article>` with `border border-white/10 rounded-xl p-6 bg-white/[0.02]`.
- Title: `text-base font-semibold` with a 2px accent underline below.
- Body: `text-sm text-muted leading-relaxed`.

**Visuals layout**
- Asymmetric grid using CSS Grid `grid-template-columns: 2fr 1fr 1fr` on desktop. First image spans 2 rows; remaining images flow into the smaller cells.
- Minimum 3, target 5–6 visuals per solution. Component reads `solution.visuals[]` and renders all entries; if the array is shorter than 3, fall back to a single full-width image.
- Each `<img>` uses `loading="lazy"`, `decoding="async"`, explicit `width`/`height`, and `alt` derived from the slide filename (e.g. `cleargate · pipeline`).
- Images sit on a subtle inner shadow / 1px ring (`ring-1 ring-white/10 rounded-lg overflow-hidden shadow-2xl`).

**CTA**
- Only the Exa entry has a `cta`. Render as a button-styled anchor: `inline-flex` with lucide `external-link` icon (inlined SVG), accent text color, accent border on hover.

**Reveal**
- Wrap each `<section>`'s `<header>`, the bullets `<ul>`, and the visuals `<figure>` separately in `<Reveal>` so they fade in as the visitor scrolls into each.

**Composition**
- Append `<SolutionClearGate />`, `<SolutionTeeMo />`, `<SolutionExa />` to `index.astro`'s `<main>`, after `<Collaboration />`.

### 1.3 Out of Scope
- Common Thread comparison table (STORY-001-06).
- Footer (STORY-001-06).
- Per-solution detail pages — single-page only.
- Light-mode variants of any visual.

## 2. The Truth (Executable Tests)

### 2.1 Acceptance Criteria (Gherkin)

```gherkin
Feature: Three Solution Sections

  Scenario: All three sections render in the spec'd order
    Given the page is loaded
    When the visitor inspects `<main>`
    Then a section with data-section="solution-cleargate" appears first among the solution sections
    And it is followed by data-section="solution-teemo"
    And then data-section="solution-exa"

  Scenario: Each section uses its own accent color
    Given the page is loaded
    When the visitor inspects each section's CSS custom properties
    Then [data-accent="cleargate"] has --accent equal to #ea580c
    And [data-accent="teemo"] has --accent equal to #fb7185
    And [data-accent="exa"] has --accent equal to #00d563

  Scenario: Each section renders 5 or 6 bullet cards
    Given the page is loaded
    When the visitor counts `.bullets > article` inside each solution section
    Then the count is between 5 and 6 inclusive

  Scenario: Each section embeds at least 3 deck visuals
    Given the page is loaded
    When the visitor counts `<img>` elements inside `.visuals` for each solution
    Then the count is >= 3
    And every `src` resolves under /assets/{cleargate|teemo|exa}/ matching the section's id

  Scenario: Exa section exposes the GitHub CTA
    Given the page is loaded
    When the visitor inspects the Exa section
    Then it contains an `<a>` with href "https://github.com/eugene-burachevskiy/exa-slack-agent"
    And the anchor has a visible label containing "GitHub"

  Scenario: Reveal animations run on scroll for each subsection
    Given default motion preferences
    When the visitor scrolls a section's header into view (intersection >= 0.1)
    Then the header element gains "reveal-in"
    And the same observer behavior applies independently to the bullets and visuals subgroups
```

### 2.2 Verification Steps (Manual)
- [ ] Visual scan of all three sections at desktop and 375px mobile widths.
- [ ] Confirm asymmetric image grid does not produce overflow / horizontal scroll on mobile.
- [ ] Hover the Exa CTA — focus ring visible, opens in a new tab (`target="_blank" rel="noopener"`).
- [ ] Tab through each section — focus order is logical, no traps.

## 3. The Implementation Guide

### 3.1 Context & Files

| Item | Value |
|---|---|
| New Files Needed | Yes |
| Primary File | `/site/src/components/SolutionClearGate.astro` |
| Related Files | `/site/src/components/SolutionTeeMo.astro`, `/site/src/components/SolutionExa.astro`, `/site/src/pages/index.astro`, `/site/src/styles/global.css` |

### 3.2 Technical Logic
1. The three solution components are intentionally near-duplicates of one shell. To keep things DRY without inventing abstractions, factor the shell into a private `<SolutionSection>` Astro component file (`/site/src/components/_SolutionSection.astro` — leading underscore indicates internal). The three public files just import `_SolutionSection` and pass the right `solution` prop. Only do this if the three components actually share ≥ 80% of their markup; if any one diverges meaningfully, keep them flat.
2. Read solution data via `import { solutions } from "../content/solutions.ts"; const cg = solutions.find(s => s.id === "cleargate");` — fail loudly (Astro frontmatter `throw`) if the entry is missing.
3. The asymmetric grid is plain CSS Grid; no JS, no library.
4. Inline lucide SVGs — paste the `<svg>` directly. Never `import { ExternalLink } from "lucide-react"` — there is no React.

### 3.3 API Contract
N/A.

## 4. Quality Gates

### 4.1 Minimum Test Expectations

| Test Type | Minimum Count | Notes |
|---|---|---|
| Unit tests | 0 | UI is the test |
| E2E / acceptance | 6 | One per Gherkin scenario |
| Build | 1 | `pnpm build` passes; first-load JS still ≤ 5 KB |

### 4.2 Definition of Done (The Gate)
- [ ] All Gherkin scenarios in §2.1 pass.
- [ ] No horizontal scroll at 375px width on any section.
- [ ] All images use lazy loading and explicit dimensions; CLS ≤ 0.05 across the three sections.
- [ ] No file outside `/site/src/components/`, `/site/src/pages/index.astro`, `/site/src/styles/global.css` is modified.
- [ ] One commit: `feat(site): three solution sections with accent theming and deck visuals`.

---

## ClearGate Ambiguity Gate (🟢 / 🟡 / 🔴)
**Current Status: 🟢 Green — Ready for Execution**
- [x] Gherkin scenarios cover all detailed requirements in §1.2.
- [x] Implementation Guide gives concrete grid + theming snippets.
- [x] Zero "TBDs" in this document.
