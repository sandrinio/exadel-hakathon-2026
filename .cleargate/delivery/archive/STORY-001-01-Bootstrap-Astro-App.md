---
story_id: STORY-001-01-Bootstrap-Astro-App
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
  last_gate_check: 2026-04-27T09:13:51Z
pushed_by: "sandro.suladze@gmail.com"
pushed_at: "2026-04-27T09:15:21.870Z"
last_pulled_by: null
last_pulled_at: null
last_remote_update: null
source: local-authored
last_synced_status: null
last_synced_body_sha: null
stamp_error: no ledger rows for work_item_id STORY-001-01-Bootstrap-Astro-App
draft_tokens:
  input: null
  output: null
  cache_creation: null
  cache_read: null
  model: null
  last_stamp: 2026-04-27T09:13:50Z
  sessions: []
---

# STORY-001-01: Bootstrap Astro App + Tailwind v4 + Base Layout
**Complexity:** L2 — scaffolds the Astro app, wires Tailwind v4, sets theme tokens, ships an empty index page that builds clean.

## 1. The Spec (The Contract)

### 1.1 User Story
As a Developer, I want a clean Astro 5 + Tailwind v4 + TypeScript-strict project under `/site/` with the dark theme tokens and self-hosted Geist fonts already wired, so that subsequent stories can drop in components without any setup churn.

### 1.2 Detailed Requirements
- Run `pnpm create astro@latest site/` with `--template minimal --typescript strict --no-git --no-install`. Then `cd site && pnpm install`.
- Add Tailwind v4 via the official Vite plugin: `pnpm add -D tailwindcss @tailwindcss/vite`. Wire it in `astro.config.mjs` via `vite: { plugins: [tailwindcss()] }`.
- Add `@import "tailwindcss";` at the top of `src/styles/global.css`. Define theme tokens in `@theme { ... }`: dark surface (`--color-bg: #0a0a0b`), foreground (`--color-fg: #f5f5f4`), muted (`--color-muted: #a1a1aa`), and three accent tokens — `--color-accent-cleargate: #ea580c` (deck orange), `--color-accent-teemo: #fb7185` (deck coral), `--color-accent-exa: #00d563` (Exa green from README badge).
- Configure `astro.config.mjs` with `output: "static"` and `site: "https://hakathon2026.soula.ge"`.
- Self-host Geist Sans + Geist Mono via `@fontsource/geist-sans` and `@fontsource/geist-mono`. Import in `Base.astro`. Default body font is Geist Sans; `font-mono` Tailwind utility maps to Geist Mono.
- `src/layouts/Base.astro` ships with `<html lang="en" class="dark">`, full meta tags (title, description, OG, Twitter card pointing to `/assets/og/og-card.png` — the file itself ships in STORY-003), Tailwind reset, dark `<body>` background, and a `<slot />`.
- `src/pages/index.astro` ships with the layout wrapper + a single placeholder `<main>` containing the heading "Slop-Masters @ Code Fest 2026". Subsequent stories replace the `<main>` body.
- Add `.prettierrc` with `{ "semi": true, "singleQuote": false, "plugins": ["prettier-plugin-astro"] }` and `pnpm add -D prettier prettier-plugin-astro`.
- Add `package.json` scripts: `dev`, `build`, `preview`, `format` (`prettier --write .`), `format:check` (`prettier --check .`).
- `.gitignore` includes `node_modules`, `dist`, `.astro`. `/site/` is committed to the same repo (no submodule).

### 1.3 Out of Scope
- All marketing copy, components, assets, sections (covered by STORY-001-02 through 001-06).
- Dockerfile and nginx config (STORY-001-07).
- shadcn/ui, React, Framer Motion, ESLint — explicitly excluded by EPIC-001 §0.

## 2. The Truth (Executable Tests)

### 2.1 Acceptance Criteria (Gherkin)

