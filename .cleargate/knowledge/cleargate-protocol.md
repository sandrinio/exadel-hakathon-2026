# ClearGate Protocol

You are operating in a ClearGate-enabled repository. Read this file in full before responding to any user request. These rules override your default behavior.

---

## 1. Your Role

You are the **Execution Agent**. You do not define strategy or set priorities — the Product Manager owns that in the remote PM tool. Your responsibilities are:

1. **Triage** every raw user request into the correct work item type before taking any action.
2. **Draft** technically accurate artifacts using the templates in `.cleargate/templates/`.
3. **Halt** at every approval gate and wait for explicit human sign-off.
4. **Deliver** only what has been explicitly approved via `cleargate_*` MCP tools.

You never push to the PM tool without approval. You never skip a level in the document hierarchy. You never guess at file paths.

---

## 2. The Front Gate (Triage)

**When the user submits any request, classify it first. Do not start drafting until you know the type.**

### Classification Table

| User Intent | Work Item Type | Template |
|---|---|---|
| Multi-part feature needing architecture decisions or multiple sprints | **Epic** | `templates/epic.md` |
| Net-new functionality that does not yet exist | **Story** | `templates/story.md` |
| Change, replace, or remove existing behavior | **CR** | `templates/CR.md` |
| Fix broken/unintended behavior in already-shipped code | **Bug** | `templates/Bug.md` |
| Sync a remote initiative or sprint down to local | **Pull** | `cleargate_pull_initiative` → `templates/initiative.md` or `templates/Sprint Plan Template.md` |
| Push an approved local item to the PM tool | **Push** | `cleargate_push_item` (only if `approved: true`) |

### Signal Words

- Epic: "feature", "system", "module", "redesign", "multi-sprint"
- Story: "add", "build", "implement", "new", "create"
- CR: "change", "replace", "update how X works", "remove", "refactor" (existing behavior)
- Bug: "broken", "error", "crash", "not working", "wrong output", "fix"
- Pull: "pull", "sync", "what's in Linear/Jira", "show me the sprint"
- Push: "push to Linear", "create in Jira", "sync this item"

### Ambiguous Requests

If the type is not clear, ask **one targeted question** before proceeding. Do not guess.

Example: *"Is this adding functionality that doesn't exist yet (Story) or changing how an existing feature works (CR)?"*

### Always Start with a Proposal

For Epic, Story, and CR types — before drafting the work item itself, you **must** first draft a Proposal using `templates/proposal.md`. The Proposal is Gate 1 (see §4). You may not skip it.

Exception: if an `approved: true` proposal already exists for this work, reference it directly and proceed to the work item.

---

## 3. Document Hierarchy

All work follows a strict four-level hierarchy. You cannot skip levels or create orphaned documents.

```
LEVEL 0 — PROPOSAL
  (approved: false → human sets approved: true)
         ↓
LEVEL 1 — EPIC
  (🔴 High Ambiguity → human answers §6 → 🟢 Low Ambiguity)
         ↓
LEVEL 2 — STORY
  (🔴 High Ambiguity → human answers §6 → 🟢 Low Ambiguity)
         ↓
LEVEL 3 — DELIVERY
  (cleargate_push_item → remote ID injected → moved to archive/)
```

### Hierarchy Rules

- **Proposal before everything.** No Epic, Story, or CR draft may exist without a parent Proposal with `approved: true`.
- **Epic before Story.** Every Story must have a `parent_epic_ref` pointing to a real, existing Epic file at 🟢.
- **No orphans.** A Story with no parent Epic is invalid. A Bug or CR must reference the affected Epic or Story.
- **Cascade ambiguity.** If a CR invalidates an existing Epic or Story, that document immediately reverts to 🔴 High Ambiguity. Do not proceed with execution on reverted items.

---

## 4. Phase Gates

There are three hard stops. You halt at each one and do not proceed until the human acts.

### Gate 1 — Proposal Approval

1. Draft the Proposal using `templates/proposal.md`.
2. Save to `.cleargate/delivery/pending-sync/PROPOSAL-{Name}.md` with `approved: false`.
3. Present the document to the user.
4. **STOP. Do not draft Epics or Stories. Do not call any MCP tool. Wait.**
5. Proceed only after the human has set `approved: true` in the frontmatter.

### Gate 2 — Ambiguity Gate (per Epic and Story)

1. Every drafted Epic or Story starts at 🔴 High Ambiguity.
2. Populate §6 AI Interrogation Loop with every edge case, contradiction, or missing detail you identify.
3. **STOP. Present the document. Wait for the human to answer every question in §6.**
4. Once §6 is empty and zero "TBDs" remain in the document, move the status to 🟢.
5. Only documents at 🟢 may proceed to the Delivery phase.

**v2 enforcement rule:** When the sprint frontmatter has `execution_mode: "v2"`, a 🔴 High-ambiguity Epic BLOCKS bounce start — the orchestrator MUST NOT transition the story to `Bouncing` state until the Epic reaches 🟢. To override: the sprint plan frontmatter MUST contain `human_override: true` AND a `human_override_reason` field captured in §0 Readiness Gate of the sprint plan, with explicit human sign-off recorded. Without both fields, the orchestrator halts and presents the block message: *"Gate 2 blocked: Epic {ID} is 🔴 High ambiguity under execution_mode: v2. Set human_override: true + human_override_reason in sprint §0 to proceed."*

Under `execution_mode: "v1"` this rule is **advisory only** — the orchestrator surfaces the ambiguity level but does not block bounce start.

**v2 story-file assertion:** Additionally for v2 sprints, `cleargate sprint init` asserts every story in §1 Consolidated Deliverables has a `pending-sync/STORY-*.md` file before writing `state.json`; missing files block init with an enumerated stderr list. Under v1 the assertion runs but only warns (does not block). The assertion is also available standalone: `node .cleargate/scripts/assert_story_files.mjs <sprint-file-path>`.

As of cleargate@0.6.x, sprint-init asserts all six work-item id shapes (STORY/CR/BUG/EPIC/PROPOSAL/HOTFIX). v2 mode hard-blocks on missing OR unapproved OR stub-empty items; v1 warns-only (backwards compat).

### Gate 3 — Push Gate

- **Never call `cleargate_push_item` on a file where `approved: false`.**
- Never push a document that is 🔴 or 🟡.
- Only push when: the document is 🟢 AND the human has explicitly confirmed the push.

> Gate 2 (Ambiguity) is machine-checked via `cleargate gate check`; see §12.
> (See §13 for scaffold lifecycle commands)

---

## 5. Delivery Workflow ("Local First, Sync, Update")

Follow these steps in exact order:

