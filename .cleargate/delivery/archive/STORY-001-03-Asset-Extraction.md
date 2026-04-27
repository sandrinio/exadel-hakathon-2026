---
story_id: STORY-001-03-Asset-Extraction
parent_epic_ref: EPIC-001
status: Approved
approved: true
approved_by: Sandro Suladze (verbal, recorded in chat 2026-04-27)
approved_at: 2026-04-27T00:00:00Z
ambiguity: 🟢 Green
context_source: PROPOSAL-001-Hackathon-Intro-Page.md
actor: Developer
complexity_label: L2
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
  last_gate_check: 2026-04-27T09:14:14Z
pushed_by: "sandro.suladze@gmail.com"
pushed_at: "2026-04-27T09:15:40.670Z"
last_pulled_by: null
last_pulled_at: null
last_remote_update: null
source: local-authored
last_synced_status: null
last_synced_body_sha: null
stamp_error: no ledger rows for work_item_id STORY-001-03-Asset-Extraction
draft_tokens:
  input: null
  output: null
  cache_creation: null
  cache_read: null
  model: null
  last_stamp: 2026-04-27T09:14:13Z
  sessions: []
---

# STORY-001-03: Asset Extraction & Curation
**Complexity:** L2 — extracts deck slides, copies team photos, sources Exa images, ships an OG card.

## 1. The Spec (The Contract)

### 1.1 User Story
As a Site Visitor, I want every section to show real visuals from the source decks and a polished OG card when the link is shared, so that the site feels deck-grade rather than text-only.

### 1.2 Detailed Requirements
- **ClearGate slides.** Render selected pages of `/ClearGate_AI_Orchestration.pdf` to JPEGs at 150 DPI quality 85, output to `/site/public/assets/cleargate/`. Curated subset (filenames must match exactly):
  - `01-cover.jpg` (page 1)
  - `02-vibe-trap.jpg` (page 2)
  - `03-pipeline.jpg` (page 5)
  - `04-gates.jpg` (page 6)
  - `05-four-agents.jpg` (page 7)
  - `06-karpathy-wiki.jpg` (page 8)
  - `07-vs-vibe.jpg` (page 9)
  - `08-ledger.jpg` (page 12)
- **Tee-Mo slides.** Same process from `/Tee-Mo_Sovereign_Intelligence.pdf` to `/site/public/assets/teemo/`:
  - `01-cover.jpg` (page 1)
  - `02-multiplayer.jpg` (page 2)
  - `03-zero-friction.jpg` (page 3)
  - `04-woven-thread.jpg` (page 4)
  - `05-read-act-automate.jpg` (page 6)
  - `06-rag-vs-router.jpg` (page 7)
  - `07-byok.jpg` (page 9)
  - `08-isolation.jpg` (page 10)
- **Exa images.** Download a curated subset from `https://github.com/eugene-burachevskiy/exa-slack-agent/tree/main/img` via `gh api repos/eugene-burachevskiy/exa-slack-agent/contents/img/<file>` and decode the base64 content. Save to `/site/public/assets/exa/`:
  - `01-header.png` (img/exa-header.png)
  - `02-speak.png` (img/speak-exa.png)
  - `03-pr.png` (img/never-miss-pr.png)
  - `04-digest.png` (img/digest.png)
  - `05-llmwiki.png` (img/llmwiki-carousel.png)
  - `06-arch-main.png` (img/exa-architecture-main.png)
  - `07-arch-scale.png` (img/exa-architecture-at-scale.png)
