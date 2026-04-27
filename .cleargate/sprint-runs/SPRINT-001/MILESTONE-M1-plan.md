# MILESTONE M1 — Hackathon Intro Page (SPRINT-001)

role: architect
sprint_id: SPRINT-001
stories: STORY-001-01 .. STORY-001-07
created_at: 2026-04-27
plan_author: architect (Claude Opus 4.7)

---

## 1. Milestone summary

M1 is the entire sprint: a static Astro 5 + Tailwind v4 single-page site at `/site/` introducing the Slop-Masters team and the three solutions (ClearGate, Tee-Mo, Exa), packaged as a multi-stage Dockerfile (`node:22-alpine` build → `nginx:alpine` serve) for Coolify auto-deploy from `main` to `https://hakathon2026.soula.ge`. Seven sequential-with-one-parallel-pair waves; no concurrent edits to any single file across waves. **Success = `https://hakathon2026.soula.ge` returns 200 with all 8 sections rendered, the smoke-test block in STORY-001-07 §1.2 passes locally, and a cold mobile Lighthouse run scores ≥ 95 on Performance / A11y / Best Practices / SEO.**

---

## 2. Cross-story architecture sketch (canonical shapes — Developers must NOT improvise away from these)

These are the load-bearing contracts every Developer must reproduce verbatim. Anything not pinned here is the Developer's call.

### 2.1 `/site/astro.config.mjs` skeleton (STORY-001-01 ships; later stories MUST NOT touch)

```js
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  output: "static",
  site: "https://hakathon2026.soula.ge",
  vite: {
    plugins: [tailwindcss()],
  },
});
```

Note the Tailwind v4 wiring is via `@tailwindcss/vite` ONLY — no `tailwind.config.ts`, no PostCSS config, no `@astrojs/tailwind` integration. This is the Tailwind v4 way.

### 2.2 `/site/src/styles/global.css` `@theme` token block (STORY-001-01 ships verbatim)

```css
@import "tailwindcss";

@theme {
  /* Surfaces */
  --color-bg: #0a0a0b;
  --color-fg: #f5f5f4;
  --color-muted: #a1a1aa;

  /* Per-solution accents (locked) */
  --color-accent-cleargate: #ea580c;
  --color-accent-teemo: #fb7185;
  --color-accent-exa: #00d563;

  /* Typography */
  --font-sans: "Geist Sans", ui-sans-serif, system-ui, sans-serif;
  --font-mono: "Geist Mono", ui-monospace, monospace;
}

/* === STORY-001-01: base === */
html.dark, body { background: var(--color-bg); color: var(--color-fg); font-family: var(--font-sans); }
```

The three accent hex values are LOCKED. Do not tweak. STORY-001-05 reads them as CSS vars; STORY-001-06 reads them in the Common Thread column headers. Changing a hex here breaks both downstream stories' Gherkin scenarios.

### 2.3 `<Reveal>` JS pattern (STORY-001-04 ships; STORY-001-05 and -06 only consume, never modify)

`/site/src/components/Reveal.astro` MUST emit exactly this single inline script (only one per page — Astro de-dupes `is:inline` only when src is identical, so the script body is intentionally idempotent):

```astro
---
// no props; the wrapper just adds .reveal-init to its single child
---
<div class="reveal-init"><slot /></div>

<script is:inline>
  (function () {
    var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduce) {
      document.querySelectorAll('.reveal-init').forEach(function (n) { n.classList.add('reveal-in'); });
      return;
    }
    var obs = new IntersectionObserver(function (entries) {
      for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (e.isIntersecting) { e.target.classList.add('reveal-in'); obs.unobserve(e.target); }
      }
    }, { threshold: 0.1 });
    document.querySelectorAll('.reveal-init').forEach(function (n) { obs.observe(n); });
  })();
</script>
```

Rules:
- One shared observer per page (the script auto-dedupes via `is:inline` when identical; do NOT instantiate per-component observers).
- Threshold = 0.1, exact value.
- `unobserve` on intersect (no re-firing).
- Reduced-motion path: NO observer, content visible immediately. Not a "shorter fade" — zero animation (per EPIC §6 Q2).
- The matching CSS lives in `global.css` under `/* === STORY-001-04: reveal === */` per §2.5 below.

### 2.4 Prebuild PDF-copy hook (STORY-001-06 ships in `package.json`; STORY-001-07 verifies it works inside Docker)