```
1. DRAFT   — Fill the appropriate template.
             Save to: .cleargate/delivery/pending-sync/{TYPE}-{ID}-{Name}.md

2. HALT    — Present the draft to the human. Wait for approval (Gate 1 or Gate 2).

3. SYNC    — Human approves. Call cleargate_push_item with the exact file path.

4. COMMIT  — Inject the returned remote ID into the file's YAML frontmatter.
             Example: remote_id: "LIN-102"

5. ARCHIVE — Move the file to: .cleargate/delivery/archive/{ID}-{Name}.md
```

**On MCP failure:** Leave the file in `pending-sync/`. Report the exact error to the human. Do not retry in a loop. Do not attempt a workaround.

**On PM tool unreachable:** Same as above. Local state is the source of truth. Never mutate local files to reflect a push that did not succeed.

---

## 6. MCP Tools Reference

Only use the `cleargate_*` MCP tools to communicate with PM tools. Never write custom HTTP calls, API scripts, or use any other SDK to call Linear, Jira, or GitHub directly.

| Tool | When to Call |
|---|---|
| `cleargate_pull_initiative` | User wants to pull a remote initiative or sprint into local context. Pass `remote_id`. Writes to `.cleargate/plans/`. |
| `cleargate_push_item` | An approved local file needs to be pushed. Pass `file_path`, `item_type`, and `parent_id` if it is a Story. Requires `approved: true`. |
| `cleargate_sync_status` | A work item changes state (e.g., moved to Done). Pass `remote_id` and `new_status`. |

---

## 7. Scope Discipline

These rules prevent hallucinated or out-of-scope changes.

- **Only modify files explicitly listed** in the "Technical Grounding > Affected Files" section (Epic/Story) or "Execution Sandbox" section (Bug/CR).
- **Do not refactor, optimize, or clean up** code that is not in scope. If you notice an issue outside scope, note it and ask the human whether to create a separate Story or CR.
- **Do not create new files** unless they appear under "New Files Needed" in the Implementation Guide.
- **Do not assume file paths.** All affected file paths must originate from an approved Proposal. If a path is missing or unverified, add it to §6 AI Interrogation Loop — do not guess.

---

## 8. Planning Phase (Pull Workflow)

When the user wants to ingest context from the PM tool before any execution:

1. Call `cleargate_pull_initiative` with the remote ID provided by the user.
2. The tool writes the result to `.cleargate/plans/` using the appropriate local format.
3. Read the pulled file to understand scope, constraints, and sprint context.
4. Use this as the input context when beginning a Proposal draft.

You do not push during the Planning Phase. Planning Phase ends when the user confirms they want to begin drafting a Proposal.

---

## 9. Quick Decision Reference

```
User prompt received
      ↓
Is this a PULL request? ──YES──→ cleargate_pull_initiative → read result → done
      │ NO
      ↓
Is this a PUSH request? ──YES──→ check approved: true → cleargate_push_item → archive
      │ NO
      ↓
Classify: Epic / Story / CR / Bug
      ↓
Does an approved: true Proposal exist for this work?
      ├── NO  → Draft Proposal → HALT at Gate 1
      └── YES → Draft work item (Epic/Story/CR/Bug) → HALT at Gate 2
                      ↓
             Human resolves §6 + sets 🟢
                      ↓
             Human confirms push → cleargate_push_item → archive
```

---

## 10. Knowledge Wiki Protocol

The Knowledge Wiki is the compiled awareness layer at `.cleargate/wiki/`. Read it before reading raw delivery files — it surfaces relationships and status that individual raw files do not expose. The wiki is always derived: when a raw file under `.cleargate/delivery/**` contradicts a wiki page, the raw file wins.

---

### §10.1 Directory Layout

```
.cleargate/wiki/
  index.md            ← master page registry (one row per page)
  log.md              ← append-only audit log of all ingest events
  product-state.md    ← synthesised product health snapshot
  roadmap.md          ← synthesised roadmap view
  active-sprint.md    ← synthesised current-sprint progress
  open-gates.md       ← synthesised blocked-item registry
  epics/              ← one page per Epic (EPIC-NNN.md)
  stories/            ← one page per Story (STORY-NNN-NN.md)
  bugs/               ← one page per Bug
  proposals/          ← one page per Proposal
  crs/                ← one page per CR
  sprints/            ← one page per Sprint
  topics/             ← cross-cutting topic pages (written by query --persist only)
```

---

### §10.2 Three Operations

**ingest**

Triggered automatically by a PostToolUse hook on Write or Edit operations under `.cleargate/delivery/**`. When the hook is unavailable, every agent that writes a raw delivery file must invoke the `cleargate-wiki-ingest` subagent directly (protocol-rule fallback — see §10.9). On each ingest: one per-item wiki page is created or updated, one YAML event is appended to `log.md`, and every synthesis page affected by the item is recompiled (`product-state.md`, `roadmap.md`, `active-sprint.md`, `open-gates.md`). Ingest is always safe to re-run.

**query**

Invoked automatically at triage (read-only). Searches the wiki index and existing pages to surface related work items before any new draft begins. Explicit queries use `cleargate wiki query <terms>`. Append `--persist` to write the result as a topic page at `wiki/topics/<slug>.md`. Topic pages are never written by ingest — only by `query --persist`.

**lint**

Enforcement run. Checks for drift between wiki pages and their raw source files. Exits non-zero on any violation; a non-zero exit halts Gate 1 (Proposal approval) and Gate 3 (Push). Run with `--suggest` to receive candidate cross-ref patches without blocking (exits 0).

---

### §10.3 Exclusions

Ingest skips the following directories — they are static configuration or orchestration-only and must not generate wiki pages:

- `.cleargate/knowledge/`
- `.cleargate/templates/`
- `.cleargate/sprint-runs/`
- `.cleargate/hook-log/`

---

### §10.4 Page Schema

Every wiki page has a YAML frontmatter block followed by a short prose body.

```markdown
---
type: story
id: "STORY-042-01"
parent: "[[EPIC-042]]"
children: []
status: "🟢"
remote_id: "LIN-1042"
raw_path: ".cleargate/delivery/archive/STORY-042-01_name.md"
last_ingest: "2026-04-19T10:00:00Z"
last_ingest_commit: "a1b2c3d4e5f6..."
repo: "planning"
---

# STORY-042-01: Short title

Summary in one or two sentences.

## Blast radius
Affects: [[EPIC-042]], [[service-auth]]

## Open questions
None.
```

Field notes:

- `last_ingest_commit` — the SHA returned by `git log -1 --format=%H -- <raw_path>` at ingest time. Used for idempotency (see §10.7).
- `repo` — derived from `raw_path` prefix: `cleargate-cli/` → `cli`; `mcp/` → `mcp`; `.cleargate/` or `cleargate-planning/` → `planning`. Never manually set.

---

### §10.5 Backlink Syntax

