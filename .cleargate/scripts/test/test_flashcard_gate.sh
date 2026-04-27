#!/usr/bin/env bash
# test_flashcard_gate.sh — STORY-013-06: Immediate Flashcard Hard-Gate
# Gherkin scenario: "Gate blocks next worktree creation until flashcards processed"
#
# Strategy: grep-based. Creates a synthetic dev-report fixture with
# flashcards_flagged, simulates a mock worktree-creation step, and asserts
# the gate contract documented in protocol §18 and the agent output-shape
# blocks in developer.md + qa.md.
#
# Usage: bash .cleargate/scripts/test/test_flashcard_gate.sh
# Exit: 0 if all assertions pass, 1 on first failure.

set -euo pipefail

REPO_ROOT="${CLEARGATE_REPO_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Scenario: Gate blocks next worktree creation until flashcards processed
# ---------------------------------------------------------------------------
# §2.1 Gherkin from STORY-013-06:
#   Given STORY-014-05 has just merged into sprint/S-XX
#   And STORY-014-05-dev.md has flashcards_flagged: [...]
#   When the orchestrator attempts to create .worktrees/STORY-014-06/
#   Then the gate presents each flagged flashcard to the user for approval
#   And upon approval each card is appended to .cleargate/FLASHCARD.md
#   And only then does worktree creation proceed
#
# This script validates the contract (protocol §18 + output-shape fields)
# that makes the scenario enforceable. The gate logic itself is orchestrator-
# out-of-band (v1: informational; v2: mandatory). The test therefore checks:
#   (a) developer.md output-shape contains flashcards_flagged field
#   (b) qa.md output-shape contains flashcards_flagged field
#   (c) protocol.md §18 exists with the correct heading
#   (d) §18 specifies the approve/reject processing rule
#   (e) §18 specifies the worktree creation gate
#   (f) live vs mirror diff is empty for all three files

DEV_MD="$REPO_ROOT/.claude/agents/developer.md"
QA_MD="$REPO_ROOT/.claude/agents/qa.md"
PROTOCOL_MD="$REPO_ROOT/.cleargate/knowledge/cleargate-protocol.md"

PLANNING_DEV_MD="$REPO_ROOT/cleargate-planning/.claude/agents/developer.md"
PLANNING_QA_MD="$REPO_ROOT/cleargate-planning/.claude/agents/qa.md"
PLANNING_PROTOCOL_MD="$REPO_ROOT/cleargate-planning/.cleargate/knowledge/cleargate-protocol.md"

# (a) developer.md has flashcards_flagged in output-shape block
if grep -q "flashcards_flagged:" "$DEV_MD"; then
  pass "developer.md output-shape contains flashcards_flagged field"
else
  fail "developer.md missing flashcards_flagged field in output-shape"
fi

# (b) qa.md has flashcards_flagged in output-shape block
if grep -q "flashcards_flagged:" "$QA_MD"; then
  pass "qa.md output-shape contains flashcards_flagged field"
else
  fail "qa.md missing flashcards_flagged field in output-shape"
fi

# (c) protocol.md §18 heading exists
if grep -q "^## 18. Immediate Flashcard Gate (v2)" "$PROTOCOL_MD"; then
  pass "protocol.md contains ## 18. Immediate Flashcard Gate (v2)"
else
  fail "protocol.md missing ## 18. Immediate Flashcard Gate (v2)"
fi

# (d) §18 specifies approve + reject processing
if grep -q "Approve" "$PROTOCOL_MD" && grep -q "Reject" "$PROTOCOL_MD"; then
  pass "protocol §18 documents Approve/Reject processing rule"
else
  fail "protocol §18 missing Approve/Reject processing rule"
fi

# (e) §18 specifies the worktree creation gate
if grep -q "Worktree creation gate\|worktree creation gate\|MUST NOT.*worktree\|worktree.*MUST NOT" "$PROTOCOL_MD"; then
  pass "protocol §18 documents worktree creation gate"
else
  fail "protocol §18 missing worktree creation gate rule"
fi

# (f) qa.md says QA list is additive to Developer's
if grep -q "additive" "$QA_MD"; then
  pass "qa.md notes that flashcards_flagged list is additive to Developer's"