Two valid forms — Developer picks the one that works in their context. Both are acceptable per STORY-001-07 §3.2 ¶2:

| Form | Where it works | Notes |
|---|---|---|
| `"prebuild": "cp ../*.pdf public/"` | Local `/site/` checkout where the repo root is the parent dir | Default. Used for `pnpm dev` / `pnpm build` from `/site/`. |
| `"prebuild": "cp ./*.pdf public/"` | Inside the Docker build stage where `WORKDIR=/app` and the Dockerfile pre-COPYs the PDFs to `/app/` | Used when the Coolify build runs. |

STORY-001-07's Dockerfile MUST `COPY ClearGate_AI_Orchestration.pdf Tee-Mo_Sovereign_Intelligence.pdf ./` BEFORE `RUN pnpm build`, so by the time the prebuild hook fires, the PDFs are at `/app/*.pdf`. Either prebuild form (`./` or `../`) works because `/app/*.pdf` is one directory up from `/app/public/` and also at `/app/*.pdf` itself. Pick `cp ../*.pdf public/` — it matches the local-dev case and the Docker case is identical (one dir up from cwd).

`/site/.gitignore` MUST add `*.pdf` in STORY-001-06 so the copies never get committed back into the repo.

### 2.5 Per-story comment header convention in `/site/src/styles/global.css`

Every story that appends a CSS block to `global.css` MUST wrap it in a fenced comment block of the form:

```css
/* === STORY-001-NN: <topic> === */
... rules ...
/* === /STORY-001-NN === */
```

Concrete blocks expected:
- `STORY-001-01: base` — `@theme` block + `html.dark`/`body` reset + Geist font wiring.
- `STORY-001-04: reveal` — `.reveal-init`, `.reveal-in`, `@media (prefers-reduced-motion: reduce)` block, hero radial-gradient background.
- `STORY-001-05: solution-accents` — `[data-accent="..."]` rules, bullet-card styles, asymmetric `.visuals` grid.
- `STORY-001-06: thread-and-polish` — Common Thread mobile-card fallback, footer columns, `--gutter` var, hero `clamp()` typography, the consolidated `@media (prefers-reduced-motion: reduce)` audit block.

A later story APPENDS its block; it never deletes or rewrites a prior story's block. QA's first check on every shared-file diff is "is this purely additive?"

---

## 3. Shared-surface contract (one rule per file)

Four files are touched by ≥ 2 stories. One rule per file, no exceptions:

| File | Touched by | Rule |
|---|---|---|
| `/site/src/styles/global.css` | 01, 04, 05, 06 | **Append-only under your story's fenced comment header (§2.5).** Never edit a prior story's block. The `@theme` block stays at the top, untouched after STORY-001-01. |
| `/site/src/pages/index.astro` | 01, 04, 05, 06 | **The `<main>` content is the only surface that grows.** STORY-001-01 ships placeholder `<main>...</main>`; STORY-001-04 replaces the placeholder with `<Hero/><Team/><Collaboration/>`; STORY-001-05 appends `<SolutionClearGate/><SolutionTeeMo/><SolutionExa/>`; STORY-001-06 appends `<CommonThread/><Footer/>`. Order is locked. No reordering, no wrapping in extra divs, no deletions. |
| `/site/src/content/solutions.ts` | 02, 03 | **STORY-001-02 owns the type definition + every field except `visuals`.** STORY-001-03 patches `visuals[]` only — exact filenames per its §1.2. STORY-001-03 must NOT modify the `Solution` type, `bullets`, `pitch`, `cta`, or `accent`. |
| `/site/package.json` | 01, 06 (and 07 indirectly via Docker) | **Scripts only grow.** STORY-001-01 ships `dev`, `build`, `preview`, `format`, `format:check`. STORY-001-06 adds exactly one key: `"prebuild": "cp ../*.pdf public/"`. STORY-001-07 makes no edits to `package.json`; the Dockerfile is the only new artifact in 07. |

Bonus shared file (lower risk, still worth pinning):

| File | Touched by | Rule |
|---|---|---|
| `/site/.gitignore` | 01, 06 | STORY-001-01 ships `node_modules`, `dist`, `.astro`. STORY-001-06 appends one line: `*.pdf`. Pure addition. |
| `/README.md` (repo root) | 07 only | The single allowed edit OUTSIDE `/site/`, per EPIC-001 §0. STORY-001-07 appends one block: a horizontal rule + `🌐 **Live site:** [hakathon2026.soula.ge](https://hakathon2026.soula.ge)`. No other edits anywhere outside `/site/`. |

