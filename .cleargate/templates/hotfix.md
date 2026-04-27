---
hotfix_id: "{ID}"
status: "Draft"
severity: "P2"
originating_signal: "user-report"
created_at: "{ISO}"
created_at_version: "cleargate@0.5.0"
merged_at: null
commit_sha: null
verified_by: null
lane: "hotfix"
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
pushed_by: null
pushed_at: null
last_pulled_by: null
last_pulled_at: null
last_remote_update: null
source: "local-authored"
last_synced_status: null
last_synced_body_sha: null
---

# {ID}: {SLUG}

## 1. Anomaly

**Expected Behavior:** {What the system should do under normal conditions.}

**Actual Behavior:** {What it is doing now — the observed deviation.}

## 2. Files Touched

Hotfix discipline: ≤2 files, ≤30 LOC net (EPIC-022 §3).

- `{path/to/file.ts}` — {brief description of change}

## 3. Verification Steps

> Rule: §3 must be non-empty before merging. An empty §3 blocks merge at review time.

1. - [ ] {Step 1: describe what to run or observe}
2. - [ ] {Step 2: confirm the anomaly is resolved}
3. - [ ] {Step 3: confirm no regression in adjacent behavior}

## 4. Rollback

If the hotfix introduces a regression, revert by running `git revert <commit-sha>` on the sprint or main branch. The original anomaly will reappear; escalate to a sprint story for a permanent fix. No data migrations are involved unless noted in §2 above.