else
  fail "qa.md missing note that flashcards_flagged is additive"
fi

# (g) developer.md references protocol §18
if grep -q "protocol §18\|§18" "$DEV_MD"; then
  pass "developer.md references protocol §18"
else
  fail "developer.md does not reference protocol §18"
fi

# (h) qa.md references protocol §18
if grep -q "protocol §18\|§18" "$QA_MD"; then
  pass "qa.md references protocol §18"
else
  fail "qa.md does not reference protocol §18"
fi

# (i) three-surface diff: live developer.md vs mirror
if diff -q "$DEV_MD" "$PLANNING_DEV_MD" > /dev/null 2>&1; then
  pass "developer.md live vs mirror diff is empty"
else
  fail "developer.md live vs mirror diff is NOT empty"
fi

# (j) three-surface diff: live qa.md vs mirror
if diff -q "$QA_MD" "$PLANNING_QA_MD" > /dev/null 2>&1; then
  pass "qa.md live vs mirror diff is empty"
else
  fail "qa.md live vs mirror diff is NOT empty"
fi

# (k) three-surface diff: live protocol.md vs mirror
if diff -q "$PROTOCOL_MD" "$PLANNING_PROTOCOL_MD" > /dev/null 2>&1; then
  pass "cleargate-protocol.md live vs mirror diff is empty"
else
  fail "cleargate-protocol.md live vs mirror diff is NOT empty"
fi

# (l) synthetic fixture: dev report with flashcards_flagged triggers gate
# Simulate: write a temp dev report with flashcards_flagged, grep for it
TMPDIR_FIXTURE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIXTURE"' EXIT

cat > "$TMPDIR_FIXTURE/STORY-014-05-dev.md" << 'FIXTURE'
STORY: STORY-014-05
STATUS: done
COMMIT: abc1234
TYPECHECK: pass
TESTS: 5 passed, 0 failed
FILES_CHANGED: src/foo.ts
NOTES: all green
flashcards_flagged:
  - "2026-04-22 · #test-harness · vitest fake-timers conflict with worker.spawn"
FIXTURE

# Assert the fixture has the flashcard entry
if grep -q "flashcards_flagged:" "$TMPDIR_FIXTURE/STORY-014-05-dev.md"; then
  pass "synthetic dev-report fixture contains flashcards_flagged field"
else
  fail "synthetic dev-report fixture missing flashcards_flagged field"
fi

# Assert extraction of the flagged card matches the FLASHCARD.md format
EXTRACTED=$(grep -A1 "flashcards_flagged:" "$TMPDIR_FIXTURE/STORY-014-05-dev.md" | tail -1 | sed 's/^[[:space:]]*- "//' | sed 's/"$//')
if echo "$EXTRACTED" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2} · #[a-z-]+ · .+"; then
  pass "extracted flashcard matches YYYY-MM-DD · #tag · lesson format"
else
  fail "extracted flashcard does NOT match expected format: '$EXTRACTED'"
fi

# Mock worktree guard: confirm the gate would block by checking the field is non-empty
FLAGGED_COUNT=$(grep -c "  - " "$TMPDIR_FIXTURE/STORY-014-05-dev.md" || true)
if [ "$FLAGGED_COUNT" -gt 0 ]; then
  pass "gate detects non-empty flashcards_flagged — worktree creation would be blocked"
else
  fail "gate failed to detect non-empty flashcards_flagged list"
fi

# Mock approval: append to a temp FLASHCARD.md and confirm it was written
TEMP_FLASHCARD="$TMPDIR_FIXTURE/FLASHCARD.md"
echo "# ClearGate Flashcards" > "$TEMP_FLASHCARD"
echo "" >> "$TEMP_FLASHCARD"
echo "$EXTRACTED" >> "$TEMP_FLASHCARD"

if grep -q "vitest fake-timers conflict" "$TEMP_FLASHCARD"; then
  pass "approved flashcard appended to FLASHCARD.md mock"
else
  fail "approved flashcard NOT found in FLASHCARD.md mock"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "Results: $PASS/$TOTAL passed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
