---
story_id: STORY-001-02-Typed-Content-Layer
parent_epic_ref: EPIC-001
status: Approved
approved: true
approved_by: Sandro Suladze (verbal, recorded in chat 2026-04-27)
approved_at: 2026-04-27T00:00:00Z
ambiguity: 🟢 Green
context_source: PROPOSAL-001-Hackathon-Intro-Page.md
actor: Developer
complexity_label: L1
parallel_eligible: y
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
  last_gate_check: 2026-04-27T09:14:03Z
pushed_by: "sandro.suladze@gmail.com"
pushed_at: "2026-04-27T09:15:30.893Z"
last_pulled_by: null
last_pulled_at: null
last_remote_update: null
source: local-authored
last_synced_status: null
last_synced_body_sha: null
stamp_error: no ledger rows for work_item_id STORY-001-02-Typed-Content-Layer
draft_tokens:
  input: null
  output: null
  cache_creation: null
  cache_read: null
  model: null
  last_stamp: 2026-04-27T09:14:03Z
  sessions: []
---

# STORY-001-02: Typed Content Layer
**Complexity:** L1 — three TypeScript content modules with strict types. No rendering.

## 1. The Spec (The Contract)

### 1.1 User Story
As a Developer, I want all marketing copy isolated in three typed TS files (`team.ts`, `solutions.ts`, `thread.ts`), so that components in later stories import structured data instead of carrying inline strings.

### 1.2 Detailed Requirements
- Create `/site/src/content/team.ts` exporting:
  - `type TeamMember = { name: string; email: string; photo: string; }` where `photo` is a path under `/assets/team/`.
  - `export const team: readonly TeamMember[]` with three entries (Christophe Domingos, Sandro Suladze, Eugene Burachevskiy) using emails from EPIC-001 §1 and the README, photos at `/assets/team/{christophe,sandro,eugene}.jpg`.
  - `export const collaboration: { paragraph: string }` — a tight ≤80-word honest placeholder paragraph (per EPIC §6 Q4). The placeholder text must be: *"We worked as a single team across all three solutions — no per-product owners. We split daily into pair-and-rotate sessions, met morning and evening to compare notes, and kept one shared thesis pinned: AI is only as good as the structure you give it. Each solution is a different altitude on that idea. Anyone could (and did) commit to any of the three."*
- Create `/site/src/content/solutions.ts` exporting:
  - `type Solution = { id: "cleargate" | "teemo" | "exa"; name: string; tagline: string; pitch: string; bullets: { title: string; body: string }[]; visuals: string[]; accent: "cleargate" | "teemo" | "exa"; cta?: { label: string; href: string } }`.
  - `export const solutions: readonly Solution[]` — three entries, content drawn verbatim from the v0 `/README.md` solution sections (paraphrasing only when needed for tighter UI fit). Bullet count: 5–6 per solution. `visuals` lists relative paths under `/assets/{cleargate,teemo,exa}/` — exact filenames slot in during STORY-001-03.
  - The Exa entry has `cta: { label: "View on GitHub", href: "https://github.com/eugene-burachevskiy/exa-slack-agent" }`.
- Create `/site/src/content/thread.ts` exporting:
  - `type ThreadRow = { axis: string; cleargate: string; teemo: string; exa: string }`.
  - `export const thread: readonly ThreadRow[]` — five rows verbatim from `/README.md` "The Common Thread" table: Layer, Surface, Knowledge model, Trust model, Status.
- All three files have **no runtime imports** beyond `type` exports — they are pure data.
- Run `pnpm exec tsc --noEmit` (or `astro check` if Astro provides it) and pass with zero errors.

### 1.3 Out of Scope
- Any Astro component that renders this data (STORY-001-04, 05, 06).
- Image files themselves (STORY-001-03).
- A CMS, MDX, or i18n abstraction.

## 2. The Truth (Executable Tests)

### 2.1 Acceptance Criteria (Gherkin)

```gherkin
Feature: Typed Content Layer

  Scenario: Type-check passes
    Given /site/src/content/{team,solutions,thread}.ts exist
    When the developer runs `pnpm exec astro check` (or `tsc --noEmit`)
    Then exit code is 0
    And no type errors are reported in /site/src/content/

  Scenario: Team data is complete and consistent
    Given /site/src/content/team.ts is loaded
    When the `team` array is read
    Then it has exactly 3 entries
    And each entry has a non-empty name, email, and photo path under "/assets/team/"
    And the three names are exactly "Christophe Domingos", "Sandro Suladze", "Eugene Burachevskiy"

  Scenario: Solutions data is complete
    Given /site/src/content/solutions.ts is loaded
    When the `solutions` array is read
    Then it has exactly 3 entries with ids "cleargate", "teemo", "exa"
    And each entry has 5 or 6 bullets
    And the "exa" entry has a cta pointing at https://github.com/eugene-burachevskiy/exa-slack-agent

  Scenario: Thread table has the five locked rows
    Given /site/src/content/thread.ts is loaded
    When the `thread` array is read
    Then it has exactly 5 entries
    And the `axis` values in order are: "Layer", "Surface", "Knowledge model", "Trust model", "Status"
```

### 2.2 Verification Steps (Manual)
- [ ] Open each file in an editor — types resolve, no red squiggles.
- [ ] `pnpm exec astro check` exits 0.
- [ ] Eyeball the collaboration paragraph length: ≤80 words.

## 3. The Implementation Guide

### 3.1 Context & Files

| Item | Value |
|---|---|
| New Files Needed | Yes |
| Primary File | `/site/src/content/solutions.ts` |
| Related Files | `/site/src/content/team.ts`, `/site/src/content/thread.ts` |

### 3.2 Technical Logic
1. Each content file exports a single `as const` array typed against the module's exported type. Use `satisfies readonly Foo[]` if helpful.
2. Source of marketing copy: `/README.md` at the repo root (the v0 intro page). Paraphrase only when needed to fit a bullet shape. Do NOT invent new claims.
3. The collaboration paragraph is locked text — copy it verbatim from §1.2 above.
4. `visuals: string[]` for each solution should be an empty array initially OR list the planned filenames; STORY-001-03 fills them with real files. Either way, components in later stories should tolerate an empty list (render no slides, show only bullets) — defensive design.

### 3.3 API Contract
N/A.

## 4. Quality Gates

### 4.1 Minimum Test Expectations

| Test Type | Minimum Count | Notes |
|---|---|---|
| Unit tests | 0 | Pure data; type system is the test |
| Type-check | 1 | `astro check` / `tsc --noEmit` exits 0 |
| E2E / acceptance | 4 | One per Gherkin scenario in §2.1 |

### 4.2 Definition of Done (The Gate)
- [ ] All Gherkin scenarios in §2.1 pass.
- [ ] `pnpm exec astro check` exits 0.
- [ ] No file outside `/site/src/content/` is modified.
- [ ] One commit: `feat(site): typed content layer for team/solutions/thread`.

---

## ClearGate Ambiguity Gate (🟢 / 🟡 / 🔴)
**Current Status: 🟢 Green — Ready for Execution**
- [x] Gherkin scenarios cover all detailed requirements in §1.2.
- [x] Implementation Guide maps to specific file paths.
- [x] Zero "TBDs" in this document.
