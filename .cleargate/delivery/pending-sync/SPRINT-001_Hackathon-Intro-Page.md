---
sprint_id: "SPRINT-001"
remote_id: null
source_tool: "local"
status: "Draft"
execution_mode: "v1"
start_date: "2026-04-27"
end_date: "2026-05-04"
synced_at: null
created_at: "2026-04-27T00:00:00Z"
updated_at: "2026-04-27T00:00:00Z"
created_at_version: "v1"
updated_at_version: "v1"
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
---

# SPRINT-001: Hackathon Intro Page

## Sprint Goal
Ship the deployed Slop-Masters hackathon showcase as a sleek static site at `https://hakathon2026.soula.ge`, packaged for Coolify auto-deploy on push to `main`.

## 1. Consolidated Deliverables

*(Locally authored — `remote_id: null` because the ClearGate MCP server is currently disconnected. When it reconnects, this sprint and its 7 stories can be pushed via `cleargate_push_item`. IDs below are local IDs.)*

| Story ID | Title | Lane | Milestone | Parallel? | Bounce Exposure |
|---|---|---|---|---|---|
| `STORY-001-01-Bootstrap-Astro-App` | Bootstrap Astro app + Tailwind v4 + base layout + theme tokens | standard | M1 | n | low |
| `STORY-001-02-Typed-Content-Layer` | Typed content layer (`team.ts`, `solutions.ts`, `thread.ts`) | standard | M1 | y | low |
| `STORY-001-03-Asset-Extraction` | Asset extraction & curation (deck slides + team photos + OG card) | standard | M1 | y | low |
| `STORY-001-04-Hero-Team-Collaboration` | Hero + Team + Collaboration sections + `Reveal.astro` | standard | M1 | n | med |
| `STORY-001-05-Solution-Sections` | Three solution sections with per-solution accent theming | standard | M1 | n | med |
| `STORY-001-06-Common-Thread-Footer-Polish` | Common Thread + Footer + mobile polish + reduced-motion path | standard | M1 | n | low |
| `STORY-001-07-Dockerfile-and-Coolify` | Dockerfile + nginx.conf + smoke test + README live-site link | standard | M1 | n | med |

## 2. Execution Strategy

### 2.1 Phase Plan

```
Wave 1  (sequential, foundation):  STORY-001-01
                                       │
Wave 2  (parallel):                STORY-001-02 ‖ STORY-001-03
                                       │
Wave 3  (sequential):              STORY-001-04   ← consumes 02 + 03 outputs
                                       │
Wave 4  (sequential):              STORY-001-05   ← reuses Reveal from 04
                                       │
Wave 5  (sequential):              STORY-001-06   ← page-wide a11y/responsive sweep
                                       │
Wave 6  (sequential):              STORY-001-07   ← packages everything for Coolify
```

