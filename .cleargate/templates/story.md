<instructions>
FOLLOW THIS EXACT STRUCTURE. Output sections in order 1-4.
YAML Frontmatter: Story ID, Parent Epic, Status, Ambiguity, Context Source (MUST link to approved proposal.md), Actor, Complexity Label.
§1 The Spec: User Story + Detailed Requirements + Out of Scope.
§2 The Truth: Gherkin acceptance criteria + manual verification steps.
§3 Implementation Guide: Files to modify, technical logic, API contract. Sourced from approved proposal.md.
§4 Quality Gates: Minimum test expectations + Definition of Done checklist.
Output location: .cleargate/delivery/pending-sync/STORY-{EpicID}-{StoryID}-{StoryName}.md

Document Hierarchy Position: LEVEL 2 (Proposal → Epic → Story)

Complexity Labels:
L1: Trivial — Single file, <1hr, known pattern
L2: Standard — 2-3 files, known pattern, ~2-4hr (default)
L3: Complex — Cross-cutting, spike may be needed, ~1-2 days
L4: Uncertain — Requires probing/spiking, >2 days

Granularity Rubric (run this check BEFORE emitting a story during epic-decomposition):
A candidate story is too big — emit two stories instead, with consecutive IDs (e.g. STORY-007-03 and STORY-007-04, never 03a/03b) — if ANY signal trips:
  • §1.2 Detailed Requirements joins unrelated user goals with "and also" / "additionally".
  • §2.1 Gherkin would need >5 scenarios covering unrelated behaviors.
  • §3.1 Files-to-touch span unrelated subsystems (e.g. API + UI + migration in one story).
  • Complexity would land at L4 (>2 days). L4 is a planning smell — split, or carve out a spike as its own story.
  • `complexity_label: L3` AND `expected_bounce_exposure: high`. L3+high consistently hits developer-agent wall-time limits (observed in SPRINT-09 on STORY-013-02/03/04, all Sonnet 4.6 stream-timeouts). Split into two L2 stories OR escalate the single L3 to Opus at dispatch — the decomposition default is to split.
Also split the inverse: two candidate stories that each touch the same 1-2 files with overlapping scenarios should merge into one L1/L2.
At epic-decomposition time there are no remote IDs yet — splits and merges are free. Prefer two focused L1/L2 stories over one L3. Prefer L3 over L4.
When the rubric is ambiguous, surface the decision to the human as a one-liner ("candidate covers A+B — split into X and Y?") rather than guessing.

§0.1 v2 Decomposition Signals:
  `parallel_eligible`: "y" if this story can run concurrently with other stories in the same milestone; "n" if it has a strict predecessor dependency. Default "y". Set by Architect during Sprint Design Review.
  `expected_bounce_exposure`: "low" | "med" | "high" — predicted re-work risk derived from §2.1 scenario count + §3 file-count + ambiguity level. Default "low". Set by Architect. Used by orchestrator to sequence high-exposure stories before low-exposure ones in a v2 sprint to surface risk early.
  `lane`: "standard" | "fast" — Architect-set during Sprint Design Review per the seven-check rubric in protocol §24. Default "standard". Absent in pre-EPIC-022 stories means standard per the migration default in update_state.mjs.
  All three fields are v2-only signals. Under v1 sprints they are informational; defaults apply for stories authored before SPRINT-09.

Do NOT output these instructions.
</instructions>