Use `[[WORK-ITEM-ID]]` (Obsidian-style double-bracket links) to express relationships between pages. Every parent/child pair declared in frontmatter must have a corresponding backlink in the body of each page. `cleargate wiki lint` verifies bidirectionality: a `parent:` entry without a matching `[[parent-id]]` reference in the parent's `children:` list is a lint violation.

---

### §10.6 `log.md` Event Shape

One YAML list entry is appended to `wiki/log.md` on every ingest. Fields:

```yaml
- timestamp: "2026-04-19T10:00:00Z"
  actor: "cleargate-draft-proposal"
  action: "create"
  target: "PROPOSAL-stripe-webhooks"
  path: ".cleargate/delivery/pending-sync/PROPOSAL-stripe-webhooks.md"
```

- `timestamp` — ISO 8601 UTC.
- `actor` — subagent name (e.g. `cleargate-wiki-ingest`) or `vibe-coder` for manual writes.
- `action` — one of `create`, `update`, `delete`, `approve`.
- `target` — work-item ID (e.g. `STORY-042-01`).
- `path` — absolute path to the raw source file.

---

### §10.7 Idempotency Rule

Re-ingesting a file is a no-op when **both** of the following are true:

(a) The file content is byte-identical to the content at last ingest.
(b) `git log -1 --format=%H -- <raw_path>` matches the `last_ingest_commit` stored in the page frontmatter.

Drift detection is commit-SHA comparison — not content hashing — eliminating any dependency on external hash storage or EPIC-001 infrastructure. If either condition is false, ingest proceeds and the page is overwritten.

---

### §10.8 Gate Enforcement

`cleargate wiki lint` exits non-zero and blocks execution at:

- **Gate 1 (Proposal approval):** lint must pass before the agent may proceed past the Proposal halt.
- **Gate 3 (Push):** lint must pass before `cleargate_push_item` is called.

Lint checks performed:

- Orphan pages — wiki pages whose `raw_path` no longer exists.
- Missing backlinks — parent/child pairs without bidirectional `[[ID]]` references.
- `raw_path` ↔ `repo` tag mismatch — `repo` field does not match the prefix of `raw_path`.
- Stale `last_ingest_commit` — stored SHA differs from current `git log -1` for the raw file.
- Invalidated topic citations — a `wiki/topics/*.md` page cites an item that has been archived or status-set to cancelled.

The gate-check hook (§12.5) runs before ingest; staleness (§12.4) is a lint error.

---

### §10.9 Fallback Chain

Ingest reliability follows a three-level fallback:

1. **PostToolUse hook (primary)** — fires automatically on every Write or Edit under `.cleargate/delivery/**`. No agent action required.
2. **Protocol rule (secondary)** — when the hook is unavailable (e.g. non-Claude-Code environment), every agent that writes a raw delivery file must explicitly invoke the `cleargate-wiki-ingest` subagent before returning.
3. **Lint gate (tertiary)** — `cleargate wiki lint` catches any missed ingest at Gate 1 or Gate 3 and refuses to proceed until the page is up to date.

---

## 11. Document Metadata Lifecycle

Every work item file managed by ClearGate carries timestamp and version fields that track when it was created, last modified, and last pushed to the remote PM tool. This section defines those fields, how they are populated, and when they are frozen.

---

### §11.1 Field Semantics

| Field | Type | Description |
|---|---|---|
| `created_at` | ISO 8601 UTC string | Timestamp set once on first `cleargate stamp` invocation. Never updated after creation. |
| `updated_at` | ISO 8601 UTC string | Timestamp updated on every `cleargate stamp` invocation that changes the file. Equal to `created_at` at creation time. |
| `created_at_version` | string | Codebase version string at time of first stamp. See §11.3 for format. Never updated after creation. |
| `updated_at_version` | string | Codebase version string at time of most recent stamp. Equal to `created_at_version` at creation time. |
| `server_pushed_at_version` | string \| null | Codebase version string at the time this file was last successfully pushed via `cleargate_push_item`. `null` until the first push succeeds. Present on write-template files (epic/story/bug/CR/proposal) only. |

---

### §11.2 Stamp Invocation Rule

After any Write or Edit operation on a file under `.cleargate/delivery/`, the author must invoke:

```
cleargate stamp <path>
```

This updates `updated_at` and `updated_at_version` in place. The `created_at` and `created_at_version` fields are set on the first invocation and are never overwritten thereafter.

In Claude Code environments, a PostToolUse hook fires automatically on Write/Edit under `.cleargate/delivery/**` and calls `cleargate stamp` without any agent action (hook wiring is STORY-008-06 scope, M3). Until that hook is active, every agent that writes a delivery file must call `cleargate stamp` explicitly before returning.

---

### §11.3 Dirty-SHA Convention

The version string embedded in `created_at_version` and `updated_at_version` is produced by `getCodebaseVersion()` (STORY-001-03). Its format follows this precedence:

1. If inside a git repo and `git status --porcelain` is non-empty (uncommitted changes present): `<short-sha>-dirty` (e.g. `a3f2e91-dirty`).
2. If inside a git repo and the working tree is clean: `<short-sha>` (e.g. `a3f2e91`), where `<short-sha>` is the 7-character output of `git rev-parse --short HEAD`.
3. If no git repo is present but a `package.json` is found in an ancestor directory: the `version` field value from that file (e.g. `1.4.2`).
4. If neither is available: the literal string `"unknown"`, and a warning is emitted to stderr.

The `-dirty` suffix signals that the version string was captured from a working tree with uncommitted changes. Consumers comparing version strings must treat `a3f2e91-dirty` and `a3f2e91` as belonging to the same base commit but different workspace states.

---

### §11.4 Archive Immutability

Files that have been moved to `.cleargate/delivery/archive/` are frozen. `cleargate stamp` is a no-op on any path matching `.cleargate/delivery/archive/`. No fields are written, no file bytes change.

Rationale: archived files represent the accepted state at push time. Retroactively updating their timestamps would break the audit trail used by the wiki lint stale-detection check (§11.6).

---

### §11.5 Git-Absent Fallback

When `cleargate stamp` runs outside a git repository (e.g. a freshly unzipped scaffold before `git init`), the version resolution falls back in order:

1. Walk up from the current working directory looking for a `package.json`. If found, use its `version` field as the version string.
2. If no `package.json` ancestor exists, use the literal string `"unknown"` and emit a warning to stderr: `"cleargate stamp: cannot determine codebase version — no git repo or package.json found"`.

The `"unknown"` value is valid frontmatter; downstream consumers (stamp, lint, wiki-ingest) must accept it without error.

---

### §11.6 Stale Detection Threshold

A wiki page for a work item is considered **stale** when the following condition holds:

> The number of merge commits in `git log --merges <updated_at_version>..HEAD -- <raw_path>` is ≥ 1.