---

## 4. Wave-by-wave handoff

### Wave 1 — STORY-001-01 (sequential foundation)
- **Produce:** scaffolded `/site/` Astro app: `astro.config.mjs` per §2.1, `global.css` with `@theme` block per §2.2, `Base.astro` with Geist + meta tags, placeholder `index.astro`, `package.json` with the four base scripts, `.prettierrc`, `.gitignore`. No components yet.
- **Downstream readers:** every later story imports from this scaffold; STORY-001-04 reads `Base.astro` and `global.css`; STORY-001-02 reads nothing (pure data) but builds inside the Astro tree.
- **Acceptance signal:** "Production build succeeds and outputs static HTML" (STORY-001-01 §2.1, scenario 3) — `pnpm build` exit 0 + `/site/dist/index.html` exists + no Node files in `dist/`.

### Wave 2 — STORY-001-02 ‖ STORY-001-03 (parallelizable)
- **02 produces:** `/site/src/content/{team.ts,solutions.ts,thread.ts}` — typed, three exports, `visuals: []` initially empty (or empty arrays — STORY-001-03 will fill). The `collaboration.paragraph` text is locked verbatim per STORY-001-02 §1.2.
- **03 produces:** all images under `/site/public/assets/{cleargate,teemo,exa,team,og}/` plus the extraction script at `/site/scripts/extract-assets.sh` (or `.mjs`), AND a patch to `/site/src/content/solutions.ts` filling each `visuals[]` with the 7-or-8 real filenames in display order.
- **Parallelism note:** 02 and 03 do not share files DURING execution, but 03's patch to `solutions.ts` MUST land AFTER 02's commit. If running in parallel, gate 03's content-patch step on 02 being merged first; the asset-extraction work in 03 can proceed independently.
- **Downstream readers:** STORY-001-04 imports `team` + `collaboration` from `team.ts`; STORY-001-05 imports `solutions` from `solutions.ts` and references files in `/site/public/assets/{cleargate,teemo,exa}/`; STORY-001-06 imports `thread` from `thread.ts`.
- **Acceptance signal (02):** "Type-check passes" (STORY-001-02 §2.1, scenario 1) — `pnpm exec astro check` exit 0.
- **Acceptance signal (03):** "Content layer references real files" (STORY-001-03 §2.1, last scenario) — every path in every `visuals[]` resolves to an existing file.

### Wave 3 — STORY-001-04 (sequential)
- **Produce:** `Reveal.astro` per §2.3, `Hero.astro`, `Team.astro`, `Collaboration.astro`, the `STORY-001-04: reveal` CSS block in `global.css`, and the first real `<main>` body in `index.astro` (`<Hero/><Team/><Collaboration/>`).
- **Downstream readers:** STORY-001-05 imports `<Reveal>`; STORY-001-06 imports `<Reveal>` again and reads the reduced-motion CSS block to extend it.
- **Acceptance signal:** "Reduced motion bypasses the observer" (STORY-001-04 §2.1, scenario 6) — every `.reveal-init` has `.reveal-in` immediately, no IntersectionObserver instance is created.