---
story_id: "STORY-{EpicID}-{StoryID}-{StoryName}"
parent_epic_ref: "EPIC-{ID}"
status: "Draft"
ambiguity: "🔴 High"
context_source: "PROPOSAL-{ID}.md"
actor: "{Persona Name}"
complexity_label: "L2"
parallel_eligible: "y"
expected_bounce_exposure: "low"
lane: "standard"
created_at: "2026-04-17T00:00:00Z"
updated_at: "2026-04-17T00:00:00Z"
created_at_version: "strategy-phase-pre-init"
updated_at_version: "strategy-phase-pre-init"
server_pushed_at_version: null
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
# Sync attribution (EPIC-010). Optional; stamped by `cleargate push` / `cleargate pull`.
pushed_by: null            # STORY-010-07 writer / STORY-010-04 reader
pushed_at: null            # STORY-010-07 writer / STORY-010-04 reader
last_pulled_by: null       # STORY-010-04 writer / STORY-010-03 reader
last_pulled_at: null       # STORY-010-04 writer / STORY-010-03 reader
last_remote_update: null   # STORY-010-02 writer (from MCP) / STORY-010-03 reader
source: "local-authored"   # STORY-010-05 flips to "remote-authored" on intake
last_synced_status: null   # STORY-010-04 writer; required for conflict-detector rule 6
last_synced_body_sha: null # STORY-010-04 writer; sha256 of body at last sync
---

# STORY-{EpicID}-{StoryID}: {Story Name}
**Complexity:** {L1/L2/L3/L4} — {brief description}

## 1. The Spec (The Contract)

### 1.1 User Story
As a {Persona}, I want to {Action}, so that {Benefit}.

### 1.2 Detailed Requirements
- Requirement 1: {Specific behavior}
- Requirement 2: {Specific data or constraint}

### 1.3 Out of Scope
{What this story explicitly does NOT do.}

## 2. The Truth (Executable Tests)

### 2.1 Acceptance Criteria (Gherkin)

```gherkin
Feature: {Story Name}

  Scenario: {Happy Path}
    Given {precondition}
    When {user action}
    Then {system response}

  Scenario: {Edge Case / Error}
    Given {precondition}
    When {invalid action}
    Then {error message}
```

### 2.2 Verification Steps (Manual)
- [ ] {e.g., "Verify API returns 200 for valid input"}
- [ ] {e.g., "Verify UI renders correctly on mobile"}

## 3. The Implementation Guide

### 3.1 Context & Files

> **v2 gate input:** under v2 execution mode, this table is a pre-commit gate input (protocol §20). Every file staged in this story's commit must appear in the Value column, or be covered by `.cleargate/scripts/surface-whitelist.txt`. Non-path rows (e.g. "Mirrors", "New Files Needed: Yes/No") are ignored by the parser.

| Item | Value |
|---|---|
| Primary File | `{filepath/to/main/component.ts}` |
| Related Files | `{filepath/to/api/service.ts}`, `{filepath/to/types.ts}` |
| New Files Needed | Yes/No — {Name of file} |

### 3.2 Technical Logic
{Describe the logic flow, e.g., "Use the existing useAuth hook to check permissions."}

### 3.3 API Contract (if applicable)

| Endpoint | Method | Auth | Request Shape | Response Shape |
|---|---|---|---|---|
| `/api/resource` | GET/POST | Bearer/None | `{ id: string }` | `{ status: string }` |

## 4. Quality Gates

### 4.1 Minimum Test Expectations

| Test Type | Minimum Count | Notes |
|---|---|---|
| Unit tests | {N} | {e.g., "1 per exported function"} |
| E2E / acceptance tests | {N} | {e.g., "1 per Gherkin scenario in §2.1"} |

### 4.2 Definition of Done (The Gate)
- [ ] Minimum test expectations (§4.1) met.
- [ ] All Gherkin scenarios from §2.1 covered.
- [ ] Peer/Architect Review passed.

---

## ClearGate Ambiguity Gate (🟢 / 🟡 / 🔴)
**Current Status: 🔴 High Ambiguity**

Requirements to pass to Green (Ready for Execution):
- [ ] Gherkin scenarios completely cover all detailed requirements in §1.2.
- [ ] Implementation Guide (§3) maps to specific, verified file paths from the approved proposal.
- [ ] No "TBDs" exist anywhere in the specification or technical logic.