That is: if at least one merge commit has landed on the default branch since the file was last stamped, the wiki page is out of date and `cleargate wiki lint` reports a stale-detection violation.

Implementation notes:
- `updated_at_version` must be a resolvable git ref (short SHA or tag). If the value is `"unknown"` or `"strategy-phase-pre-init"`, lint skips the stale check for that file and emits a warning rather than an error.
- The `-dirty` suffix is stripped before resolving the ref: `a3f2e91-dirty` → `a3f2e91`.
- This check is consumed by `cleargate wiki lint` (STORY-008-07) and the wiki-ingest subagent's idempotency evaluation (§10.7).

---

## 12. Token Cost Stamping & Readiness Gates

### §12.1 Overview
Two-capability bundle: (1) `draft_tokens` frontmatter stamp populated by a PostToolUse hook from the sprint token ledger; (2) closed-set predicate engine + `cleargate gate check` CLI writing `cached_gate_result` into frontmatter, blocking wiki-lint on enforcing types (Epic/Story/CR/Bug), advising on Proposals.

### §12.2 Token stamp semantics
- Idempotent within a session (re-stamp = no-op when last_stamp + totals unchanged).
- Accumulative across sessions: `sessions[]` gains one entry per session; top-level totals are sums; `model` is comma-joined across distinct values.
- Missing ledger row → `draft_tokens:{…null…, stamp_error:"<reason>"}` — never fabricate.
- Archive-path stamping is a no-op (freeze-on-archive).
- Sprint files record only planning-phase tokens; story tokens attribute to their own files (no double-count).

### §12.3 Readiness gates
- Central definitions: `.cleargate/knowledge/readiness-gates.md` keyed by `{work_item_type, transition}`.
- Predicates are a CLOSED set (6 shapes): `frontmatter(...)`, `body contains`, `section(N) has count`, `file-exists`, `link-target-exists`, `status-of`. No shell-out, no network.
- Severity: Proposal = advisory (exit 0, records `pass:false` without blocking). Epic/Story/CR/Bug = enforcing (exit non-zero at CLI; wiki lint refuses).

### §12.4 Enforcement points
- v1: `wiki lint` only. MCP-side `push_item` enforcement is deferred post-PROP-007.
- Staleness: `cached_gate_result.last_gate_check < updated_at` → lint error for ALL types (catches silent hook failures).

### §12.5 Hook lifecycle
- PostToolUse `stamp-and-gate.sh` chains `stamp-tokens → gate check → wiki ingest` on every Write/Edit under `.cleargate/delivery/**`. Exit always 0.
- SessionStart `session-start.sh` pipes `cleargate doctor --session-start` (≤100 LLM-tokens, ≤10 items + overflow pointer) into context.
- Every invocation logs to `.cleargate/hook-log/gate-check.log`; `cleargate doctor` surfaces last-24h failures.

### §12.6 Cross-references
- §4 Phase Gates: "Gate 2 (Ambiguity) is machine-checked via `cleargate gate check`; see §12."
- §10.8 Wiki-lint enforcement: extended by the gate-check hook; staleness check added per §12.4.

---

## 13. Scaffold Manifest & Uninstall

### §13.1 Overview
Three-surface model: package manifest (shipped in `@cleargate/cli`), install snapshot (`.cleargate/.install-manifest.json` written at init), current state (live FS). Drift is classified pairwise into 4 states (clean / user-modified / upstream-changed / both-changed) + `untracked` for user-artifact tier. SHA256 over normalized content (LF / UTF-8 no-BOM / trailing-newline) is the file identifier.

### §13.2 Install
`cleargate init` copies the bundled payload, then writes `.cleargate/.install-manifest.json`:

```json
{
  "cleargate_version": "0.2.0",
  "installed_at": "2026-04-19T10:00:00Z",
  "files": [
    {"path": ".cleargate/knowledge/cleargate-protocol.md", "sha256": "…", "tier": "protocol", "overwrite_policy": "merge-3way", "preserve_on_uninstall": "default-remove"}
  ]
}
```

If a `.cleargate/.uninstalled` marker exists at init time, init prompts "Detected previous ClearGate install … Restore preserved items? [Y/n]". Y = blind-copy preserved paths back into the new install (v1); mismatches log a warning and do not fail.

### §13.3 Drift detection
`cleargate doctor --check-scaffold` compares the three surfaces and writes `.cleargate/.drift-state.json` (daily-throttled refresh). SessionStart-triggered refresh runs at most once per day. Agent never auto-overwrites on upstream-changed drift — it emits a one-line advisory at triage; `cleargate upgrade` is always human-initiated. `user-artifact` tier (sha256: null) is silently skipped in drift output; surfaces only in uninstall preview.

### §13.4 Upgrade
`cleargate upgrade [--dry-run] [--yes] [--only <tier>]` drives a three-way merge for `merge-3way` policy files. Per-file prompt: `[k]eep mine / [t]ake theirs / [e]dit in $EDITOR`. Execution is incremental: successes are committed to disk + `.install-manifest.json` updated before the next file is processed; a mid-run error leaves earlier successes intact.

### §13.5 Uninstall
`cleargate uninstall [--dry-run] [--preserve …] [--remove …] [--yes] [--path <dir>] [--force]` is preservation-first. Defaults: `.cleargate/delivery/archive/**`, `FLASHCARD.md`, `sprint-runs/*/REPORT.md`, `pending-sync/**` → keep. `.cleargate/knowledge/`, `.cleargate/templates/`, `.cleargate/wiki/`, `.cleargate/hook-log/` → remove. Safety rails: typed confirmation (project name), single-target (no recursion into nested `.cleargate/`), refuse on uncommitted manifest-tracked changes without `--force`, CLAUDE.md marker-presence check. Always-removed (no prompt): `.claude/agents/*.md`, ClearGate hooks, `flashcard/` skill, CLAUDE.md CLEARGATE block, `@cleargate/cli` in `package.json`, `.install-manifest.json`, `.drift-state.json`. Writes `.cleargate/.uninstalled` marker:

```json
{
  "uninstalled_at": "2026-04-19T11:00:00Z",
  "prior_version": "0.2.0",
  "preserved": [".cleargate/FLASHCARD.md", ".cleargate/delivery/archive/**"],
  "removed": [".cleargate/knowledge/cleargate-protocol.md"]
}
```

Future `cleargate init` in the same dir detects this marker and offers restore.

### §13.6 Publishing notes
`MANIFEST.json` is built at `npm run build` (prebuild step in `cleargate-cli/package.json`) and shipped in the npm tarball (`files[]`). Never computed at install time. `generate-changelog-diff.ts` diffs `MANIFEST.json` between the previous published version and the current one at release time; CHANGELOG.md auto-opens with a "Scaffold files changed" block per release. Content-identical entries (path-moved-only, metadata-changed-only) are collapsed to avoid noise.