- **Team photos.** Copy `/team-photos/{christophe,sandro,eugene}.jpg` → `/site/public/assets/team/{christophe,sandro,eugene}.jpg`. **If any source file is missing, exit non-zero with a clear error naming the missing file. No silent fallback to placeholders.**
- **OG card.** Generate `/site/public/assets/og/og-card.png` at 1200×630 px. Implementation choice: simplest path is to build a single `.astro` page or a small Node script that uses `satori` + `@resvg/resvg-js` to render a templated card with the title "Slop-Masters · Code Fest 2026" and the tagline "Three solutions. One thesis." over a dark background with orange/coral accent gradient. **Alternative (simpler still):** hand-author an SVG, convert to PNG via `sharp` or `sips`. Either is acceptable as long as the resulting PNG is committed at the spec'd path and is ≤ 200 KB.
- **Update content.** Patch `/site/src/content/solutions.ts` `visuals` arrays so each solution lists its 7–8 real filenames (relative to `/assets/{slug}/`), in display order.
- **Asset hygiene.** All committed images ≤ 400 KB each (deck slides typically come in ~200 KB at the spec'd quality). If any single file exceeds, re-encode at lower quality before commit.
- **Update update.** Update content layer's `solutions.visuals` arrays to reference the actual filenames listed above.

### 1.3 Out of Scope
- Embedding images in components (STORY-001-04, 05, 06).
- Image lazy-loading wiring (covered when components consume them).
- Dynamic OG cards per section.
- Editing the source PDFs.

## 2. The Truth (Executable Tests)

### 2.1 Acceptance Criteria (Gherkin)

```gherkin
Feature: Asset Extraction & Curation

  Scenario: All curated deck slides exist with the spec'd filenames
    Given the story has run
    When the developer lists /site/public/assets/cleargate/ and /site/public/assets/teemo/
    Then exactly 8 .jpg files exist in each directory matching the filenames in §1.2
    And every file size is between 30 KB and 400 KB

  Scenario: All Exa images are present
    Given the story has run
    When the developer lists /site/public/assets/exa/
    Then exactly 7 .png files exist matching the filenames in §1.2

  Scenario: Team photos are copied
    Given /team-photos/christophe.jpg, sandro.jpg, eugene.jpg all exist
    When the asset-copy step runs
    Then /site/public/assets/team/{christophe,sandro,eugene}.jpg exist
    And each file is byte-identical to its source

  Scenario: Missing team photo halts the pipeline
    Given /team-photos/eugene.jpg does NOT exist
    When the asset-copy step runs
    Then the script exits with status != 0
    And stderr contains "missing" and "eugene.jpg"
    And no file under /site/public/assets/team/ has been created or modified for this run

  Scenario: OG card is committed
    Given the story has run
    When the developer inspects /site/public/assets/og/og-card.png
    Then the file exists
    And its dimensions are 1200x630
    And its size is <= 200 KB

  Scenario: Content layer references real files
    Given STORY-001-03 has run
    When the developer reads /site/src/content/solutions.ts
    Then the cleargate, teemo, and exa entries each have a `visuals` array of >= 5 entries
    And every path in those arrays resolves to an existing file under /site/public/assets/
```

### 2.2 Verification Steps (Manual)
- [ ] Open each generated JPEG/PNG in Preview — image is sharp, no rendering artifacts.
- [ ] OG card visually inspected — title and tagline legible, no clipping.
- [ ] `pnpm build` from `/site/` still passes after the content-layer update.

## 3. The Implementation Guide

### 3.1 Context & Files

| Item | Value |
|---|---|
| New Files Needed | Yes |
| Primary File | `/site/public/assets/og/og-card.png` |
| Related Files | `/site/public/assets/cleargate/*.jpg`, `/site/public/assets/teemo/*.jpg`, `/site/public/assets/exa/*.png`, `/site/public/assets/team/*.jpg`, `/site/src/content/solutions.ts` |

### 3.2 Technical Logic

```bash
# Slide extraction (poppler is already installed on the dev machine)
pdftoppm -r 150 -jpeg -jpegopt quality=85 \
  /Users/ssuladze/Documents/Dev/Hakathon/ClearGate_AI_Orchestration.pdf \
  /tmp/cg
# then map pages to spec'd filenames and `mv` into /site/public/assets/cleargate/

# Exa images via gh
for src in exa-header.png speak-exa.png never-miss-pr.png digest.png \
           llmwiki-carousel.png exa-architecture-main.png exa-architecture-at-scale.png; do
  gh api "repos/eugene-burachevskiy/exa-slack-agent/contents/img/$src" \
    --jq '.content' | base64 -d > "/site/public/assets/exa/<mapped-name>.png"
done

# Team photos
for who in christophe sandro eugene; do
  test -f "/team-photos/$who.jpg" || { echo "missing: $who.jpg" >&2; exit 1; }
  cp "/team-photos/$who.jpg" "/site/public/assets/team/$who.jpg"
done
```

The slide-extraction logic should live in a one-shot script `/site/scripts/extract-assets.sh` (or `.mjs`) so it is re-runnable. Commit the script + the resulting artifacts. Don't gate the prod build on the script — Coolify must NOT need `pdftoppm` to build the container.

### 3.3 API Contract
N/A.

## 4. Quality Gates

### 4.1 Minimum Test Expectations

| Test Type | Minimum Count | Notes |
|---|---|---|
| Unit tests | 0 | Pure file-IO + tooling story |
| Asset existence | 23 | 8 cleargate + 8 teemo + 7 exa + 3 team + 1 OG = 27. Allow ≥ 23 to account for any single dropped slide; spec target is 27. |
| E2E / acceptance | 6 | One per Gherkin scenario in §2.1 |

### 4.2 Definition of Done (The Gate)
- [ ] All Gherkin scenarios in §2.1 pass.
- [ ] `/site/scripts/extract-assets.sh` is idempotent — running twice produces no diff.
- [ ] Total bytes added under `/site/public/assets/` ≤ 8 MB.
- [ ] No file outside `/site/public/assets/`, `/site/src/content/solutions.ts`, and `/site/scripts/` is modified.
- [ ] One commit: `feat(site): extract deck slides + team photos + OG card`.

---

## ClearGate Ambiguity Gate (🟢 / 🟡 / 🔴)
**Current Status: 🟢 Green — Ready for Execution**
- [x] Gherkin scenarios cover all detailed requirements in §1.2.
- [x] Implementation Guide names exact tools and paths.
- [x] Zero "TBDs" in this document.