```gherkin
Feature: Bootstrap Astro App

  Scenario: Dependencies install cleanly
    Given the developer is at /site/
    When they run `pnpm install`
    Then exit code is 0
    And node_modules/ contains astro, @tailwindcss/vite, @fontsource/geist-sans, @fontsource/geist-mono, prettier, prettier-plugin-astro

  Scenario: Dev server starts and renders the placeholder page
    Given dependencies are installed
    When the developer runs `pnpm dev`
    Then the dev server listens on http://localhost:4321
    And `curl -s http://localhost:4321/` returns HTML containing "Slop-Masters @ Code Fest 2026"
    And no console errors are emitted in the terminal

  Scenario: Production build succeeds and outputs static HTML
    Given dependencies are installed
    When the developer runs `pnpm build`
    Then exit code is 0
    And `/site/dist/index.html` exists
    And `/site/dist/_astro/` contains a hashed CSS bundle that includes the dark theme tokens
    And no Node runtime files (`server.mjs`, etc.) are present in `/site/dist/`

  Scenario: Theme tokens are accessible via Tailwind utilities
    Given the production build has run
    When the developer inspects the generated CSS in `/site/dist/_astro/*.css`
    Then it contains the variables `--color-accent-cleargate`, `--color-accent-teemo`, `--color-accent-exa` with the spec'd hex values

  Scenario: Prettier check passes on the bootstrapped tree
    Given dependencies are installed
    When the developer runs `pnpm format:check`
    Then exit code is 0
```

### 2.2 Verification Steps (Manual)
- [ ] `pnpm install && pnpm dev` from `/site/` — page renders, no errors.
- [ ] `pnpm build` produces `/site/dist/index.html` with dark background visible when previewed via `pnpm preview`.
- [ ] DevTools shows `font-family: Geist` on `<body>` and the three accent CSS vars in the inspector.

## 3. The Implementation Guide

### 3.1 Context & Files

| Item | Value |
|---|---|
| New Files Needed | Yes |
| Primary File | `/site/astro.config.mjs` |
| Related Files | `/site/package.json`, `/site/tsconfig.json`, `/site/.prettierrc`, `/site/.gitignore`, `/site/src/styles/global.css`, `/site/src/layouts/Base.astro`, `/site/src/pages/index.astro` |

### 3.2 Technical Logic
1. Use the Astro `minimal` template, not the default — the default ships extra demo content we don't want.
2. Tailwind v4 is configured purely via `@import "tailwindcss"` + `@theme { ... }` in CSS. There is **no** `tailwind.config.ts` in v4.
3. The `<html>` element gets a static `dark` class (no theme switcher, per EPIC §0 rule on hard-coded dark).
4. Geist fonts: import `@fontsource/geist-sans/400.css`, `/500.css`, `/600.css`, `/700.css` and `@fontsource/geist-mono/400.css` in `Base.astro`. Set `--font-sans: "Geist Sans", ui-sans-serif, system-ui, sans-serif;` and `--font-mono: "Geist Mono", ui-monospace, monospace;` in `@theme`.
5. The placeholder `<main>` is intentionally minimal — its only job is to prove the layout/font/theme pipeline works end-to-end.

### 3.3 API Contract
N/A — no APIs.

## 4. Quality Gates

### 4.1 Minimum Test Expectations

| Test Type | Minimum Count | Notes |
|---|---|---|
| Unit tests | 0 | No business logic to test in this story |
| E2E / acceptance | 5 | One per Gherkin scenario in §2.1, executed manually + via the verification block in §2.2 |
| Build/CI | 1 | `pnpm build` must succeed with exit code 0 |

### 4.2 Definition of Done (The Gate)
- [ ] All Gherkin scenarios in §2.1 pass.
- [ ] `pnpm build && pnpm preview` shows a dark page with the placeholder heading.
- [ ] `pnpm format:check` exits 0.
- [ ] No files outside `/site/` are created or modified.
- [ ] One commit on the story's branch with conventional message `feat(site): bootstrap astro+tailwind app`.

---

## ClearGate Ambiguity Gate (🟢 / 🟡 / 🔴)
**Current Status: 🟢 Green — Ready for Execution**
- [x] Gherkin scenarios cover all detailed requirements in §1.2.
- [x] Implementation Guide maps to specific, verified file paths from EPIC-001 §4.
- [x] Zero "TBDs" in this document.