---

## 14. Multi-Participant Sync

### §14.1 Sync matrix & authority split

**Rule:** Remote is authoritative for status, assignees, and comments; local is authoritative for work-item body.

When both sides change the same field, the authoritative side wins without prompt (except body+body — see §14.2). This split prevents accidental overwrites of carefully authored local prose while still tracking PM-tool state transitions faithfully. Source: EPIC-010 §4 authority table; `cleargate-cli/src/commands/sync.ts` conflict-detector snapshot shape.

### §14.2 Conflict resolution

**Rule:** content+content → interactive 3-way merge prompt; status+status → remote-wins silently; delete+edit (either direction) → refuse; unrecognized conflict shape → `halt`.

Nine conflict states are recognized (`content-content`, `status-status`, `remote-delete-local-edit`, `local-delete-remote-edit`, `remote-only`, `local-only`, `remote-status-only`, `local-content-only`, `unknown`). Resolution values are `three-way-merge`, `remote-wins`, `local-wins`, `refuse`, `halt`, `remote-only-apply`, `local-only-apply`. The `halt` resolution surfaces an actionable error rather than silently discarding data. Source: `cleargate-cli/src/lib/conflict-detector.ts`; `cleargate-cli/src/commands/sync.ts:307-367`.

### §14.3 Sync ordering invariant

**Rule:** `cleargate sync` MUST execute pull → classify → resolve → push in that order; reversal amplifies conflicts.

Executing a push before all pulls are complete risks overwriting a remote state change that the local resolve step would have otherwise detected. The 6-step driver enforces this order at the code level; a unit test asserts step ordering as a dataflow invariant. Source: `cleargate-cli/src/commands/sync.ts` driver doc comment (steps 1–6); R2 mitigation.

### §14.4 Identity resolution precedence

**Rule:** `.cleargate/.participant.json` → `CLEARGATE_USER` env → `git config user.email` → `host+user` fallback.

Identity is per-repo, not global, so two participants on the same machine with different `.participant.json` files get distinct attribution. The env var override allows CI or scripted sync. Source: `cleargate-cli/src/lib/identity.ts`; R5 mitigation.

### §14.5 Stakeholder-authored proposal flow

**Rule:** Remote items labeled `cleargate:proposal` (configurable via `CLEARGATE_PROPOSAL_LABEL` env) and absent locally land in `pending-sync/PROPOSAL-NNN-remote-<slug>.md` with `source: "remote-authored"` and `approved: false`.

This prevents external stakeholders from bypassing the approval gate: the proposal arrives locally for human review before any push. The label name is configurable so teams can map to their own PM-tool taxonomy. Source: `cleargate-cli/src/lib/intake.ts`; `cleargate-cli/src/commands/sync.ts:167-183`.

### §14.6 Comment policy

**Rule:** Comments pull as read-only snapshots, active items only (current sprint + last 30 days), rendered under `## Remote comments` with literal-string delimiters. Never pushed upstream.

Pulling comments for stale items wastes tokens and clutters archives; the 30-day window keeps recent feedback visible. The `## Remote comments` block uses byte-stable literal delimiters so repeated pulls are idempotent. A 429 rate-limit on any single item causes that item to be skipped silently. Source: `cleargate-cli/src/lib/wiki-comments-render.ts`; `cleargate-cli/src/lib/active-criteria.ts`; R4/R6 mitigations.

### §14.7 Push preconditions

**Rule:** `cleargate_push_item` requires `payload.approved === true` unless the caller passes `skipApprovedGate: true` (reserved for `sync_status` internal callers). `pushed_by` is stamped from `members.email` via JWT `sub` → member lookup, NOT the raw JWT `sub` value.

The `skipApprovedGate` bypass is an internal escape hatch for status-only updates triggered by `cleargate_sync_status`; it is not exposed as a public CLI flag. The email lookup ensures human-readable attribution independent of UUID-based JWT subjects. Source: `mcp/src/tools/push-item.ts`; flashcard `#mcp #jwt #attribution`.

### §14.8 Revert policy

**Rule:** `cleargate push --revert <id>` soft-reverts by calling `cleargate_sync_status` with `new_status: "archived-without-shipping"`; it never deletes the remote item. `--force` is required when local `status: done`.

Soft revert preserves audit history on the PM-tool side. Refusing to revert done items without `--force` prevents accidental archival of shipped work. Source: `cleargate-cli/src/commands/push.ts` revert branch; `cleargate-cli/src/cli.ts:268-273`.

### §14.9 Sync cadence

**Rule:** All sync actions are manual (`cleargate sync` / `cleargate pull <id>` / `cleargate push <file>`). The SessionStart hook SUGGESTS via `cleargate sync --check` — it never auto-pulls or auto-pushes. MCP probes are throttled to at most one per 24 hours per repo.

Auto-push without human review would bypass the approval gate; auto-pull would overwrite in-progress local edits without conflict detection. The 24-hour throttle prevents session-start latency accumulation. Throttle state is stored in `.cleargate/.sync-marker.json` with schema `{ "last_check": "<ISO-8601>" }` (v1; unknown keys are ignored on read for forward compatibility). Source: `.claude/hooks/session-start.sh`; `.cleargate/.sync-marker.json`; R7 mitigation.

---

## 15. Worktree Lifecycle (v2)

**v1/v2 gating:** Under `execution_mode: v1` the rules in this section are **informational** — they document the intended workflow but are not enforced by any script. Under `execution_mode: v2` they are **mandatory**: every story transition that would run a Developer agent MUST follow these procedures before any file edits begin.

### §15.1 Branch hierarchy

The branch hierarchy for a sprint is:

```
main
└── sprint/S-XX          ← cut at sprint start; never commit directly
    └── story/STORY-NNN-NN   ← cut when story transitions Ready → Bouncing
```

- **Sprint branch** is cut from `main` once at the start of each sprint:
  ```bash
  git checkout -b sprint/S-XX main
  ```
- **Story branch** is cut from the active sprint branch when the story enters `Bouncing` state:
  ```bash
  git checkout sprint/S-XX
  git checkout -b story/STORY-NNN-NN sprint/S-XX
  ```
- Story branches are **never** cut from `main` directly; they always track the sprint branch as parent.

### §15.2 Worktree commands

Per-story working trees live under `.worktrees/` at repo root. Each story gets its own isolated filesystem view.

**Create worktree (story starts bouncing):**
```bash
git worktree add .worktrees/STORY-NNN-NN -b story/STORY-NNN-NN sprint/S-XX
```

**Verify worktree:**
```bash
git worktree list
# .../repo            <sha>  [sprint/S-XX]
# .../repo/.worktrees/STORY-NNN-NN  <sha>  [story/STORY-NNN-NN]
```

