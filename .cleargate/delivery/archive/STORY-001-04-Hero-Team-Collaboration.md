---
story_id: STORY-001-04-Hero-Team-Collaboration
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
  last_gate_check: 2026-04-27T09:14:23Z
pushed_by: "sandro.suladze@gmail.com"
pushed_at: "2026-04-27T09:15:50.250Z"
last_pulled_by: null
last_pulled_at: null
last_remote_update: null
source: local-authored
last_synced_status: null
last_synced_body_sha: null
stamp_error: no ledger rows for work_item_id STORY-001-04-Hero-Team-Collaboration
draft_tokens:
  input: null
  output: null
  cache_creation: null
  cache_read: null
  model: null
  last_stamp: 2026-04-27T09:14:22Z
  sessions: []
---

# STORY-001-04: Hero + Team + Collaboration Sections + Reveal Wrapper
**Complexity:** L2 — three sections + the IntersectionObserver scroll-reveal wrapper used by every later section.

## 1. The Spec (The Contract)

### 1.1 User Story
As a Site Visitor landing at hakathon2026.soula.ge, I want a striking hero, a team section with three real headshots, and a short collaboration paragraph — each smoothly revealing as I scroll — so that within five seconds I know who the team is and what we built.

### 1.2 Detailed Requirements

**Reveal.astro (shared)**
- A wrapper component used as `<Reveal><div>...</div></Reveal>`.
- Adds class `reveal-init` (opacity 0, translate-y-4) on the immediate child element.
- Ships ~25 lines of inline `<script>` (vanilla, not a module) that creates one `IntersectionObserver` shared across all `.reveal-init` nodes; on intersection ratio ≥ 0.1 add class `reveal-in` (opacity 1, translate-y-0) and unobserve.
- Total inline JS for the page must remain ≤ 5 KB after build (per EPIC §3 constraint).
- Wrap the whole script body in `if (!matchMedia('(prefers-reduced-motion: reduce)').matches)`. If reduced-motion is set, skip the observer entirely AND apply `.reveal-in` immediately on DOMContentLoaded so content is visible without animation (per EPIC §6 Q2 & Q5).
- Transition: `transition: opacity 600ms ease, transform 600ms ease;` on `.reveal-init`.

**Hero.astro**
- Full-viewport (`min-h-screen`) section with vertically centered content.
- H1: "Slop-Masters" (Geist Sans 600, large display size, e.g. ~10rem on desktop / 4rem on mobile).
- Eyebrow above H1: "Exadel Code Fest 2026" in mono, muted.
- Subheadline: "Three solutions. One thesis: AI is only as good as the structure you give it." (~1.5rem on desktop).
- Background: subtle radial gradient using the three accent tokens (orange/coral/green) at low opacity over the dark base — hand-tuned, no library.
- Scroll-down indicator at bottom (chevron-down lucide SVG inlined) that pulses via `@keyframes` (skipped when reduced-motion).
- Wrapped in `<Reveal>`.

**Team.astro**
- Section heading: "The Team" (sticks left, deck-style typography).
- Three cards laid out in a CSS Grid (`grid-cols-1 md:grid-cols-3 gap-8`). Order: Christophe, Sandro, Eugene.
- Each card: square photo (`aspect-square`, `rounded-2xl`, `object-cover`) loaded from `member.photo` with `loading="lazy"`, `decoding="async"`, `width="512" height="512"`; below it the member's name (`text-xl font-semibold`) and a `mailto:` link with the member's email (`font-mono text-sm text-muted hover:text-fg`).
- Each card wrapped in `<Reveal>`.
- Imports `team` from `/site/src/content/team.ts`.

**Collaboration.astro**
- Section heading: "How We Collaborated".
- Single column max-w-3xl. Renders `collaboration.paragraph` from `/site/src/content/team.ts` as a generously sized prose block (`text-xl leading-relaxed`).
- Pull-quote treatment for the last sentence: italic, larger, accent-orange left border (`border-l-4 border-accent-cleargate pl-6`).
- Wrapped in `<Reveal>`.

**Composition**
- `/site/src/pages/index.astro` imports `Hero`, `Team`, `Collaboration` from `/site/src/components/`, replaces the placeholder `<main>` from STORY-001-01 with `<main><Hero /><Team /><Collaboration /></main>`. Solution sections + footer slot in via STORY-005/006.

### 1.3 Out of Scope
- The three solution sections (STORY-001-05).
- Common Thread, Footer, mobile polish (STORY-001-06).
- Theme switcher.
- A separate "About" page.

## 2. The Truth (Executable Tests)

### 2.1 Acceptance Criteria (Gherkin)