### Wave 4 — STORY-001-05 (sequential)
- **Produce:** `SolutionClearGate.astro`, `SolutionTeeMo.astro`, `SolutionExa.astro` (and optionally a private `_SolutionSection.astro` shell — only if ≥ 80% markup overlap, per the story's own §3.2 ¶1). The `STORY-001-05: solution-accents` CSS block in `global.css`. Append three components to `index.astro`'s `<main>`.
- **Downstream readers:** STORY-001-06 walks every section to verify the reduced-motion sweep; QA reads the `data-accent` attribute to verify accent CSS vars resolve to the locked hex values.
- **Acceptance signal:** "Each section uses its own accent color" (STORY-001-05 §2.1, scenario 2) — `[data-accent="cleargate"]` resolves `--accent` to `#ea580c`, etc.

### Wave 5 — STORY-001-06 (sequential)
- **Produce:** `CommonThread.astro`, `Footer.astro`, the `STORY-001-06: thread-and-polish` CSS block (responsive `--gutter`, hero `clamp()`, mobile-table card fallback, consolidated reduced-motion `@media` block), the `prebuild` script in `package.json` per §2.4, the `*.pdf` line in `/site/.gitignore`. Append `<CommonThread/><Footer/>` to `index.astro`.
- **Downstream readers:** STORY-001-07 verifies that `pnpm build` outputs both PDFs into `/site/dist/`; the smoke test curls `/ClearGate_AI_Orchestration.pdf` against the running container.
- **Acceptance signal:** "Both PDFs are reachable on the deployed bundle" (STORY-001-06 §2.1, scenario 3) — `/site/dist/ClearGate_AI_Orchestration.pdf` and `/site/dist/Tee-Mo_Sovereign_Intelligence.pdf` exist after `pnpm build`.

### Wave 6 — STORY-001-07 (sequential — packaging)
- **Produce:** `/site/Dockerfile` (final form per the story's §1.2 ¶2 — build context = repo root, `Dockerfile = site/Dockerfile`), `/site/nginx.conf`, `/site/.dockerignore`, the README append. Run the smoke-test block from §1.2 verbatim.
- **Downstream readers:** Coolify (out of band) — its service config must be `Build context = /, Dockerfile = site/Dockerfile`. Document this expectation inline at the bottom of `/site/Dockerfile` as comments.
- **Acceptance signal:** "Container serves the homepage" (STORY-001-07 §2.1, scenario 3) — `curl -sf http://localhost:8080/ | grep -q "Slop-Masters"` exits 0 against the locally-built image.

---

## 5. Risk register (carried forward from sprint plan §"Risks & Dependencies")

| # | Risk (verbatim from sprint plan) | Mitigation (sprint plan) | Architect tweak |
|---|---|---|---|
| 1 | Coolify service is not yet configured to point at `site/Dockerfile` with build context = repo root | Document the required Coolify config inline at the bottom of `site/Dockerfile`. Verification slips to post-merge. | None — accepted as is. The Coolify-side config is genuinely out of scope; documenting it inline is the right hedge. |
| 2 | `nginx:alpine` base alone is ~50 MB; final image cap from EPIC was 50 MB | STORY-001-07 raises the realistic cap to 80 MB and notes the deviation. | None. The 80 MB cap is the realistic ceiling and is already pinned in STORY-001-07 §1.2. |
| 3 | STORY-001-05 is the only L3 in the sprint and could exceed wall-time on a single Developer-agent run | If 05 stalls past 90 minutes, split into 05a (CG + Tee-Mo) and 05b (Exa + shell). Splits at decomposition are free; mid-run splits cost a re-plan. | **Tweak:** the orchestrator should pre-emit a soft 75-minute checkpoint for STORY-001-05 — if the Developer agent has not yet committed `SolutionClearGate.astro` by then, treat it as the early-warning signal and prepare the 05a/05b split before the 90-minute hard line. Saves one cycle of context loss on the re-plan. |
| 4 | MCP server (`cleargate-mcp.soula.ge`) is currently disconnected | Sprint runs locally end-to-end; `cleargate_push_item` waits for MCP recovery. Source of truth = `state.json` on disk per protocol §17. | None — already correct. |
| 5 | Source PDFs at repo root are read-only inputs and ship to `/site/dist/` via the prebuild hook | If either PDF moves or is renamed, the prebuild step fails loudly — no silent broken link. | None. The fail-loud behavior is already the right design; `cp` will exit non-zero on missing source. |

No new risks identified during plan synthesis.

---

## 6. Open architectural questions

I read every story file end-to-end. I identified ONE non-trivial spec ambiguity worth surfacing before Developer-agent dispatch, and ZERO contradictions between sprint plan / epic / stories.

### 6.1 STORY-001-06 prebuild hook vs STORY-001-07 Dockerfile prebuild path

**Where it shows up:**
- `/Users/ssuladze/Documents/Dev/Hakathon/.cleargate/delivery/archive/STORY-001-06-Common-Thread-Footer-Polish.md` §3.2 ¶1: prescribes `"prebuild": "cp ../ClearGate_AI_Orchestration.pdf ../Tee-Mo_Sovereign_Intelligence.pdf public/"` (the `../` form), assuming local-dev cwd = `/site/`.
- `/Users/ssuladze/Documents/Dev/Hakathon/.cleargate/delivery/archive/STORY-001-07-Dockerfile-and-Coolify.md` §3.2 ¶2: explicitly notes the prebuild form may need to flip to `cp ./*.pdf public/` inside the Docker build stage, and says "both forms are acceptable; pick what works in the container."

**The ambiguity:** if STORY-001-06's Developer commits `cp ../*.pdf public/` and STORY-001-07's Developer discovers it doesn't work inside Docker, STORY-001-07 will silently edit `package.json` — but `package.json` is NOT in STORY-001-07's allowed file list per its §4.2 (`No file outside /site/ and /README.md is modified` is fine, but STORY-001-07's intent is "package the build, not edit scripts").

**§2.4 of this plan resolves it concretely:** I prescribe `cp ../*.pdf public/` because, given the Dockerfile WORKDIR=`/app` and `pnpm build` running with cwd=`/app`, the prebuild's `..` resolves to `/` of the build container, and `..*.pdf` matches the PDFs that the Dockerfile COPYs to `/app/` AND the parent. **Wait — that's wrong.** `cp ../*.pdf public/` from cwd=`/app` looks at `/*.pdf`, not `/app/*.pdf`. The Dockerfile in STORY-001-07 §1.2 final-form COPYs the PDFs to `./` which is `/app/`, so `../*.pdf` would NOT find them — only `./*.pdf` would.

**Recommendation to orchestrator:** authorize STORY-001-07's Developer to amend `package.json`'s `prebuild` script from `cp ../*.pdf public/` to `cp ./*.pdf public/` IF the smoke test fails on missing PDFs in `/site/dist/`. This is a one-line scoped exception to STORY-001-07's "no `package.json` edits" rule. Alternatively: have STORY-001-06's Developer ship `cp ./*.pdf public/` from the start AND have STORY-001-07's Dockerfile add `WORKDIR /app && COPY ClearGate_AI_Orchestration.pdf Tee-Mo_Sovereign_Intelligence.pdf ./` so `./*.pdf` resolves locally. The second path is cleaner. **Decision needed from orchestrator before Wave 5 dispatch.**

**No drift between sprint plan, epic, and stories** — sprint plan §2.2 row 4 (`/site/package.json` touched by 01, 06) matches the stories. The drift, if any, is between STORY-001-06 and STORY-001-07's own description of the same hook — and STORY-001-07 already flags it as "pick what works." I am not silently fixing it; I am surfacing it.

---

## 7. Dispatch order recommended for the orchestrator

Strict sequence, with the only parallel handoff in Wave 2:

```
1. Dispatch STORY-001-01 (foundation; blocks everything).
   └─ Wait for Developer + QA pass + commit on story/STORY-001-01.

2. Dispatch STORY-001-02 AND STORY-001-03 IN PARALLEL.
   ├─ STORY-001-02: typed content layer.
   └─ STORY-001-03: asset extraction.
   └─ Synchronization: STORY-001-03's content-layer patch step (the visuals[]
      filenames) must land on the branch AFTER STORY-001-02 commits. If 03
      finishes its asset-extraction work before 02 commits, hold the patch
      and resume after 02 lands. QA runs once for each story.

3. Dispatch STORY-001-04 (Hero + Team + Collaboration + Reveal).
   └─ Wait for Developer + QA pass + commit.

4. Dispatch STORY-001-05 (three solution sections).
   └─ Set a 75-minute soft checkpoint per §5 risk #3.
   └─ If checkpoint missed, prepare 05a/05b split before the 90-minute hard line.
   └─ Wait for Developer + QA pass + commit.

5. Dispatch STORY-001-06 (Common Thread + Footer + polish + prebuild hook).
   └─ Wait for Developer + QA pass + commit.

6. RESOLVE §6.1 prebuild-hook ambiguity with the user before dispatching 07,
   OR explicitly authorize STORY-001-07's Developer to amend package.json's
   prebuild script if the Docker smoke test fails on missing PDFs.

7. Dispatch STORY-001-07 (Dockerfile + nginx + smoke test + README link).
   └─ Wait for Developer + QA pass + commit.

8. Sprint close: merge sprint/SPRINT-001 → main. Coolify auto-deploys.
   Run Lighthouse mobile against https://hakathon2026.soula.ge — verify
   Performance / A11y / Best Practices / SEO each ≥ 95.
```

End of plan.