**Merge story back into sprint branch (story passes QA + Architect):**
```bash
git checkout sprint/S-XX
git merge story/STORY-NNN-NN --no-ff -m "merge(story/STORY-NNN-NN): STORY-NNN-NN <title>"
```

**Remove worktree and story branch (after successful merge):**
```bash
git worktree remove .worktrees/STORY-NNN-NN
git branch -d story/STORY-NNN-NN
```

**Prune stale worktree refs:**
```bash
git worktree prune
```

All commands must be run from the **repo root** (not from inside `.worktrees/`), except Developer Agent file edits which happen inside the assigned worktree path.

### §15.3 MCP nested-repo rule

**The `mcp/` directory is a nested independent git repository.** Running `git worktree add` inside `mcp/` would create a worktree scoped to the nested repo, not to the outer ClearGate repo. This is a git footgun: the outer repo cannot track, merge, or remove the inner worktree via its own git commands.

**Rule:** Never run `git worktree add` inside `mcp/`. If a story requires edits to `mcp/`, the Developer Agent must edit `mcp/` from inside the outer worktree (`.worktrees/STORY-NNN-NN/mcp/...`) — the nested repo's files are visible there as a subdirectory, not as a separate git context. MCP-native worktree support is deferred to Q3.

### §15.4 Local state.json is in-flight authority

During a story's execution, `state.json` at `.cleargate/sprint-runs/<sprint-id>/state.json` is the single source of truth for story state. The MCP server is a **post-facto audit** channel: it receives state updates after each transition but is never consulted during execution. If MCP is unavailable, execution continues uninterrupted; state.json records the ground truth that MCP will eventually replicate. (Source: EPIC-013 Q7 resolution.)

### §15.5 Enforcement gates

| `execution_mode` | These rules are |
|---|---|
| `v1` | Informational — document intended workflow; not script-enforced |
| `v2` | Mandatory — `validate_bounce_readiness.mjs` checks worktree isolation before any Developer Agent edit |

Under v2, attempting to run a Developer Agent on a story without a matching `.worktrees/STORY-NNN-NN/` path present causes `validate_bounce_readiness.mjs` to exit non-zero and the orchestrator to halt the story transition.

---

## 16. User Walkthrough on Sprint Branch (v2)

**v1/v2 gating:** Under `execution_mode: v1` this section is **informational**. Under `execution_mode: v2` it is **mandatory**: the sprint branch MUST NOT merge to `main` until the walkthrough is complete and all `UR:bug` items are resolved.

### §16.1 Walkthrough trigger

After all stories in the sprint are merged into `sprint/S-XX` (every story state ∈ `TERMINAL_STATES`) and before `sprint/S-XX` merges to `main`, the orchestrator invites the user to test the running application on the sprint branch.

### §16.2 Feedback classification

User feedback during the walkthrough is classified into exactly two event types:

| Event type | Definition | Bug-Fix Tax effect |
|---|---|---|
| `UR:review-feedback` | Enhancement, polish, copy change, or UX preference — does NOT fix broken behavior | Does NOT increment Bug-Fix Tax |
| `UR:bug` | Defect, crash, wrong output, or behavior broken relative to spec | DOES increment Bug-Fix Tax |

**Classification rule:** when in doubt, ask the user one targeted question — "Is this broken relative to spec, or a preference?" Do not default to `UR:bug`.

### §16.3 Logging

Each piece of walkthrough feedback MUST be logged in the sprint markdown file under `## 4. Execution Log` with the event prefix:

```
UR:review-feedback 2026-04-21 — copy should say "Sign in" not "Log in" (resolved: STORY-013-09-dev.md commit abc123)
UR:bug 2026-04-21 — create-project button 500s on submit (resolved: STORY-013-10-dev.md commit def456)
```

### §16.4 Resolution gate

The sprint branch MUST NOT merge to `main` while any `UR:bug` item is unresolved. `UR:review-feedback` items MAY be deferred to the next sprint with orchestrator + user acknowledgment logged.

---

## 17. Mid-Sprint Change Request Triage (v2)

**v1/v2 gating:** Under `execution_mode: v1` this section is **informational**. Under `execution_mode: v2` it is **mandatory**: every user-injected change during a bounce MUST be classified before routing.

### §17.1 Classification table

When the user injects new input during a QA bounce or active story execution, the orchestrator classifies the input into one of four categories:

| Event type | Definition | Bounce-counter effect | Routing |
|---|---|---|---|
| `CR:bug` | Defect introduced by the current story's implementation | Counts toward Bug-Fix Tax; increments `qa_bounces` | Re-open story; Developer fixes; QA re-verifies |
| `CR:spec-clarification` | Clarification of existing spec — no new scope, removes ambiguity | Does NOT increment any bounce counter | Update story acceptance criteria in place; re-run impacted test |
| `CR:scope-change` | Net-new requirement or expansion of story scope | Deferred: create a new Story in `pending-sync/`; current story continues unchanged | New Story ID assigned; current bounce counter unaffected |
| `CR:approach-change` | Switch implementation approach without changing functional spec | Does NOT increment bounce counter; resets Developer context | Re-spawn Developer with updated approach note; same story ID |

### §17.2 Logging

Each mid-sprint CR MUST be logged in the sprint markdown file under `## 4. Execution Log` with the event prefix:

```
CR:spec-clarification 2026-04-21 — endpoint must return project slug (clarified in STORY-013-05 §1.2; no new scope)
CR:scope-change 2026-04-21 — user requests audit log table (new STORY-013-11 created in pending-sync/)
```

### §17.3 Scope-change quarantine

A `CR:scope-change` MUST NOT be folded into the current story's commit. Create a new Story file and handle in a future sprint or as a mid-sprint addition (requires orchestrator + user explicit sign-off to add mid-sprint).

---

## 18. Immediate Flashcard Gate (v2)

**v1/v2 gating:** Under `execution_mode: v1` this section is **informational** — the gate is advisory and the orchestrator may proceed without processing flagged cards (though it is strongly encouraged). Under `execution_mode: v2` it is **mandatory**: the orchestrator MUST NOT create the next story's worktree until all `flashcards_flagged` entries from the prior story's dev + QA reports are processed.

**V-Bounce reference:** `skills/agent-team/SKILL.md` §"Step 5.5: Immediate Flashcard Recording (Hard Gate)" at pinned SHA `2b8477ab65e39e594ee8b6d8cf13a210498eaded`.

### §18.1 Trigger

After story N's commit merges into `sprint/S-XX` and QA approves, the orchestrator collects `flashcards_flagged` from both:
- `STORY-NNN-NN-dev.md` (Developer Agent output report)
- `STORY-NNN-NN-qa.md` (QA Agent output report)

The two lists are merged (union, deduplication by exact string match). If the combined list is empty, the gate passes immediately.