```gherkin
Feature: Hero + Team + Collaboration

  Scenario: All three sections render in order
    Given the page is loaded
    When the visitor inspects the DOM
    Then `<main>` contains <section data-section="hero">, <section data-section="team">, <section data-section="collaboration"> in that order

  Scenario: Hero shows team name and tagline
    Given the page is loaded
    When the visitor reads the hero
    Then the H1 text is exactly "Slop-Masters"
    And the eyebrow text contains "Exadel Code Fest 2026"
    And a paragraph contains "Three solutions. One thesis"

  Scenario: Team section renders three cards with real photos
    Given the page is loaded
    When the visitor scrolls to the Team section
    Then exactly three `<img>` elements are present with src starting "/assets/team/"
    And the alt attribute on each img is the member's name
    And each card contains an `<a>` whose href starts with "mailto:" and ends with "@exadel.com"

  Scenario: Collaboration paragraph is rendered verbatim
    Given the page is loaded
    When the visitor reads the Collaboration section
    Then the rendered text matches `collaboration.paragraph` from /site/src/content/team.ts

  Scenario: Scroll reveal fires for elements entering the viewport
    Given the page is loaded with default motion preferences
    When a `<Reveal>`-wrapped element scrolls into view (intersection >= 0.1)
    Then the element gains the class "reveal-in"
    And the same observer does not re-fire after the class is added (unobserve)

  Scenario: Reduced motion bypasses the observer
    Given the OS sets `prefers-reduced-motion: reduce`
    When the page loads
    Then every `<Reveal>`-wrapped element has class "reveal-in" applied immediately
    And no IntersectionObserver instance is created
```

### 2.2 Verification Steps (Manual)
- [ ] `pnpm dev`, open at desktop width — sections fade-up as you scroll.
- [ ] DevTools → Rendering → Emulate `prefers-reduced-motion: reduce`. Reload — all sections appear instantly, no animation.
- [ ] Network tab: each photo loads, all 200, served from `/_astro/` or `/assets/team/`.
- [ ] Run `pnpm build` then inspect `/site/dist/_astro/`: total JS payload ≤ 5 KB.

## 3. The Implementation Guide

### 3.1 Context & Files

| Item | Value |
|---|---|
| New Files Needed | Yes |
| Primary File | `/site/src/components/Hero.astro` |
| Related Files | `/site/src/components/Team.astro`, `/site/src/components/Collaboration.astro`, `/site/src/components/Reveal.astro`, `/site/src/pages/index.astro`, `/site/src/styles/global.css` |

### 3.2 Technical Logic
1. `<Reveal>` is implemented as a single `.astro` component with a `<slot />` and an inline `<script is:inline>` block. Use `is:inline` so Astro doesn't bundle it as a module — keeps the JS tiny and cache-stable.
2. Single shared observer pattern:
   ```js
   const obs = new IntersectionObserver((entries) => {
     for (const e of entries) {
       if (e.isIntersecting) { e.target.classList.add('reveal-in'); obs.unobserve(e.target); }
     }
   }, { threshold: 0.1 });
   document.querySelectorAll('.reveal-init').forEach((n) => obs.observe(n));
   ```
3. CSS in `global.css`:
   ```css
   .reveal-init { opacity: 0; transform: translateY(1rem); transition: opacity 600ms ease, transform 600ms ease; }
   .reveal-in { opacity: 1; transform: none; }
   @media (prefers-reduced-motion: reduce) {
     .reveal-init { opacity: 1; transform: none; transition: none; }
   }
   ```
4. Images in `Team.astro` use plain `<img>` (not Astro's `<Image>`) — keeps the build simple and the assets are already sized correctly. Set explicit `width`/`height` to avoid CLS.
5. Hero gradient is hand-authored in `global.css` as a `radial-gradient(...)` background applied to the section, NOT an SVG file.

### 3.3 API Contract
N/A.

## 4. Quality Gates

### 4.1 Minimum Test Expectations

| Test Type | Minimum Count | Notes |
|---|---|---|
| Unit tests | 0 | UI is the test |
| E2E / acceptance | 6 | One per Gherkin scenario |
| Build | 1 | `pnpm build` passes; total JS ≤ 5 KB |

### 4.2 Definition of Done (The Gate)
- [ ] All Gherkin scenarios in §2.1 pass.
- [ ] Lighthouse CLS for the hero ≤ 0.05 (no layout shift on load).
- [ ] `prefers-reduced-motion` honored and verified by manual emulation.
- [ ] No file outside `/site/src/components/`, `/site/src/pages/index.astro`, `/site/src/styles/global.css` is modified.
- [ ] One commit: `feat(site): hero + team + collaboration sections with scroll reveal`.

---

## ClearGate Ambiguity Gate (🟢 / 🟡 / 🔴)
**Current Status: 🟢 Green — Ready for Execution**
- [x] Gherkin scenarios cover all detailed requirements in §1.2.
- [x] Implementation Guide includes the exact JS pattern and CSS tokens.
- [x] Zero "TBDs" in this document.