Critical path length: 6 waves. Only Wave 2 admits parallelism (content authoring vs asset pipeline don't share files).

### 2.2 Merge Ordering (Shared-File Surface Analysis)

| Shared File | Stories Touching It | Merge Order | Rationale |
|---|---|---|---|
| `/site/src/styles/global.css` | 01, 04, 05, 06 | 01 → 04 → 05 → 06 | 01 ships theme tokens; 04 adds reveal classes; 05 adds per-accent rules; 06 adds responsive utilities + reduced-motion sweep. Each story APPENDs; no rewrites of prior blocks. |
| `/site/src/pages/index.astro` | 01, 04, 05, 06 | 01 → 04 → 05 → 06 | 01 ships placeholder `<main>`. 04 replaces it with three sections. 05 appends three more. 06 appends two more (CommonThread, Footer). Diff per story is strictly additive. |
| `/site/src/content/solutions.ts` | 02, 03 | 02 → 03 | 02 ships the typed shape; 03 only patches `visuals` arrays with real filenames. 03 must NOT modify type definitions or other fields. |
| `/site/package.json` | 01, 06 | 01 → 06 | 01 ships `dev/build/preview/format` scripts. 06 adds the `prebuild` PDF-copy hook. Pure addition. |
| `/site/.gitignore` | 01, 06 | 01 → 06 | 01 ships base ignores; 06 appends `*.pdf` to keep the prebuild copies out of git. Pure addition. |
| `/README.md` (repo root) | 07 only | — | The single allowed edit outside `/site/` per EPIC-001 §0. Story 07 appends one line. |

Wave 2 stories (02 ‖ 03) **do not share files** — 02 writes only `/site/src/content/*.ts`; 03 writes `/site/public/assets/*` plus a final patch to `/site/src/content/solutions.ts.visuals`. Run 02 → 03 if running serially; run in parallel if 02 commits before 03 begins (the patch order is enforced by Wave 2 internal ordering).

### 2.3 Shared-Surface Warnings

- **`/site/src/pages/index.astro` is touched by 4 stories.** All sequential, all additive. Risk is low but each story's diff MUST be reviewed to confirm it ONLY adds its own section element — no reordering, no deletions of prior stories' work.
- **`/site/src/styles/global.css` is touched by 4 stories.** Same pattern, same low risk. Each story should append its block under a clearly commented section header (e.g. `/* === STORY-001-04: reveal === */`).
- **No file is touched by both Wave 2 stories** — 02 ‖ 03 are safe to parallelize.
- **`/site/src/content/solutions.ts` patch in 03 is the only cross-wave content edit.** STORY-003 must change ONLY the `visuals` arrays; the schema and other fields are 02's territory.

### 2.4 Lane Audit

*(Empty — all 7 stories run on the standard lane. No fast-lane assignments for SPRINT-001.)*

### 2.5 ADR-Conflict Flags

- None identified. The ClearGate framework's own knowledge base (`.cleargate/knowledge/`) is in the protected scope and is not modified by any sprint story.

## Risks & Dependencies

| Risk | Mitigation |
|---|---|
| Coolify service is not yet configured to point at `site/Dockerfile` with build context = repo root | Document the required Coolify config inline at the bottom of `site/Dockerfile` (per STORY-001-07 §4.2). User configures Coolify in parallel with story execution; verification slips to post-merge. |
| `nginx:alpine` base alone is ~50 MB; final image cap from EPIC was 50 MB | STORY-001-07 raises the realistic cap to 80 MB and notes the deviation. No story split needed. |
| STORY-001-05 is the only L3 in the sprint and could exceed wall-time on a single developer-agent run | If 05 stalls past 90 minutes of agent time, split into two L2 stories (e.g. `05a: ClearGate + Tee-Mo sections`, `05b: Exa section + shared `_SolutionSection` shell`). Splits at decomposition time are free; splits mid-run cost a re-plan. |
| MCP server (`cleargate-mcp.soula.ge`) is currently disconnected | Sprint runs locally end-to-end; `cleargate_push_item` for the sprint + items can wait until MCP recovers. State of truth is `state.json` on disk per protocol §17. |
| Source PDFs at repo root are read-only inputs and ship to `/site/dist/` via the prebuild hook | If either PDF moves or is renamed, the prebuild step fails loudly — no silent broken link. |

## Metrics & Metadata

- **Expected Impact:** Deployed public showcase URL (`hakathon2026.soula.ge`) with Lighthouse Performance ≥ 95, A11y ≥ 95, Best Practices ≥ 95, SEO ≥ 95 on a cold mobile run.
- **Priority Alignment:** All 7 stories are M1 (single milestone). No deferred items.
- **Token budget:** None set; first sprint in this repo, treat the sprint-end ledger as the baseline for future sprints.

---

## Execution Guidelines (Local Annotation — Not Pushed)

- **Starting point:** STORY-001-01 (foundation; blocks every other story). Run via the Architect → Developer → QA loop per `cleargate-protocol.md`.
- **Relevant context:** Read `.cleargate/wiki/index.md` first if it exists; otherwise `EPIC-001-Hackathon-Intro-Page.md` is the canonical handoff. Each story's §0 `<agent_context>` (where present) is the Developer agent's primary input.
- **Constraints (sprint-wide, lifted from EPIC-001 §0):**
  - **Stack is locked:** Astro 5 + Tailwind v4 + TypeScript strict + pnpm. No React, no shadcn/ui, no Framer Motion.
  - **Do NOT modify:** `/CLAUDE.md`, `/MANIFEST.json`, `/.cleargate/`, `/.claude/`, the two source PDFs at repo root. The single allowed edit outside `/site/` is `/README.md` in STORY-001-07.
  - **Single source of truth for copy:** `/site/src/content/{team,solutions,thread}.ts`. Components import; no inline marketing copy.
  - **Hard-coded dark theme.** Do not respect `prefers-color-scheme`.
  - **Reduced-motion = no animation.** Per EPIC §6 Q2, set `prefers-reduced-motion: reduce` shows everything immediately, no shorter-fade fallback.
  - **Halt-on-missing-photo at STORY-001-03.** All three `/team-photos/*.jpg` already exist on disk (verified 2026-04-27).
  - **No analytics, no third-party scripts, no GitHub Actions in this sprint.**
- **Per-story commit discipline:** One commit per story, conventional message (`feat(site): ...`), passes `pnpm format:check` + the story's Gherkin verifications before commit.
- **Sprint branch:** Per protocol §29, cut `sprint/SPRINT-001` from `main` once at sprint start; each story branches from there as `story/STORY-001-NN`. With Coolify configured to deploy from `main`, merging `sprint/SPRINT-001` → `main` at sprint close is the deploy trigger.