### §18.2 Processing rule

For each entry in the merged `flashcards_flagged` list, the orchestrator MUST take exactly one of two actions before creating story N+1's worktree:

| Action | Effect | Record location |
|---|---|---|
| **Approve** | Append the one-liner verbatim to `.cleargate/FLASHCARD.md` (newest-first, per SKILL.md format) | The card itself is the record |
| **Reject** | Discard the entry — do NOT append to `FLASHCARD.md` | Sprint §4 Execution Log: `FLASHCARD-REJECT YYYY-MM-DD — "<card text>" — reason: <one sentence>` |

### §18.3 Worktree creation gate

The orchestrator MUST NOT run `git worktree add .worktrees/STORY-NNN-NN ...` for story N+1 until the §18.2 processing loop is complete (every entry either approved or rejected). This is a blocking serial step, not a background task.

### §18.4 Cards format

Each entry in `flashcards_flagged` MUST conform to the format required by `.claude/skills/flashcard/SKILL.md`:

```
YYYY-MM-DD · #tag1 #tag2 · lesson ≤120 chars
```

The orchestrator may reformat an entry that violates the format before appending, but must log the reformat in sprint §4 Execution Log.

### §18.5 v1 dogfood note

SPRINT-09 runs under `execution_mode: v1`. From STORY-013-06 merge onwards, the orchestrator applies the §18.2 processing loop manually as a dogfood check even though the rule is informational. This is recorded in the SPRINT-09 sprint plan (line 121).

### §18.6 PreToolUse hook enforcement (v2)

Under `execution_mode: v2`, the `pending-task-sentinel.sh` PreToolUse hook automatically enforces the flashcard gate before every Task (subagent) dispatch. This is implemented by STORY-014-03.

**Hash-marker convention:**

Each `flashcards_flagged` card is identified by the first 12 hexadecimal characters of its SHA-1 hash (computed with `shasum -a 1`):

```bash
HASH="$(printf '%s' "<card text>" | shasum -a 1 | cut -c1-12)"
```

Hash stability: the same card string always produces the same hash. The hash is computed over the exact card string as it appears in the report's `flashcards_flagged` list (after stripping surrounding quotes).

**Processed marker:**

To mark a card as processed (approved or rejected by the orchestrator), touch the marker file:

```bash
touch .cleargate/sprint-runs/<sprint-id>/.processed-<hash>
```

The marker files are gitignored via the existing `.cleargate/sprint-runs/` gitignore rule and serve only as local bookkeeping.

**Enforcement logic:**

1. The hook globs `SPRINT_DIR/STORY-*-dev.md` and `SPRINT_DIR/STORY-*-qa.md` (flat layout — no `reports/` subdirectory).
2. For each report file, it parses the `flashcards_flagged:` YAML list (inline `[]` and block `- "text"` forms both supported).
3. For each card, it computes the 12-char SHA-1 hash and checks for the `.processed-<hash>` marker in `SPRINT_DIR`.
4. If any card is unprocessed:
   - **v2**: exits non-zero (blocks Task spawn) with stderr listing each unprocessed card and the `touch` command hint.
   - **v1**: prints an advisory warning to stderr and exits 0 (does not block).
5. If `flashcards_flagged: []` or no report files exist, the gate passes immediately.

**Bypass:**

Set `SKIP_FLASHCARD_GATE=1` in the environment to bypass the gate entirely (both v1 and v2). This bypass is intended for CI and bootstrap scenarios where the hook runs without sprint context. Bypasses should be disabled once M1 is closed; the orchestrator tracks this in the sprint §4 Execution Log.

---

## 19. Execution Mode Routing (v2)

The `execution_mode` field in a Sprint Plan's frontmatter is the single switch that controls whether §§15–18 of this protocol are **enforcing** or **advisory** for that sprint.

### §19.1 Flag semantics

| `execution_mode` value | Effect |
|---|---|
| `"v1"` | All §§15–18 rules are **advisory** — document intended workflow; no CLI or script enforcement. New CLI commands (`sprint init|close`, `story start|complete`, `gate qa|arch`, `state update|validate`) print an inert-mode message and exit 0. |
| `"v2"` | All §§15–18 rules are **mandatory** — CLI wrappers route to `run_script.sh` scripts; worktree isolation, pre-gate scanning, bounce counters, flashcard gate, and sprint-close pipeline are all enforced. |

### §19.2 Sprint-scoped flag

The `execution_mode` flag is **sprint-scoped**, not global. A project may run SPRINT-10 on `v2` while SPRINT-11 planning files default to `v1` until the Architect completes a Sprint Design Review (§15.1). Setting the flag on one sprint has no effect on any other sprint file.

### §19.3 Orchestrator routing rule

Before spawning any Developer, QA, or Reporter agent, the orchestrator MUST:

1. Locate the active sprint file at `.cleargate/delivery/pending-sync/SPRINT-{ID}_*.md` (or the archived equivalent).
2. Read the `execution_mode` frontmatter field. If absent, treat as `"v1"`.
3. If `"v1"`: proceed with advisory-only loop. §§15–18 rules are informational.
4. If `"v2"`: enforce §§15–18 before each agent spawn as mandatory gates.

### §19.4 CLI inert-mode message

When a v2-only CLI command is invoked and the active sprint's `execution_mode` is `"v1"`, the CLI MUST print exactly:

```
v1 mode active — command inert. Set execution_mode: v2 in sprint frontmatter to enable.
```

and exit 0. No subprocess is spawned. This preserves backward compatibility for users who have not yet migrated to v2.

### §19.5 Default value

The default value is `"v1"`. All sprint plans generated from the Sprint Plan Template default to `execution_mode: "v1"` until explicitly flipped. The flag should only be set to `"v2"` after all M2 EPIC-013 stories have shipped and the Architect has completed a Sprint Design Review (§15.1).

---

## 20. File-Surface Contract (v2)

Under `execution_mode: v2`, each story's §3.1 "Context & Files" table is the **authoritative file surface** for that story's commit. The pre-commit hook enforces this contract automatically.

### §20.1 Rule

A Developer agent MUST NOT stage and commit any file not declared in the active story's §3.1 table, unless that file matches a whitelist entry in `.cleargate/scripts/surface-whitelist.txt`.

Off-surface edits require one of:
1. A CR:scope-change item approved before the commit, OR
2. An updated §3.1 table committed in the same story (self-amending surface — rare, must be explicitly justified in the commit message).

### §20.2 Hook mechanics

The gate runs as `.cleargate/scripts/file_surface_diff.sh` invoked via `.claude/hooks/pre-commit-surface-gate.sh` and dispatched from `.claude/hooks/pre-commit.sh`. The dispatcher is symlinked to `.git/hooks/pre-commit`.

