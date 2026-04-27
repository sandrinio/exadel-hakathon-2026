<instructions>
This is a READ artifact. It is written by cleargate_pull_initiative when syncing a Sprint from the remote PM tool.
Do NOT draft this file manually. Do NOT invoke cleargate_push_item on this file.
The Vibe Coder may annotate the "Execution Guidelines" section locally — this section is never pushed.
Output location: .cleargate/plans/SPRINT-{ID}.md
Do NOT output these instructions.

§1 Lane column placement: "Lane" is inserted between "Title" and "Milestone" in the Consolidated Deliverables
table (§1). This positions lane as a planning signal adjacent to the story title, which is where the Architect
most naturally reads it during Sprint Design Review. Values are "standard" (default) or "fast" (see protocol §24).

§2.4 Lane Audit: The Architect populates one row per fast-lane story during Sprint Design Review. Empty by default.
Rows are added only for non-`standard` lanes. The subsection is numbered 2.4; the former §2.4 ADR-Conflict Flags
is renumbered to §2.5.
</instructions>

---
sprint_id: "SPRINT-{ID}"
remote_id: "{PM_TOOL_SPRINT_ID}"
source_tool: "linear | jira"
status: "Draft | Active | Completed"
execution_mode: "v1"   # Enum: "v1" | "v2". Default "v1". Under "v2", §§15–18 of cleargate-protocol.md are enforcing (worktree isolation, pre-gate scanning, bounce counters, flashcard gate, sprint-close pipeline). Under "v1", those sections are advisory only and all new CLI commands (sprint init|close, story start|complete, gate qa|arch, state update|validate) print an inert-mode message. Set to "v2" only after all EPIC-013 M2 stories have shipped and the Architect has completed a Sprint Design Review (see §19 of the protocol).
start_date: "{YYYY-MM-DD}"
end_date: "{YYYY-MM-DD}"
synced_at: "{ISO-8601 timestamp}"
created_at: "2026-04-17T00:00:00Z"
updated_at: "2026-04-17T00:00:00Z"
created_at_version: "strategy-phase-pre-init"
updated_at_version: "strategy-phase-pre-init"
draft_tokens:
  input: null
  output: null
  cache_read: null
  cache_creation: null
  model: null
  sessions: []
cached_gate_result:
  pass: null
  failing_criteria: []
  last_gate_check: null
---

# SPRINT-{ID}: {Sprint Number / Name}

## Sprint Goal
{One clear sentence describing the primary objective of this sprint, as defined in the PM tool.}

## 1. Consolidated Deliverables
*(Pulled from PM tool. IDs are the remote PM entity IDs.)*

| Story ID | Title | Lane | Milestone | Parallel? | Bounce Exposure |
|---|---|---|---|---|---|
| `{STORY-NNN-NN}` | {Title} | standard / fast | M{N} | y / n | low / med / high |

## 2. Execution Strategy
*(Written by Architect during Sprint Design Review. Required before `execution_mode: v2` sprint start. Under v1, this section may be omitted or left as a stub.)*

### 2.1 Phase Plan
{Parallel vs sequential story groups. List which stories run concurrently in each wave and which must be serialized.}
Example:
- Wave 1 (sequential): STORY-NNN-01 → STORY-NNN-02 (02 depends on 01's schema)
- Wave 2 (parallel): STORY-NNN-03 ‖ STORY-NNN-04

### 2.2 Merge Ordering (Shared-File Surface Analysis)
{List files touched by more than one story. For each shared file, specify which story lands first and why.}

| Shared File | Stories Touching It | Merge Order | Rationale |
|---|---|---|---|
| `.cleargate/knowledge/cleargate-protocol.md` | STORY-NNN-01, STORY-NNN-02 | 01 → 02 | 01 adds §16; 02 amends §16 |

### 2.3 Shared-Surface Warnings
{Explicit conflict risks. One bullet per risk. Cite file + story pair.}
- None identified. (Replace with actual warnings if applicable.)

### 2.4 Lane Audit
{Architect populates one row per fast-lane story during Sprint Design Review. Empty by default — rows added only for non-`standard` lanes.}

| Story | Lane | Rationale (≤80 chars) |
|---|---|---|
| `STORY-NNN-NN` | fast | <one-line rationale> |

### 2.5 ADR-Conflict Flags
{Any story whose implementation conflicts with an Architectural Decision Record in `.cleargate/knowledge/` or prior sprint decisions. One bullet per flag.}
- None identified. (Replace with actual flags if applicable.)

## Risks & Dependencies
*(As defined in the PM tool.)*

| Risk | Mitigation |
|---|---|
| {Description} | {Action} |

## Metrics & Metadata
- **Expected Impact:** {e.g., performance improvement %, specific user outcome}
- **Priority Alignment:** {Notes on prioritization from the PM tool}

---

## Execution Guidelines (Local Annotation — Not Pushed)
*(Vibe Coder: Fill this in locally to direct Claude Code during the Execution Phase. This section never syncs to the PM tool.)*

- **Starting Point:** {Which deliverable to tackle first and why}
- **Relevant Context:** {Key documentation or codebase areas to reference}
- **Constraints:** {Specific technical boundaries or "out of scope" rules for this sprint}