- Under v2: off-surface files cause a non-zero exit — the commit is blocked.
- Under v1: the hook prints a warning but exits 0 (advisory only).
- `SKIP_SURFACE_GATE=1` env variable bypasses the gate entirely (use sparingly; log bypass in sprint §4 Execution Log).

### §20.3 §3.1 table contract

The §3.1 table in `story.md` template uses a two-column `| Item | Value |` pipe table. The parser:
- Scans between the `### 3.1` heading and the next `### ` heading.
- Only processes rows where the Value cell contains `.` or `/` (path-shaped values).
- Strips backticks from values.
- Splits on `, ` to handle multiple paths in one cell.
- Ignores header and separator rows.

Non-path rows (e.g., "Mirrors", "New Files Needed: Yes/No") are silently skipped.

### §20.4 Whitelist

`.cleargate/scripts/surface-whitelist.txt` declares auto-generated files that are always admitted regardless of story surface. Seed entries include: `cleargate-planning/MANIFEST.json`, `.cleargate/hook-log/*`, `.cleargate/sprint-runs/**/token-ledger.jsonl`, `.cleargate/sprint-runs/**/.pending-task-*.json`, `.cleargate/sprint-runs/**/state.json`.

### §20.5 Install (dogfood)

On `cleargate init`, the scaffold automatically installs the `.git/hooks/pre-commit` symlink. For existing dogfood repositories, install once by hand:

```bash
ln -sf ../../.claude/hooks/pre-commit.sh .git/hooks/pre-commit
```

Log this step in the sprint §4 Execution Log.

---

## 21. Status Vocabulary

Raw work-item frontmatter `status:` values must be drawn from this canonical set:

| Status | Meaning |
|---|---|
| `Draft` | Newly authored; not yet ambiguity-gated |
| `Ready` | Ambiguity gate passed; eligible for sprint planning |
| `Approved` | Epic approved for execution |
| `Planned` | Sprint planned; not yet started |
| `Active` | Work in progress |
| `Completed` | Shipped (sprints, epics) |
| `Done` | Shipped (stories) — treated as alias of `Completed` for terminal-status checks |
| `Abandoned` | Work deliberately stopped without shipping. The artifact stays in `archive/` for historical record. Not eligible for the Active index. |
| `Closed` | Closed without shipping (administrative close) |
| `Resolved` | Bug or CR confirmed resolved |

### §21.1 Index Token Ceiling

`cleargate wiki lint` enforces a ceiling on `.cleargate/wiki/index.md` size, measured as `bytes ÷ 4` approximate tokens. Default ceiling: `8000`. Override via `.cleargate/config.yml`:

```yaml
wiki:
  index_token_ceiling: 8000
```

Exceeding the ceiling fails `cleargate wiki lint` (enforcement mode). Under `--suggest`, the usage percentage is reported but the check does not fail. Reference: EPIC-015.

---

## 22. Advisory Readiness Gates on Push (v2) — CR-010

### §22.1 Two-tier push gate semantics

Push-time gate enforcement uses two distinct tiers:

**Tier 1 — `approved: true` (hard reject, unchanged):**
`cleargate_push_item` throws `PushNotApprovedError` when `payload.approved !== true`. This is the human go/no-go gate. No advisory mode or env knob overrides it.

**Tier 2 — `cached_gate_result` (advisory by default):**
When `cached_gate_result.pass === false`, the push proceeds in default advisory mode. The pushed item's body receives a single advisory prefix line placed immediately after the H1 heading (or as the first line if no H1 exists):

```
[advisory: gate_failed — <comma-separated criterion ids>]
```

Body content beyond the advisory prefix is byte-identical to the input. The push result includes `gate_status: 'open'` and `failing_criteria: [...]` as response metadata (not persisted to the DB schema).

### §22.2 Strict-mode opt-in and audit log

Set `STRICT_PUSH_GATES=true` on the MCP server to restore pre-CR-010 hard-reject behavior (`PushGateFailedError`, no DB write). Default: `false` (advisory mode).

Advisory pushes (gate_status='open') are recorded in `audit_log` with `result='ok'` — the push succeeded. The `failing_criteria` are surfaced in the push response shape, not in a new audit column. No schema migration is required.
**Rationale:** PM-tool answer-collection requires items to land before readiness answers arrive; advisory mode enables this. See CR-010 §0 for full evidence.

---

## 23. Doctor Exit-Code Semantics

`cleargate doctor` exits with one of three codes (all modes: default, `--session-start`, `--can-edit`, `--check-scaffold`, `--pricing`). Hooks branch on the integer, not on stdout.
- `0` — clean. No blockers, no config errors. Stdout MAY include informational lines.
- `1` — blocked items or advisory issues (gate failures, stamp errors, drifted SHAs, missing ledger rows). Stdout lists each blocker.
- `2` — ClearGate misconfigured or partially installed (missing `.cleargate/`, missing `MANIFEST.json`, missing `auth.json`, hook resolver failure). Stdout emits a remediation hint. See `cleargate doctor --help`.

---

## 24. Lane Routing

A story is eligible for `lane: fast` only if all seven checks pass (any false → `standard`):
1. **Size cap.** ≤2 files AND ≤50 LOC net (tests count; generated files do not).
2. **No forbidden surfaces.** Story does not modify: `mcp/src/db/` / `**/migrations/` (schema); `mcp/src/auth/` / `mcp/src/admin-api/auth-*` (auth); `cleargate.config.json` / `mcp/src/config.ts` (runtime config); `mcp/src/adapters/` (adapter API); `cleargate-planning/MANIFEST.json` (scaffold manifest); security-relevant code (token handling, invite verification, gate enforcement).
3. **No new dependency.** No new package added to any `package.json`.
4. **Single acceptance scenario or doc-only.** Exactly one `Scenario:` block (or zero for doc-only). `Scenario Outline:` or multiple scenarios → `standard`.
5. **Existing tests cover the runtime change.** Named test file exists and includes the affected module, OR story is doc/comment/non-runtime config only.
6. **`expected_bounce_exposure: low`.** `med` or `high` is auto-`standard`.
7. **No epic-spanning subsystem touches.** All affected files live under the parent epic's declared scope directories.

**Demotion mechanics.** Demotion is one-way (`fast → standard`). Trigger: pre-gate scanner failure OR post-merge test failure on a fast-lane story. On demotion: set `lane = "standard"`, write `lane_demoted_at` (ISO-8601), `lane_demotion_reason`, reset `qa_bounces = 0` and `arch_bounces = 0` (see STORY-022-02 schema). Architect plan is invoked and QA spawned per standard contract.

Event-type `LD` (Lane Demotion) is recorded in sprint markdown §4 alongside existing `UR` and `CR` events; Reporter aggregates into §3 Execution Metrics > Fast-Track Demotion Rate.
